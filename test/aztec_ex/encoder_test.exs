defmodule AztecEx.EncoderTest do
  use ExUnit.Case, async: true

  alias AztecEx.{BitMatrix, Encoder}

  describe "codeword_size/1" do
    test "1-2 layers use 6-bit codewords" do
      assert Encoder.codeword_size(1) == 6
      assert Encoder.codeword_size(2) == 6
    end

    test "3-8 layers use 8-bit codewords" do
      assert Encoder.codeword_size(3) == 8
      assert Encoder.codeword_size(8) == 8
    end

    test "9-22 layers use 10-bit codewords" do
      assert Encoder.codeword_size(9) == 10
      assert Encoder.codeword_size(22) == 10
    end

    test "23-32 layers use 12-bit codewords" do
      assert Encoder.codeword_size(23) == 12
      assert Encoder.codeword_size(32) == 12
    end
  end

  describe "compact_size/1 and full_size/1" do
    test "compact sizes" do
      assert Encoder.compact_size(1) == 15
      assert Encoder.compact_size(2) == 19
      assert Encoder.compact_size(3) == 23
      assert Encoder.compact_size(4) == 27
    end

    test "full sizes" do
      assert Encoder.full_size(1) == 31
      assert Encoder.full_size(4) == 43
      assert Encoder.full_size(5) == 49
    end
  end

  describe "select_symbol/2" do
    test "selects compact symbol for small data" do
      data_bits = List.duplicate(0, 20)
      assert {:ok, {true, layers, _cw_size, _total, _size}} = Encoder.select_symbol(data_bits)
      assert layers >= 1
    end

    test "returns error for impossibly large data" do
      data_bits = List.duplicate(0, 100_000)
      assert {:error, _} = Encoder.select_symbol(data_bits)
    end

    test "respects min_layers option" do
      data_bits = List.duplicate(0, 20)

      assert {:ok, {_compact, layers, _, _, _}} =
               Encoder.select_symbol(data_bits, min_layers: 3)

      assert layers >= 3
    end
  end

  describe "build_mode_message/3" do
    test "compact mode message is 28 bits" do
      bits = Encoder.build_mode_message(true, 1, 5)
      assert length(bits) == 28
    end

    test "full mode message is 40 bits" do
      bits = Encoder.build_mode_message(false, 4, 10)
      assert length(bits) == 40
    end
  end

  describe "draw_finder/4" do
    test "compact finder has correct bull's-eye pattern" do
      size = 15
      cx = div(size, 2)
      matrix = BitMatrix.new(size) |> Encoder.draw_finder(true, cx, cx)

      assert BitMatrix.get(matrix, cx, cx) == true
      assert BitMatrix.get(matrix, cx + 1, cx) == false
      assert BitMatrix.get(matrix, cx + 2, cx) == true
      assert BitMatrix.get(matrix, cx + 3, cx) == false
      assert BitMatrix.get(matrix, cx + 4, cx) == true
    end

    test "full finder has 7 rings" do
      size = 31
      cx = div(size, 2)
      matrix = BitMatrix.new(size) |> Encoder.draw_finder(false, cx, cx)

      assert BitMatrix.get(matrix, cx, cx) == true
      assert BitMatrix.get(matrix, cx + 6, cx) == true
    end
  end

  describe "draw_orientation/4" do
    test "compact orientation marks" do
      size = 15
      cx = div(size, 2)

      matrix =
        BitMatrix.new(size)
        |> Encoder.draw_finder(true, cx, cx)
        |> Encoder.draw_orientation(true, cx, cx)

      assert BitMatrix.get(matrix, cx - 5, cx - 5) == true
      assert BitMatrix.get(matrix, cx + 5, cx + 5) == false
    end
  end

  describe "place_mode_message/5" do
    test "compact mode message fills 28 positions" do
      size = 15
      cx = div(size, 2)
      mode_bits = List.duplicate(1, 28)

      matrix =
        BitMatrix.new(size)
        |> Encoder.place_mode_message(true, mode_bits, cx, cx)

      set_count = BitMatrix.count(matrix)
      assert set_count == 28
    end
  end
end
