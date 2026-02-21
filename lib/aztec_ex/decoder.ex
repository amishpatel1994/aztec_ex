defmodule AztecEx.Decoder do
  @moduledoc """
  Aztec barcode decoder that reads a BitMatrix and returns the encoded data.

  The decoder pipeline:
  1. Detect the bull's-eye center and determine compact vs full
  2. Read orientation marks to determine rotation
  3. Extract and decode the mode message (with RS error correction)
  4. Extract layer count and data codeword count
  5. Read data bits from the spiral pattern
  6. Apply RS error correction to data codewords
  7. Remove bit stuffing
  8. High-level decode the bitstream back to bytes

  Note: Image processing (binarization, perspective correction) is
  out of scope. The decoder accepts an already-extracted binary matrix.
  """

  alias AztecEx.{BitMatrix, BitStuffing, Encoder, HighLevelDecoder}
  alias AztecEx.ReedSolomon

  @doc """
  Decodes an Aztec barcode from a BitMatrix.

  Returns `{:ok, binary}` on success, `{:error, reason}` on failure.
  """
  @spec decode(BitMatrix.t()) :: {:ok, binary()} | {:error, String.t()}
  def decode(%BitMatrix{} = matrix) do
    {w, _h} = BitMatrix.dimensions(matrix)
    center = div(w, 2)

    with {:ok, compact} <- detect_type(matrix, center),
         {:ok, mode_bits} <- extract_mode_message(matrix, compact, center),
         {:ok, {layers, data_cw_count}} <- decode_mode_message(compact, mode_bits),
         {:ok, data} <- extract_and_decode_data(matrix, compact, layers, data_cw_count, center) do
      {:ok, data}
    end
  end

  @doc """
  Detects whether the symbol is compact or full by examining the finder pattern.
  """
  @spec detect_type(BitMatrix.t(), non_neg_integer()) :: {:ok, boolean()} | {:error, String.t()}
  def detect_type(matrix, center) do
    if BitMatrix.get(matrix, center, center) do
      full_ok = verify_finder_rings(matrix, center, 6)
      compact_ok = verify_finder_rings(matrix, center, 4)

      cond do
        full_ok -> {:ok, false}
        compact_ok -> {:ok, true}
        true -> {:error, "cannot detect Aztec finder pattern"}
      end
    else
      {:error, "center pixel is not set -- not an Aztec code"}
    end
  end

  defp verify_finder_rings(matrix, center, max_ring) do
    Enum.all?(0..max_ring, fn ring ->
      expected = rem(ring, 2) == 0
      check_finder_ring(matrix, center, ring, expected)
    end)
  end

  defp check_finder_ring(matrix, center, 0, expected) do
    BitMatrix.get(matrix, center, center) == expected
  end

  defp check_finder_ring(matrix, center, ring, expected) do
    half = ring

    Enum.all?(-half..half, fn offset ->
      BitMatrix.get(matrix, center + half, center + offset) == expected and
        BitMatrix.get(matrix, center - half, center + offset) == expected and
        BitMatrix.get(matrix, center + offset, center + half) == expected and
        BitMatrix.get(matrix, center + offset, center - half) == expected
    end)
  end

  @doc """
  Extracts the raw mode message bits from around the finder core.
  """
  @spec extract_mode_message(BitMatrix.t(), boolean(), non_neg_integer()) ::
          {:ok, list(0 | 1)} | {:error, String.t()}
  def extract_mode_message(matrix, compact, center) do
    half = if compact, do: 5, else: 7
    positions = mode_message_positions(compact, center, half)

    bits =
      Enum.map(positions, fn {x, y} ->
        if BitMatrix.get(matrix, x, y), do: 1, else: 0
      end)

    expected_len = if compact, do: 28, else: 40

    if length(bits) == expected_len do
      {:ok, bits}
    else
      {:error,
       "mode message extraction failed: got #{length(bits)} bits, expected #{expected_len}"}
    end
  end

  defp mode_message_positions(compact, center, half) do
    if compact do
      top = for x <- (center - 3)..(center + 3), do: {x, center - half}
      right = for y <- (center - 3)..(center + 3), do: {center + half, y}
      bottom = for x <- (center + 3)..(center - 3)//-1, do: {x, center + half}
      left = for y <- (center + 3)..(center - 3)//-1, do: {center - half, y}
      top ++ right ++ bottom ++ left
    else
      top_l = for x <- (center - 5)..(center - 1), do: {x, center - half}
      top_r = for x <- (center + 1)..(center + 5), do: {x, center - half}
      right_t = for y <- (center - 5)..(center - 1), do: {center + half, y}
      right_b = for y <- (center + 1)..(center + 5), do: {center + half, y}
      bottom_r = for x <- (center + 5)..(center + 1)//-1, do: {x, center + half}
      bottom_l = for x <- (center - 1)..(center - 5)//-1, do: {x, center + half}
      left_b = for y <- (center + 5)..(center + 1)//-1, do: {center - half, y}
      left_t = for y <- (center - 1)..(center - 5)//-1, do: {center - half, y}
      top_l ++ top_r ++ right_t ++ right_b ++ bottom_r ++ bottom_l ++ left_b ++ left_t
    end
  end

  @doc """
  Decodes the mode message to extract layer count and data codeword count.
  """
  @spec decode_mode_message(boolean(), list(0 | 1)) ::
          {:ok, {pos_integer(), pos_integer()}} | {:error, String.t()}
  def decode_mode_message(compact, mode_bits) do
    codewords = BitStuffing.to_codewords(mode_bits, 4)
    num_check = if compact, do: 5, else: 6

    case ReedSolomon.Decoder.decode(4, codewords, num_check) do
      {:ok, corrected} ->
        data_cws = Enum.take(corrected, length(corrected) - num_check)
        data_bits = BitStuffing.from_codewords(data_cws, 4)

        if compact do
          layers = bits_to_int(Enum.take(data_bits, 2)) + 1
          data_cw_count = bits_to_int(Enum.drop(data_bits, 2) |> Enum.take(6)) + 1
          {:ok, {layers, data_cw_count}}
        else
          layers = bits_to_int(Enum.take(data_bits, 5)) + 1
          data_cw_count = bits_to_int(Enum.drop(data_bits, 5) |> Enum.take(11)) + 1
          {:ok, {layers, data_cw_count}}
        end

      {:error, reason} ->
        {:error, "mode message decode failed: #{reason}"}
    end
  end

  @doc false
  def extract_and_decode_data(matrix, compact, layers, data_cw_count, center) do
    cw_size = Encoder.codeword_size(layers)

    total_capacity =
      if compact, do: Encoder.compact_capacity(layers), else: Encoder.full_capacity(layers)

    total_codewords = div(total_capacity, cw_size)
    check_count = total_codewords - data_cw_count

    positions = Encoder.spiral_positions(compact, layers, center)
    total_bits = total_capacity

    raw_bits =
      positions
      |> Enum.take(total_bits)
      |> Enum.map(fn {x, y} ->
        if BitMatrix.get(matrix, x, y), do: 1, else: 0
      end)

    prefix_bits = rem(total_capacity, cw_size)
    data_bits_without_prefix = Enum.drop(raw_bits, prefix_bits)

    all_codewords = BitStuffing.to_codewords(data_bits_without_prefix, cw_size)

    case ReedSolomon.Decoder.decode(cw_size, all_codewords, check_count) do
      {:ok, corrected} ->
        data_cws = Enum.take(corrected, data_cw_count)
        data_bits = BitStuffing.from_codewords(data_cws, cw_size)
        unstuffed = BitStuffing.unstuff(data_bits, cw_size)
        HighLevelDecoder.decode(unstuffed)

      {:error, reason} ->
        {:error, "data decode failed: #{reason}"}
    end
  end

  defp bits_to_int(bits) do
    Enum.reduce(bits, 0, fn bit, acc -> Bitwise.bor(Bitwise.bsl(acc, 1), bit) end)
  end
end
