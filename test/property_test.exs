defmodule AztecEx.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Bitwise

  alias AztecEx.{BitMatrix, BitStuffing, GaloisField, HighLevelEncoder, HighLevelDecoder}
  alias AztecEx.ReedSolomon

  @moduletag timeout: 120_000

  describe "BitMatrix properties" do
    property "set then get returns the value" do
      check all(
              size <- integer(1..50),
              x <- integer(0..(size - 1)),
              y <- integer(0..(size - 1)),
              val <- boolean()
            ) do
        matrix = BitMatrix.new(size) |> BitMatrix.set(x, y, val)
        assert BitMatrix.get(matrix, x, y) == val
      end
    end

    property "from_list then to_list roundtrips" do
      check all(
              rows <- integer(1..20),
              cols <- integer(1..20),
              grid <-
                list_of(list_of(boolean(), length: cols), length: rows)
            ) do
        matrix = BitMatrix.from_list(grid)
        assert BitMatrix.to_list(matrix) == grid
      end
    end
  end

  describe "GaloisField properties" do
    property "multiply then divide roundtrips (non-zero)" do
      check all(
              field_size <- member_of([4, 6, 8, 10, 12]),
              a <- integer(1..((1 <<< field_size) - 1)),
              b <- integer(1..((1 <<< field_size) - 1))
            ) do
        product = GaloisField.multiply(field_size, a, b)
        assert GaloisField.divide(field_size, product, b) == a
      end
    end

    property "add is its own inverse (XOR)" do
      check all(
              field_size <- member_of([4, 6, 8]),
              a <- integer(0..((1 <<< field_size) - 1)),
              b <- integer(0..((1 <<< field_size) - 1))
            ) do
        sum = GaloisField.add(field_size, a, b)
        assert GaloisField.add(field_size, sum, b) == a
      end
    end
  end

  describe "Reed-Solomon properties" do
    property "encode then decode roundtrips without errors" do
      check all(
              field_size <- member_of([4, 6, 8]),
              max_val = (1 <<< field_size) - 1,
              data_len <- integer(1..10),
              check_len <- integer(2..8),
              data <- list_of(integer(0..max_val), length: data_len)
            ) do
        check_cws = ReedSolomon.Encoder.encode(field_size, data, check_len)
        message = data ++ check_cws
        assert {:ok, corrected} = ReedSolomon.Decoder.decode(field_size, message, check_len)
        assert Enum.take(corrected, data_len) == data
      end
    end
  end

  describe "BitStuffing properties" do
    property "stuff then unstuff roundtrips" do
      check all(
              cw_size <- member_of([6, 8, 10, 12]),
              len <- integer(1..60),
              bits <- list_of(member_of([0, 1]), length: len)
            ) do
        stuffed = BitStuffing.stuff(bits, cw_size)
        padded = BitStuffing.pad(stuffed, cw_size)
        codewords = BitStuffing.to_codewords(padded, cw_size)
        recovered_bits = BitStuffing.from_codewords(codewords, cw_size)
        unstuffed = BitStuffing.unstuff(recovered_bits, cw_size)
        assert Enum.take(unstuffed, len) == bits
      end
    end
  end

  describe "HighLevelEncoder/Decoder properties" do
    @upper_chars ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZ "

    property "encode then decode roundtrips for uppercase strings" do
      check all(
              len <- integer(1..20),
              chars <- list_of(member_of(@upper_chars), length: len)
            ) do
        data = List.to_string(chars)
        {:ok, bits} = HighLevelEncoder.encode(data)
        {:ok, decoded} = HighLevelDecoder.decode(bits)
        assert decoded == data
      end
    end
  end

  describe "full encode-decode property" do
    @encodable_chars ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789"

    property "AztecEx.encode then decode roundtrips for safe strings" do
      check all(
              len <- integer(1..15),
              chars <- list_of(member_of(@encodable_chars), length: len)
            ) do
        data = List.to_string(chars)
        assert {:ok, code} = AztecEx.encode(data)
        assert {:ok, ^data} = AztecEx.decode(code.matrix)
      end
    end
  end
end
