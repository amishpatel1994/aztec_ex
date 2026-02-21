defmodule AztecEx.BitMatrixTest do
  use ExUnit.Case, async: true

  alias AztecEx.BitMatrix

  describe "new/2" do
    test "creates matrix with given dimensions" do
      m = BitMatrix.new(10, 15)
      assert {10, 15} = BitMatrix.dimensions(m)
    end

    test "all cells are initially false" do
      m = BitMatrix.new(5, 5)

      for x <- 0..4, y <- 0..4 do
        refute BitMatrix.get(m, x, y)
      end
    end
  end

  describe "new/1" do
    test "creates square matrix" do
      m = BitMatrix.new(7)
      assert {7, 7} = BitMatrix.dimensions(m)
    end
  end

  describe "get/3 and set/4" do
    test "set a cell to true and read it back" do
      m = BitMatrix.new(5, 5) |> BitMatrix.set(2, 3, true)
      assert BitMatrix.get(m, 2, 3)
    end

    test "set a cell to false clears it" do
      m =
        BitMatrix.new(5, 5)
        |> BitMatrix.set(2, 3, true)
        |> BitMatrix.set(2, 3, false)

      refute BitMatrix.get(m, 2, 3)
    end

    test "setting does not affect other cells" do
      m = BitMatrix.new(5, 5) |> BitMatrix.set(1, 1, true)
      refute BitMatrix.get(m, 0, 0)
      refute BitMatrix.get(m, 1, 0)
      assert BitMatrix.get(m, 1, 1)
    end
  end

  describe "set/3" do
    test "shorthand sets cell to true" do
      m = BitMatrix.new(3, 3) |> BitMatrix.set(0, 0)
      assert BitMatrix.get(m, 0, 0)
    end
  end

  describe "flip/3" do
    test "flips false to true" do
      m = BitMatrix.new(3, 3) |> BitMatrix.flip(1, 1)
      assert BitMatrix.get(m, 1, 1)
    end

    test "flips true to false" do
      m =
        BitMatrix.new(3, 3)
        |> BitMatrix.set(1, 1)
        |> BitMatrix.flip(1, 1)

      refute BitMatrix.get(m, 1, 1)
    end
  end

  describe "set_region/6" do
    test "fills a rectangular region" do
      m = BitMatrix.new(5, 5) |> BitMatrix.set_region(1, 1, 3, 2)

      for x <- 1..3, y <- 1..2 do
        assert BitMatrix.get(m, x, y), "expected (#{x},#{y}) to be set"
      end

      refute BitMatrix.get(m, 0, 0)
      refute BitMatrix.get(m, 4, 4)
    end

    test "fills region with false to clear" do
      m =
        BitMatrix.new(5, 5)
        |> BitMatrix.set_region(0, 0, 5, 5)
        |> BitMatrix.set_region(1, 1, 2, 2, false)

      assert BitMatrix.get(m, 0, 0)
      refute BitMatrix.get(m, 1, 1)
      refute BitMatrix.get(m, 2, 2)
      assert BitMatrix.get(m, 3, 3)
    end
  end

  describe "to_list/1 and from_list/1" do
    test "roundtrip through list representation" do
      rows = [
        [true, false, true],
        [false, true, false],
        [true, true, false]
      ]

      m = BitMatrix.from_list(rows)
      assert {3, 3} = BitMatrix.dimensions(m)
      assert rows == BitMatrix.to_list(m)
    end

    test "empty matrix" do
      m = BitMatrix.from_list([])
      assert {0, 0} = BitMatrix.dimensions(m)
    end
  end

  describe "count/1" do
    test "counts set cells" do
      m =
        BitMatrix.new(3, 3)
        |> BitMatrix.set(0, 0)
        |> BitMatrix.set(1, 1)
        |> BitMatrix.set(2, 2)

      assert 3 == BitMatrix.count(m)
    end

    test "empty matrix has count 0" do
      assert 0 == BitMatrix.count(BitMatrix.new(5, 5))
    end
  end
end
