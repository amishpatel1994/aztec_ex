defmodule AztecEx.HighLevelEncoderTest do
  use ExUnit.Case, async: true

  alias AztecEx.HighLevelEncoder

  describe "encode/1" do
    test "encodes uppercase-only string" do
      {:ok, bits} = HighLevelEncoder.encode("AB")
      assert is_list(bits)
      assert Enum.all?(bits, &(&1 in [0, 1]))
      assert bits == [0, 0, 0, 1, 0, 0, 0, 0, 1, 1]
    end

    test "encodes lowercase string with mode latch" do
      {:ok, bits} = HighLevelEncoder.encode("ab")
      assert is_list(bits)
      assert length(bits) > 0
    end

    test "encodes digits" do
      {:ok, bits} = HighLevelEncoder.encode("123")
      assert is_list(bits)
    end

    test "encodes mixed upper and lower" do
      {:ok, bits} = HighLevelEncoder.encode("Hello")
      assert is_list(bits)
    end

    test "encodes punctuation" do
      {:ok, bits} = HighLevelEncoder.encode("!")
      assert is_list(bits)
    end

    test "encodes empty string" do
      {:ok, bits} = HighLevelEncoder.encode("")
      assert bits == []
    end

    test "encodes space (available in multiple modes)" do
      {:ok, bits} = HighLevelEncoder.encode(" ")
      assert bits == [0, 0, 0, 0, 1]
    end

    test "encodes binary data via binary shift" do
      {:ok, bits} = HighLevelEncoder.encode(<<128>>)
      assert is_list(bits)
      assert length(bits) > 0
    end

    test "encodes string with punctuation pairs" do
      {:ok, bits} = HighLevelEncoder.encode(".\r\n")
      assert is_list(bits)
    end
  end

  describe "int_to_bits/2" do
    test "converts integer to bit list" do
      assert HighLevelEncoder.int_to_bits(5, 5) == [0, 0, 1, 0, 1]
      assert HighLevelEncoder.int_to_bits(0, 4) == [0, 0, 0, 0]
      assert HighLevelEncoder.int_to_bits(15, 4) == [1, 1, 1, 1]
      assert HighLevelEncoder.int_to_bits(1, 1) == [1]
    end
  end
end
