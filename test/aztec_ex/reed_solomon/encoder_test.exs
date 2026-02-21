defmodule AztecEx.ReedSolomon.EncoderTest do
  use ExUnit.Case, async: true

  alias AztecEx.ReedSolomon.Encoder
  alias AztecEx.GaloisField, as: GF

  describe "generator_poly/2" do
    test "generator poly for 1 check word is (x - a^1) = [1, 2]" do
      poly = Encoder.generator_poly(8, 1)
      assert poly == [1, 2]
    end

    test "generator poly has num_check + 1 coefficients" do
      for num_check <- [1, 3, 5, 10] do
        poly = Encoder.generator_poly(8, num_check)
        assert length(poly) == num_check + 1
      end
    end

    test "leading coefficient is always 1" do
      for num_check <- [1, 3, 5] do
        poly = Encoder.generator_poly(8, num_check)
        assert hd(poly) == 1
      end
    end
  end

  describe "encode/3" do
    test "returns correct number of check codewords" do
      for field_size <- [4, 6, 8], num_check <- [2, 5, 10] do
        data = [1, 2, 3, 4, 5]
        check = Encoder.encode(field_size, data, num_check)
        assert length(check) == num_check
      end
    end

    test "all-zero data produces all-zero check words" do
      check = Encoder.encode(8, [0, 0, 0], 5)
      assert Enum.all?(check, &(&1 == 0))
    end

    test "data + check words form a valid codeword (divisible by generator)" do
      field_size = 8
      data = [17, 42, 99, 3, 200]
      num_check = 5
      check = Encoder.encode(field_size, data, num_check)
      message = data ++ check

      gen = Encoder.generator_poly(field_size, num_check)
      remainder = evaluate_remainder(field_size, message, gen)

      assert Enum.all?(remainder, &(&1 == 0)),
             "message should be divisible by generator polynomial"
    end

    test "GF(16) mode message encoding: 2 data + 5 check words" do
      data = [0b0101, 0b0111]
      check = Encoder.encode(4, data, 5)
      assert length(check) == 5

      message = data ++ check
      gen = Encoder.generator_poly(4, 5)
      remainder = evaluate_remainder(4, message, gen)
      assert Enum.all?(remainder, &(&1 == 0))
    end

    test "GF(64) encoding for 1-2 layer Aztec" do
      data = for i <- 1..10, do: rem(i * 7, 63)
      check = Encoder.encode(6, data, 11)
      assert length(check) == 11

      message = data ++ check
      gen = Encoder.generator_poly(6, 11)
      remainder = evaluate_remainder(6, message, gen)
      assert Enum.all?(remainder, &(&1 == 0))
    end

    test "check words are within field range" do
      for field_size <- [4, 6, 8, 10, 12] do
        max = GF.max_value(field_size)
        data = [1, 2, 3]
        check = Encoder.encode(field_size, data, 5)
        assert Enum.all?(check, &(&1 >= 0 and &1 <= max))
      end
    end
  end

  defp evaluate_remainder(field_size, message, divisor) do
    divisor_len = length(divisor)
    message_len = length(message)

    if message_len < divisor_len do
      message
    else
      Enum.reduce(0..(message_len - divisor_len), message, fn _i, current ->
        if hd(current) == 0 do
          tl(current)
        else
          factor = GF.divide(field_size, hd(current), hd(divisor))

          rest =
            current
            |> Enum.zip(divisor ++ List.duplicate(0, length(current) - divisor_len))
            |> Enum.map(fn {a, b} ->
              GF.add(field_size, a, GF.multiply(field_size, b, factor))
            end)

          tl(rest)
        end
      end)
    end
  end
end
