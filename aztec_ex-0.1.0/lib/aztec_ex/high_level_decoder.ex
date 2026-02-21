defmodule AztecEx.HighLevelDecoder do
  @moduledoc """
  Decodes an Aztec bitstream back into the original bytes.

  Reads codes from the bitstream, tracks the current encoding mode,
  handles latch/shift transitions, binary shifts, and FLG(n) escapes.
  """

  alias AztecEx.CharTable
  import Bitwise

  @doc """
  Decodes a list of bits (0s and 1s) into a binary string.

  Returns `{:ok, binary}` on success, `{:error, reason}` on failure.
  """
  @spec decode([0 | 1]) :: {:ok, binary()} | {:error, String.t()}
  def decode(bits) when is_list(bits) do
    result = do_decode(bits, :upper, [])
    {:ok, IO.iodata_to_binary(result)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp do_decode([], _mode, acc), do: Enum.reverse(acc)

  defp do_decode(bits, mode, acc) do
    width = CharTable.bit_width(mode)

    if length(bits) < width do
      Enum.reverse(acc)
    else
      {code, rest} = read_bits(bits, width)
      handle_code(code, rest, mode, acc)
    end
  end

  defp handle_code(code, rest, mode, acc) do
    cond do
      shift_target = shift_target(mode, code) ->
        handle_shift(rest, mode, shift_target, acc)

      latch_target = latch_target(mode, code) ->
        do_decode(rest, latch_target, acc)

      binary_shift?(mode, code) ->
        handle_binary_shift(rest, mode, acc)

      flg?(mode, code) ->
        handle_flg(rest, mode, acc)

      true ->
        case CharTable.code_to_char(mode, code) do
          nil ->
            Enum.reverse(acc)

          {b1, b2} ->
            do_decode(rest, mode, [[b2, b1] | acc])

          byte ->
            do_decode(rest, mode, [[byte] | acc])
        end
    end
  end

  defp handle_shift(bits, return_mode, target_mode, acc) do
    width = CharTable.bit_width(target_mode)

    if length(bits) < width do
      Enum.reverse(acc)
    else
      {code, rest} = read_bits(bits, width)

      case CharTable.code_to_char(target_mode, code) do
        nil ->
          do_decode(rest, return_mode, acc)

        {b1, b2} ->
          do_decode(rest, return_mode, [[b2, b1] | acc])

        byte ->
          do_decode(rest, return_mode, [[byte] | acc])
      end
    end
  end

  defp handle_binary_shift(bits, mode, acc) do
    if length(bits) < 5 do
      Enum.reverse(acc)
    else
      {len, rest} = read_bits(bits, 5)

      {byte_count, rest2} =
        if len == 0 do
          if length(rest) < 11 do
            {0, rest}
          else
            {ext_len, rest3} = read_bits(rest, 11)
            {ext_len + 31, rest3}
          end
        else
          {len, rest}
        end

      if length(rest2) < byte_count * 8 do
        Enum.reverse(acc)
      else
        {byte_bits, rest3} = Enum.split(rest2, byte_count * 8)

        bytes =
          byte_bits
          |> Enum.chunk_every(8)
          |> Enum.map(&bits_to_int/1)

        do_decode(rest3, mode, [bytes | acc])
      end
    end
  end

  defp handle_flg(bits, mode, acc) do
    if length(bits) < 3 do
      Enum.reverse(acc)
    else
      {n, rest} = read_bits(bits, 3)

      cond do
        n == 0 ->
          do_decode(rest, mode, [[29] | acc])

        n >= 1 and n <= 6 ->
          digit_bits_needed = n * 4

          if length(rest) < digit_bits_needed do
            Enum.reverse(acc)
          else
            {_eci_bits, rest2} = Enum.split(rest, digit_bits_needed)
            do_decode(rest2, mode, acc)
          end

        true ->
          do_decode(rest, mode, acc)
      end
    end
  end

  defp shift_target(mode, code) do
    case {mode, code} do
      {:upper, 0} -> :punct
      {:lower, 0} -> :punct
      {:mixed, 0} -> :punct
      {:digit, 0} -> :punct
      {:digit, 15} -> :upper
      {:lower, 28} -> :upper
      _ -> nil
    end
  end

  defp latch_target(mode, code) do
    case {mode, code} do
      {:upper, 28} -> :lower
      {:upper, 29} -> :mixed
      {:upper, 30} -> :digit
      {:lower, 29} -> :mixed
      {:lower, 30} -> :digit
      {:mixed, 28} -> :lower
      {:mixed, 29} -> :upper
      {:mixed, 30} -> :punct
      {:digit, 14} -> :upper
      {:punct, 31} -> :upper
      _ -> nil
    end
  end

  defp binary_shift?(mode, code) when mode in [:upper, :lower, :mixed, :punct], do: code == 31
  defp binary_shift?(:mixed, 31), do: true
  defp binary_shift?(_, _), do: false

  defp flg?(:punct, 0), do: true
  defp flg?(_, _), do: false

  defp read_bits(bits, width) do
    {taken, rest} = Enum.split(bits, width)
    {bits_to_int(taken), rest}
  end

  defp bits_to_int(bits) do
    Enum.reduce(bits, 0, fn bit, acc -> acc <<< 1 ||| bit end)
  end
end
