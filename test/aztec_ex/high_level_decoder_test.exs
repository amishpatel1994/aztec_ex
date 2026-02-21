defmodule AztecEx.HighLevelDecoderTest do
  use ExUnit.Case, async: true

  alias AztecEx.{HighLevelEncoder, HighLevelDecoder}

  describe "decode/1" do
    test "decodes uppercase string" do
      {:ok, bits} = HighLevelEncoder.encode("HELLO")
      {:ok, decoded} = HighLevelDecoder.decode(bits)
      assert decoded == "HELLO"
    end

    test "decodes lowercase string" do
      {:ok, bits} = HighLevelEncoder.encode("hello")
      {:ok, decoded} = HighLevelDecoder.decode(bits)
      assert decoded == "hello"
    end

    test "decodes mixed case" do
      {:ok, bits} = HighLevelEncoder.encode("Hello")
      {:ok, decoded} = HighLevelDecoder.decode(bits)
      assert decoded == "Hello"
    end

    test "decodes digits" do
      {:ok, bits} = HighLevelEncoder.encode("12345")
      {:ok, decoded} = HighLevelDecoder.decode(bits)
      assert decoded == "12345"
    end

    test "decodes space" do
      {:ok, bits} = HighLevelEncoder.encode(" ")
      {:ok, decoded} = HighLevelDecoder.decode(bits)
      assert decoded == " "
    end

    test "decodes empty input" do
      {:ok, decoded} = HighLevelDecoder.decode([])
      assert decoded == ""
    end

    test "decodes punctuation" do
      {:ok, bits} = HighLevelEncoder.encode("!")
      {:ok, decoded} = HighLevelDecoder.decode(bits)
      assert decoded == "!"
    end

    test "decodes string with digits and letters" do
      {:ok, bits} = HighLevelEncoder.encode("ABC 123")
      {:ok, decoded} = HighLevelDecoder.decode(bits)
      assert decoded == "ABC 123"
    end

    test "roundtrip for various strings" do
      strings = [
        "A",
        "AB",
        "HELLO WORLD",
        "hello world",
        "Hello World",
        "12345",
        "ABC 123",
        " ",
        "TEST 123 TEST"
      ]

      for s <- strings do
        {:ok, bits} = HighLevelEncoder.encode(s)
        {:ok, decoded} = HighLevelDecoder.decode(bits)
        assert decoded == s, "roundtrip failed for #{inspect(s)}, got #{inspect(decoded)}"
      end
    end
  end
end
