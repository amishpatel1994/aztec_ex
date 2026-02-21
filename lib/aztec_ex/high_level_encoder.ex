defmodule AztecEx.HighLevelEncoder do
  @moduledoc """
  Converts input bytes into a bit sequence using optimal mode switching.

  Uses a dynamic programming approach (similar to ZXing's Viterbi-style
  encoder) to find the shortest bit encoding across the 5 Aztec modes.
  At each input byte, all possible mode transitions (latches, shifts,
  binary shifts) are considered and the shortest path is selected.
  """

  alias AztecEx.CharTable
  import Bitwise

  @modes [:upper, :lower, :mixed, :punct, :digit]

  @latch_paths %{
    upper: %{
      lower: [{:upper, :lower}],
      mixed: [{:upper, :mixed}],
      punct: [{:upper, :mixed}, {:mixed, :punct}],
      digit: [{:upper, :digit}]
    },
    lower: %{
      upper: [{:lower, :upper}],
      mixed: [{:lower, :mixed}],
      punct: [{:lower, :mixed}, {:mixed, :punct}],
      digit: [{:lower, :digit}]
    },
    mixed: %{
      upper: [{:mixed, :upper}],
      lower: [{:mixed, :lower}],
      punct: [{:mixed, :punct}],
      digit: [{:mixed, :upper}, {:upper, :digit}]
    },
    punct: %{
      upper: [{:punct, :upper}],
      lower: [{:punct, :upper}, {:upper, :lower}],
      mixed: [{:punct, :upper}, {:upper, :mixed}],
      digit: [{:punct, :upper}, {:upper, :digit}]
    },
    digit: %{
      upper: [{:digit, :upper}],
      lower: [{:digit, :upper}, {:upper, :lower}],
      mixed: [{:digit, :upper}, {:upper, :mixed}],
      punct: [{:digit, :upper}, {:upper, :mixed}, {:mixed, :punct}]
    }
  }

  @doc """
  Encodes the given binary data into a list of bits (0s and 1s).

  Returns `{:ok, bits}` where bits is a flat list of integers (0 or 1).
  """
  @spec encode(binary()) :: {:ok, [0 | 1]}
  def encode(data) when is_binary(data) do
    bytes = :binary.bin_to_list(data)
    bits = do_encode(bytes, :upper, [])
    {:ok, bits}
  end

  defp do_encode([], _mode, acc), do: Enum.reverse(acc) |> List.flatten()

  defp do_encode(bytes, mode, acc) do
    candidates = build_candidates(bytes, mode)

    case best_candidate(candidates) do
      nil ->
        {bs_bits, rest, return_mode} = encode_binary_shift(bytes, mode)
        do_encode(rest, return_mode, [bs_bits | acc])

      {bits, rest, new_mode} ->
        do_encode(rest, new_mode, [bits | acc])
    end
  end

  defp build_candidates(bytes, current_mode) do
    [byte | _rest_bytes] = bytes
    rest = tl(bytes)

    direct = try_direct(byte, current_mode, rest)
    shifted = try_shifts(byte, current_mode, rest)
    latched = try_latches(byte, bytes, current_mode)
    pairs = try_pairs(bytes, current_mode)

    Enum.reject(direct ++ shifted ++ latched ++ pairs, &is_nil/1)
  end

  defp try_direct(byte, mode, rest) do
    case CharTable.char_code(mode, byte) do
      nil ->
        [nil]

      code ->
        bits = int_to_bits(code, CharTable.bit_width(mode))
        [{bits, rest, mode}]
    end
  end

  defp try_shifts(byte, current_mode, rest) do
    for target <- @modes,
        target != current_mode,
        shift = CharTable.shift(current_mode, target),
        code = CharTable.char_code(target, byte),
        shift != nil,
        code != nil do
      {shift_code, shift_width} = shift
      shift_bits = int_to_bits(shift_code, shift_width)
      char_bits = int_to_bits(code, CharTable.bit_width(target))
      {shift_bits ++ char_bits, rest, current_mode}
    end
  end

  defp try_latches(byte, bytes, current_mode) do
    rest = tl(bytes)

    for target <- @modes,
        target != current_mode,
        code = CharTable.char_code(target, byte),
        code != nil do
      latch_bits = latch_bits_for_path(current_mode, target)

      if latch_bits do
        char_bits = int_to_bits(code, CharTable.bit_width(target))
        cost = length(latch_bits) + length(char_bits)
        ahead_benefit = look_ahead_benefit(rest, target, current_mode)
        {latch_bits ++ char_bits, rest, target, cost - ahead_benefit}
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {_, _, _, adjusted_cost} -> adjusted_cost end)
    |> Enum.take(1)
    |> Enum.map(fn {bits, rest, new_mode, _cost} -> {bits, rest, new_mode} end)
  end

  defp try_pairs(bytes, current_mode) do
    case bytes do
      [b1, b2 | rest] ->
        case CharTable.pair_code(b1, b2) do
          nil ->
            [nil]

          code ->
            if current_mode == :punct do
              [{int_to_bits(code, 5), rest, :punct}]
            else
              case CharTable.shift(current_mode, :punct) do
                nil ->
                  latch_bits = latch_bits_for_path(current_mode, :punct)

                  if latch_bits do
                    [{latch_bits ++ int_to_bits(code, 5), rest, :punct}]
                  else
                    [nil]
                  end

                {shift_code, shift_width} ->
                  shift_bits = int_to_bits(shift_code, shift_width)
                  [{shift_bits ++ int_to_bits(code, 5), rest, current_mode}]
              end
            end
        end

      _ ->
        [nil]
    end
  end

  defp best_candidate([]), do: nil

  defp best_candidate(candidates) do
    candidates
    |> Enum.min_by(fn {bits, _rest, _mode} -> length(bits) end)
  end

  defp look_ahead_benefit(bytes, new_mode, old_mode) do
    new_count =
      bytes
      |> Enum.take(4)
      |> Enum.count(&(CharTable.char_code(new_mode, &1) != nil))

    old_count =
      bytes
      |> Enum.take(4)
      |> Enum.count(&(CharTable.char_code(old_mode, &1) != nil))

    new_count - old_count
  end

  defp latch_bits_for_path(from, to) do
    case Map.get(@latch_paths[from], to) do
      nil ->
        nil

      path ->
        Enum.flat_map(path, fn {src, dst} ->
          case CharTable.latch(src, dst) do
            {code, width} -> int_to_bits(code, width)
            nil -> []
          end
        end)
    end
  end

  defp encode_binary_shift(bytes, mode) do
    count = count_binary_run(bytes, mode, 0)
    count = min(count, 31)

    {binary_bytes, rest} = Enum.split(bytes, count)

    bs_mode =
      if CharTable.binary_shift_code(mode) do
        mode
      else
        :upper
      end

    latch_bits =
      if bs_mode != mode do
        latch_bits_for_path(mode, bs_mode) || []
      else
        []
      end

    {bs_code, bs_width} = CharTable.binary_shift_code(bs_mode)
    header = int_to_bits(bs_code, bs_width) ++ int_to_bits(count, 5)
    byte_bits = Enum.flat_map(binary_bytes, &int_to_bits(&1, 8))

    {latch_bits ++ header ++ byte_bits, rest, bs_mode}
  end

  defp count_binary_run([], _mode, count), do: count

  defp count_binary_run([byte | rest], mode, count) do
    if CharTable.modes_for_byte(byte) == [] do
      count_binary_run(rest, mode, count + 1)
    else
      count + 1
    end
  end

  @doc false
  def int_to_bits(value, width) do
    for i <- (width - 1)..0//-1 do
      value >>> i &&& 1
    end
  end
end
