defmodule AztecEx.ReedSolomon.DecoderTest do
  use ExUnit.Case, async: true

  alias AztecEx.ReedSolomon.{Encoder, Decoder}
  alias AztecEx.GaloisField, as: GF

  describe "decode/3 with no errors" do
    test "returns original message when no errors present" do
      field_size = 8
      data = [17, 42, 99, 3, 200]
      num_check = 10
      check = Encoder.encode(field_size, data, num_check)
      message = data ++ check

      assert {:ok, ^message} = Decoder.decode(field_size, message, num_check)
    end

    test "works for GF(16) mode message" do
      data = [5, 7]
      num_check = 5
      check = Encoder.encode(4, data, num_check)
      message = data ++ check

      assert {:ok, ^message} = Decoder.decode(4, message, num_check)
    end

    test "works for GF(64)" do
      data = for i <- 1..10, do: rem(i * 7, 63)
      num_check = 11
      check = Encoder.encode(6, data, num_check)
      message = data ++ check

      assert {:ok, ^message} = Decoder.decode(6, message, num_check)
    end
  end

  describe "decode/3 with errors" do
    test "corrects a single error in GF(256)" do
      field_size = 8
      data = [17, 42, 99, 3, 200]
      num_check = 10
      check = Encoder.encode(field_size, data, num_check)
      original = data ++ check

      corrupted = List.replace_at(original, 2, rem(Enum.at(original, 2) + 50, 256))

      assert {:ok, corrected} = Decoder.decode(field_size, corrupted, num_check)
      assert corrected == original
    end

    test "corrects multiple errors up to t = num_check/2" do
      field_size = 8
      data = [10, 20, 30, 40, 50]
      num_check = 10
      check = Encoder.encode(field_size, data, num_check)
      original = data ++ check
      max_errors = div(num_check, 2)

      corrupted =
        original
        |> List.replace_at(0, bxor(Enum.at(original, 0), 0xFF))
        |> List.replace_at(3, bxor(Enum.at(original, 3), 0xAB))

      assert {:ok, corrected} = Decoder.decode(field_size, corrupted, num_check)
      assert corrected == original
      assert max_errors == 5
    end

    test "corrects single error in GF(16)" do
      data = [3, 9]
      num_check = 5
      check = Encoder.encode(4, data, num_check)
      original = data ++ check

      corrupted = List.replace_at(original, 0, bxor(Enum.at(original, 0), 0x7))

      assert {:ok, corrected} = Decoder.decode(4, corrupted, num_check)
      assert corrected == original
    end

    test "corrects single error in GF(64)" do
      data = [1, 2, 3, 4, 5, 6, 7, 8]
      num_check = 8
      check = Encoder.encode(6, data, num_check)
      original = data ++ check

      corrupted = List.replace_at(original, 4, bxor(Enum.at(original, 4), 0x1F))

      assert {:ok, corrected} = Decoder.decode(6, corrupted, num_check)
      assert corrected == original
    end
  end

  describe "decode/3 with too many errors" do
    test "returns error when errors exceed correction capacity" do
      field_size = 8
      data = [10, 20, 30, 40, 50]
      num_check = 4
      check = Encoder.encode(field_size, data, num_check)
      original = data ++ check

      corrupted =
        original
        |> List.replace_at(0, bxor(Enum.at(original, 0), 0xFF))
        |> List.replace_at(1, bxor(Enum.at(original, 1), 0xAB))
        |> List.replace_at(2, bxor(Enum.at(original, 2), 0xCD))

      assert {:error, _reason} = Decoder.decode(field_size, corrupted, num_check)
    end
  end

  describe "compute_syndromes/3" do
    test "syndromes are all zero for valid codeword" do
      field_size = 8
      data = [1, 2, 3]
      num_check = 6
      check = Encoder.encode(field_size, data, num_check)
      message = data ++ check

      syndromes = Decoder.compute_syndromes(field_size, message, num_check)
      assert Enum.all?(syndromes, &(&1 == 0))
    end

    test "syndromes are non-zero when errors present" do
      field_size = 8
      data = [1, 2, 3]
      num_check = 6
      check = Encoder.encode(field_size, data, num_check)
      message = data ++ check

      corrupted = List.replace_at(message, 1, bxor(Enum.at(message, 1), 0x42))

      syndromes = Decoder.compute_syndromes(field_size, corrupted, num_check)
      refute Enum.all?(syndromes, &(&1 == 0))
    end
  end

  describe "roundtrip across all field sizes" do
    for field_size <- [4, 6, 8, 10, 12] do
      test "encode then corrupt then decode in GF(2^#{field_size})" do
        fs = unquote(field_size)
        max = GF.max_value(fs)
        data = for i <- 1..5, do: rem(i * 3, max)
        num_check = 6
        check = Encoder.encode(fs, data, num_check)
        original = data ++ check

        corrupted = List.replace_at(original, 2, bxor(Enum.at(original, 2), 1))

        assert {:ok, corrected} = Decoder.decode(fs, corrupted, num_check)
        assert corrected == original
      end
    end
  end

  defp bxor(a, b), do: Bitwise.bxor(a, b)
end
