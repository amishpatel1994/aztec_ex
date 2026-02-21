defmodule AztecEx.CharTableTest do
  use ExUnit.Case, async: true

  alias AztecEx.CharTable

  describe "char_code/2" do
    test "uppercase letters in upper mode" do
      assert CharTable.char_code(:upper, ?A) == 2
      assert CharTable.char_code(:upper, ?Z) == 27
    end

    test "space is available in upper, lower, mixed, and digit modes" do
      assert CharTable.char_code(:upper, ?\s) == 1
      assert CharTable.char_code(:lower, ?\s) == 1
      assert CharTable.char_code(:mixed, ?\s) == 1
      assert CharTable.char_code(:digit, ?\s) == 1
    end

    test "lowercase letters in lower mode" do
      assert CharTable.char_code(:lower, ?a) == 2
      assert CharTable.char_code(:lower, ?z) == 27
    end

    test "digits in digit mode" do
      assert CharTable.char_code(:digit, ?0) == 2
      assert CharTable.char_code(:digit, ?9) == 11
    end

    test "punctuation characters" do
      assert CharTable.char_code(:punct, ?!) == 6
      assert CharTable.char_code(:punct, ?}) == 30
    end

    test "mixed mode characters" do
      assert CharTable.char_code(:mixed, ?@) == 20
      assert CharTable.char_code(:mixed, ?~) == 26
    end

    test "returns nil for characters not in mode" do
      assert CharTable.char_code(:upper, ?a) == nil
      assert CharTable.char_code(:lower, ?A) == nil
      assert CharTable.char_code(:digit, ?A) == nil
    end
  end

  describe "pair_code/2" do
    test "CR+LF pair" do
      assert CharTable.pair_code(?\r, ?\n) == 2
    end

    test "period+space pair" do
      assert CharTable.pair_code(?., ?\s) == 3
    end

    test "comma+space pair" do
      assert CharTable.pair_code(?,, ?\s) == 4
    end

    test "colon+space pair" do
      assert CharTable.pair_code(?:, ?\s) == 5
    end

    test "non-pair returns nil" do
      assert CharTable.pair_code(?A, ?B) == nil
    end
  end

  describe "bit_width/1" do
    test "digit mode is 4 bits" do
      assert CharTable.bit_width(:digit) == 4
    end

    test "all other modes are 5 bits" do
      assert CharTable.bit_width(:upper) == 5
      assert CharTable.bit_width(:lower) == 5
      assert CharTable.bit_width(:mixed) == 5
      assert CharTable.bit_width(:punct) == 5
    end
  end

  describe "latch/2" do
    test "upper to lower latch exists" do
      assert {28, 5} = CharTable.latch(:upper, :lower)
    end

    test "upper to digit latch exists" do
      assert {30, 5} = CharTable.latch(:upper, :digit)
    end

    test "same mode returns nil" do
      assert CharTable.latch(:upper, :upper) == nil
    end

    test "no direct latch from upper to punct" do
      assert CharTable.latch(:upper, :punct) == nil
    end
  end

  describe "shift/2" do
    test "upper to punct shift exists" do
      assert {0, 5} = CharTable.shift(:upper, :punct)
    end

    test "digit to upper shift exists" do
      assert {15, 4} = CharTable.shift(:digit, :upper)
    end

    test "no shift from upper to lower" do
      assert CharTable.shift(:upper, :lower) == nil
    end
  end

  describe "modes_for_byte/1" do
    test "space is in multiple modes" do
      modes = CharTable.modes_for_byte(?\s)
      assert :upper in modes
      assert :lower in modes
      assert :mixed in modes
      assert :digit in modes
    end

    test "uppercase letter only in upper mode" do
      assert CharTable.modes_for_byte(?A) == [:upper]
    end

    test "digit in digit mode and possibly punct for comma/period" do
      modes = CharTable.modes_for_byte(?0)
      assert :digit in modes
    end
  end

  describe "code_to_char/2" do
    test "reverse lookup for upper mode" do
      assert CharTable.code_to_char(:upper, 2) == ?A
      assert CharTable.code_to_char(:upper, 27) == ?Z
    end

    test "reverse lookup for punct pair" do
      assert CharTable.code_to_char(:punct, 2) == {?\r, ?\n}
    end

    test "returns nil for invalid code" do
      assert CharTable.code_to_char(:upper, 99) == nil
    end
  end

  describe "binary_shift_code/1" do
    test "available for upper, lower, mixed, punct" do
      assert {31, 5} = CharTable.binary_shift_code(:upper)
      assert {31, 5} = CharTable.binary_shift_code(:lower)
      assert {31, 5} = CharTable.binary_shift_code(:mixed)
      assert {31, 5} = CharTable.binary_shift_code(:punct)
    end

    test "not available for digit mode" do
      assert CharTable.binary_shift_code(:digit) == nil
    end
  end
end
