defmodule AztecEx.BitStuffingTest do
  use ExUnit.Case, async: true

  alias AztecEx.BitStuffing

  describe "stuff/2" do
    test "no stuffing needed when bits are mixed" do
      bits = [1, 0, 1, 0, 1, 0]
      assert BitStuffing.stuff(bits, 6) == bits
    end

    test "stuffs complement when first b-1 bits are all zeros" do
      bits = [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1]
      stuffed = BitStuffing.stuff(bits, 6)
      assert length(stuffed) > length(bits)
    end

    test "stuffs complement when first b-1 bits are all ones" do
      bits = [1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0]
      stuffed = BitStuffing.stuff(bits, 6)
      assert length(stuffed) > length(bits)
    end

    test "empty input" do
      assert BitStuffing.stuff([], 6) == []
    end
  end

  describe "pad/2" do
    test "pads to codeword boundary" do
      bits = [1, 0, 1]
      padded = BitStuffing.pad(bits, 6)
      assert rem(length(padded), 6) == 0
    end

    test "no padding needed when already aligned" do
      bits = [1, 0, 1, 0, 1, 0]
      assert BitStuffing.pad(bits, 6) == bits
    end

    test "padding avoids all-ones last codeword" do
      bits = [1, 1, 1, 1, 1]
      padded = BitStuffing.pad(bits, 6)
      assert rem(length(padded), 6) == 0
      last_cw = Enum.take(padded, -6)
      refute Enum.all?(last_cw, &(&1 == 1))
    end
  end

  describe "unstuff/2" do
    test "roundtrip: stuff then unstuff recovers original" do
      bits = [1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0]
      stuffed = BitStuffing.stuff(bits, 6)
      unstuffed = BitStuffing.unstuff(stuffed, 6)
      assert unstuffed == bits
    end

    test "roundtrip with all-zero prefix" do
      bits = [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1]
      stuffed = BitStuffing.stuff(bits, 6)
      unstuffed = BitStuffing.unstuff(stuffed, 6)
      assert unstuffed == bits
    end

    test "empty input" do
      assert BitStuffing.unstuff([], 6) == []
    end
  end

  describe "to_codewords/2 and from_codewords/2" do
    test "converts bits to codewords and back" do
      bits = [1, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0]
      codewords = BitStuffing.to_codewords(bits, 6)
      assert length(codewords) == 2
      recovered = BitStuffing.from_codewords(codewords, 6)
      assert recovered == bits
    end

    test "ignores incomplete last codeword" do
      bits = [1, 0, 1, 0, 1, 0, 1, 1]
      codewords = BitStuffing.to_codewords(bits, 6)
      assert length(codewords) == 1
    end
  end

  describe "count_codewords/2" do
    test "counts complete codewords" do
      bits = List.duplicate(0, 18)
      assert BitStuffing.count_codewords(bits, 6) == 3
    end

    test "partial codeword not counted" do
      bits = List.duplicate(0, 20)
      assert BitStuffing.count_codewords(bits, 6) == 3
    end
  end
end
