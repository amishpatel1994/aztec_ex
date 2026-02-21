defmodule AztecEx.DecoderTest do
  use ExUnit.Case, async: true

  alias AztecEx.{BitMatrix, Decoder, Encoder}

  defp encode_to_matrix(data, opts \\ []) do
    {:ok, code} = Encoder.encode(data, opts)
    {code.matrix, code}
  end

  describe "detect_type/2" do
    test "detects compact symbol" do
      {matrix, _code} = encode_to_matrix("HELLO")
      {w, _} = BitMatrix.dimensions(matrix)
      center = div(w, 2)

      assert {:ok, true} = Decoder.detect_type(matrix, center)
    end

    test "detects full symbol when forced" do
      {matrix, code} =
        encode_to_matrix("HELLO WORLD THIS IS A LONGER MESSAGE FOR FULL", compact: false)

      assert code.compact == false, "expected encoder to produce full code"
      {w, _} = BitMatrix.dimensions(matrix)
      center = div(w, 2)

      assert {:ok, false} = Decoder.detect_type(matrix, center)
    end

    test "returns error for empty matrix" do
      matrix = BitMatrix.new(15)
      center = 7

      assert {:error, "center pixel is not set" <> _} = Decoder.detect_type(matrix, center)
    end

    test "returns error when center is set but no finder rings" do
      matrix = BitMatrix.new(15) |> BitMatrix.set(7, 7, true)
      center = 7

      assert {:error, "cannot detect Aztec finder pattern"} = Decoder.detect_type(matrix, center)
    end
  end

  describe "extract_mode_message/3" do
    test "extracts 28-bit compact mode message" do
      {matrix, _code} = encode_to_matrix("AB")
      {w, _} = BitMatrix.dimensions(matrix)
      center = div(w, 2)

      assert {:ok, bits} = Decoder.extract_mode_message(matrix, true, center)
      assert length(bits) == 28
      assert Enum.all?(bits, &(&1 in [0, 1]))
    end

    test "extracts 40-bit full mode message" do
      {matrix, _code} =
        encode_to_matrix("HELLO WORLD THIS IS A LONGER MESSAGE FOR FULL", compact: false)

      {w, _} = BitMatrix.dimensions(matrix)
      center = div(w, 2)

      assert {:ok, bits} = Decoder.extract_mode_message(matrix, false, center)
      assert length(bits) == 40
      assert Enum.all?(bits, &(&1 in [0, 1]))
    end
  end

  describe "decode_mode_message/2" do
    test "decodes compact mode message to layers and data codeword count" do
      {matrix, code} = encode_to_matrix("HELLO")
      {w, _} = BitMatrix.dimensions(matrix)
      center = div(w, 2)

      {:ok, mode_bits} = Decoder.extract_mode_message(matrix, true, center)
      {:ok, {layers, data_cw_count}} = Decoder.decode_mode_message(true, mode_bits)

      assert layers == code.layers
      assert data_cw_count == code.data_codewords
    end

    test "decodes full mode message to layers and data codeword count" do
      {matrix, code} =
        encode_to_matrix("HELLO WORLD THIS IS A LONGER MESSAGE FOR FULL", compact: false)

      {w, _} = BitMatrix.dimensions(matrix)
      center = div(w, 2)

      {:ok, mode_bits} = Decoder.extract_mode_message(matrix, false, center)
      {:ok, {layers, data_cw_count}} = Decoder.decode_mode_message(false, mode_bits)

      assert layers == code.layers
      assert data_cw_count == code.data_codewords
    end
  end

  describe "decode/1 roundtrip" do
    test "uppercase string" do
      {matrix, _} = encode_to_matrix("HELLO")
      assert {:ok, "HELLO"} = Decoder.decode(matrix)
    end

    test "lowercase string" do
      {matrix, _} = encode_to_matrix("hello")
      assert {:ok, "hello"} = Decoder.decode(matrix)
    end

    test "mixed case" do
      {matrix, _} = encode_to_matrix("Hello World")
      assert {:ok, "Hello World"} = Decoder.decode(matrix)
    end

    test "digits" do
      {matrix, _} = encode_to_matrix("12345")
      assert {:ok, "12345"} = Decoder.decode(matrix)
    end

    test "alphanumeric with spaces" do
      {matrix, _} = encode_to_matrix("ABC 123")
      assert {:ok, "ABC 123"} = Decoder.decode(matrix)
    end

    test "single character" do
      {matrix, _} = encode_to_matrix("A")
      assert {:ok, "A"} = Decoder.decode(matrix)
    end

    test "space" do
      {matrix, _} = encode_to_matrix(" ")
      assert {:ok, " "} = Decoder.decode(matrix)
    end

    test "longer uppercase message" do
      msg = "THE QUICK BROWN FOX"
      {matrix, _} = encode_to_matrix(msg)
      assert {:ok, ^msg} = Decoder.decode(matrix)
    end
  end

  describe "decode/1 with errors" do
    test "returns error for all-white matrix" do
      matrix = BitMatrix.new(15)
      assert {:error, _} = Decoder.decode(matrix)
    end

    test "returns error for matrix with only center set" do
      matrix = BitMatrix.new(15) |> BitMatrix.set(7, 7, true)
      assert {:error, _} = Decoder.decode(matrix)
    end
  end
end
