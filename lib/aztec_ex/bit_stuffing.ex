defmodule AztecEx.BitStuffing do
  @moduledoc """
  Bit stuffing and padding for Aztec barcode data encoding.

  Before Reed-Solomon encoding, data bits are packed into codewords
  with bit stuffing applied to avoid all-zero and all-one codewords
  (which are reserved for erasure detection). After stuffing, the
  stream is padded to a codeword boundary.
  """

  @doc """
  Applies bit stuffing to a bit list for the given codeword size.

  If the first `b-1` bits of any codeword position are all the same
  value, an extra complementary bit is inserted. This makes the data
  longer and may require a larger symbol.

  Returns the stuffed bit list.
  """
  @spec stuff(list(0 | 1), pos_integer()) :: list(0 | 1)
  def stuff(bits, codeword_size) do
    do_stuff(bits, codeword_size, codeword_size - 1, 0, [])
    |> Enum.reverse()
  end

  defp do_stuff([], _cw_size, _threshold, _pos_in_cw, acc), do: acc

  defp do_stuff([bit | rest], cw_size, threshold, pos_in_cw, acc) do
    new_acc = [bit | acc]
    new_pos = pos_in_cw + 1

    if new_pos == threshold do
      prefix = Enum.take(new_acc, threshold)

      if all_same?(prefix) do
        complement = 1 - hd(prefix)
        do_stuff(rest, cw_size, threshold, 0, [complement | new_acc])
      else
        do_stuff(rest, cw_size, threshold, rem(new_pos, cw_size), new_acc)
      end
    else
      do_stuff(rest, cw_size, threshold, rem(new_pos, cw_size), new_acc)
    end
  end

  defp all_same?([]), do: false
  defp all_same?([x | rest]), do: Enum.all?(rest, &(&1 == x))

  @doc """
  Pads a stuffed bit list to the next codeword boundary.

  Appends a `1` bit. If this creates an all-ones codeword, the last
  bit is flipped to `0`.
  """
  @spec pad(list(0 | 1), pos_integer()) :: list(0 | 1)
  def pad(bits, codeword_size) do
    remainder = rem(length(bits), codeword_size)

    if remainder == 0 do
      bits
    else
      padding_needed = codeword_size - remainder
      padded = bits ++ List.duplicate(1, padding_needed)

      last_cw = Enum.take(padded, -codeword_size)

      if Enum.all?(last_cw, &(&1 == 1)) do
        List.replace_at(padded, length(padded) - 1, 0)
      else
        padded
      end
    end
  end

  @doc """
  Removes bit stuffing from a bit list (for decoding).

  Examines each codeword position: if the first `b-1` bits are all
  the same, the next bit is a stuffed complement and is removed.
  """
  @spec unstuff(list(0 | 1), pos_integer()) :: list(0 | 1)
  def unstuff(bits, codeword_size) do
    do_unstuff(bits, codeword_size, codeword_size - 1, 0, [])
    |> Enum.reverse()
  end

  defp do_unstuff([], _cw_size, _threshold, _pos, acc), do: acc

  defp do_unstuff([bit | rest], cw_size, threshold, pos_in_cw, acc) do
    new_acc = [bit | acc]
    new_pos = pos_in_cw + 1

    if new_pos == threshold do
      prefix = Enum.take(new_acc, threshold)

      if all_same?(prefix) do
        case rest do
          [_stuffed_bit | rest2] ->
            do_unstuff(rest2, cw_size, threshold, 0, new_acc)

          [] ->
            new_acc
        end
      else
        do_unstuff(rest, cw_size, threshold, rem(new_pos, cw_size), new_acc)
      end
    else
      do_unstuff(rest, cw_size, threshold, rem(new_pos, cw_size), new_acc)
    end
  end

  @doc """
  Returns the number of data codewords that fit in the given bit list
  after stuffing, for the given codeword size.
  """
  @spec count_codewords(list(0 | 1), pos_integer()) :: non_neg_integer()
  def count_codewords(stuffed_bits, codeword_size) do
    div(length(stuffed_bits), codeword_size)
  end

  @doc """
  Splits a bit list into codewords of the given size.
  """
  @spec to_codewords(list(0 | 1), pos_integer()) :: list(non_neg_integer())
  def to_codewords(bits, codeword_size) do
    bits
    |> Enum.chunk_every(codeword_size)
    |> Enum.filter(&(length(&1) == codeword_size))
    |> Enum.map(&bits_to_int/1)
  end

  @doc """
  Converts codewords back to a bit list.
  """
  @spec from_codewords(list(non_neg_integer()), pos_integer()) :: list(0 | 1)
  def from_codewords(codewords, codeword_size) do
    Enum.flat_map(codewords, fn cw ->
      for i <- (codeword_size - 1)..0//-1 do
        Bitwise.band(Bitwise.bsr(cw, i), 1)
      end
    end)
  end

  defp bits_to_int(bits) do
    Enum.reduce(bits, 0, fn bit, acc -> Bitwise.bor(Bitwise.bsl(acc, 1), bit) end)
  end
end
