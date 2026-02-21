defmodule AztecEx.GaloisFieldTest do
  use ExUnit.Case, async: true
  import Bitwise

  alias AztecEx.GaloisField, as: GF

  @field_sizes [4, 6, 8, 10, 12]

  describe "field properties" do
    for size <- [4, 6, 8, 10, 12] do
      test "GF(2^#{size}) has correct order" do
        size = unquote(size)
        assert GF.order(size) == :math.pow(2, size) |> round()
      end

      test "GF(2^#{size}) exp table covers all non-zero elements" do
        size = unquote(size)
        max = GF.max_value(size)
        elements = for i <- 0..(max - 1), do: GF.exp_table(size, i)
        assert length(Enum.uniq(elements)) == max
      end
    end
  end

  describe "add/3" do
    test "addition is XOR" do
      assert GF.add(8, 0b10110, 0b01101) == 0b11011
    end

    test "adding element to itself yields zero" do
      for size <- @field_sizes, x <- [1, 5, 13] do
        assert GF.add(size, x, x) == 0
      end
    end

    test "adding zero is identity" do
      for size <- @field_sizes do
        assert GF.add(size, 42 &&& GF.max_value(size), 0) ==
                 (42 &&& GF.max_value(size))
      end
    end
  end

  describe "multiply/3" do
    test "multiply by zero yields zero" do
      for size <- @field_sizes do
        assert GF.multiply(size, 0, 7) == 0
        assert GF.multiply(size, 7, 0) == 0
      end
    end

    test "multiply by one is identity" do
      for size <- @field_sizes do
        assert GF.multiply(size, 5, 1) == 5
        assert GF.multiply(size, 1, 5) == 5
      end
    end

    test "multiplication is commutative" do
      for size <- @field_sizes do
        a = 3
        b = 7
        assert GF.multiply(size, a, b) == GF.multiply(size, b, a)
      end
    end

    test "known GF(256) multiplication: 42 * 23" do
      result = GF.multiply(8, 42, 23)
      assert is_integer(result)
      assert result >= 0 and result < 256
    end
  end

  describe "divide/3" do
    test "division by zero raises" do
      assert_raise ArgumentError, fn -> GF.divide(8, 5, 0) end
    end

    test "zero divided by anything is zero" do
      for size <- @field_sizes do
        assert GF.divide(size, 0, 5) == 0
      end
    end

    test "multiply then divide roundtrips" do
      for size <- @field_sizes do
        a = 7
        b = 11 &&& GF.max_value(size)
        b = if b == 0, do: 1, else: b
        product = GF.multiply(size, a, b)
        assert GF.divide(size, product, b) == a
      end
    end
  end

  describe "inverse/2" do
    test "inverse of zero raises" do
      assert_raise ArgumentError, fn -> GF.inverse(8, 0) end
    end

    test "element times its inverse equals 1" do
      for size <- @field_sizes, x <- [1, 2, 5, 13] do
        x = x &&& GF.max_value(size)
        x = if x == 0, do: 1, else: x
        inv = GF.inverse(size, x)
        assert GF.multiply(size, x, inv) == 1
      end
    end
  end

  describe "power/3" do
    test "anything to the 0 is 1" do
      for size <- @field_sizes do
        assert GF.power(size, 5, 0) == 1
      end
    end

    test "zero to any positive power is 0" do
      for size <- @field_sizes do
        assert GF.power(size, 0, 3) == 0
      end
    end

    test "x^1 is x" do
      for size <- @field_sizes do
        assert GF.power(size, 7, 1) == 7
      end
    end

    test "x^2 equals x*x" do
      for size <- @field_sizes do
        x = 5
        assert GF.power(size, x, 2) == GF.multiply(size, x, x)
      end
    end
  end

  describe "exp/2" do
    test "exp(0) is 1 (generator^0)" do
      for size <- @field_sizes do
        assert GF.exp(size, 0) == 1
      end
    end

    test "exp(1) is 2 (the generator element)" do
      for size <- @field_sizes do
        assert GF.exp(size, 1) == 2
      end
    end
  end

  describe "subtract/3" do
    test "subtract is same as add in GF(2^p)" do
      for size <- @field_sizes do
        assert GF.subtract(size, 10, 7) == GF.add(size, 10, 7)
      end
    end
  end
end
