defmodule AztecEx.IntegrationTest do
  use ExUnit.Case, async: true

  describe "full encode-decode roundtrip" do
    @roundtrip_cases [
      {"single char", "A"},
      {"uppercase", "HELLO WORLD"},
      {"lowercase", "hello world"},
      {"mixed case", "Hello World"},
      {"digits only", "1234567890"},
      {"alphanumeric", "ABC 123 DEF"},
      {"with punctuation", "HELLO, WORLD!"},
      {"space", " "},
      {"repeated chars", "AAAAAAA"},
      {"all upper alpha", "ABCDEFGHIJKLMNOPQRSTUVWXYZ"},
      {"all digits", "0123456789"},
      {"short message", "OK"},
      {"medium message", "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG"}
    ]

    for {label, data} <- @roundtrip_cases do
      @tag label: label
      test "roundtrip: #{label}" do
        data = unquote(data)
        assert {:ok, code} = AztecEx.encode(data)
        assert {:ok, ^data} = AztecEx.decode(code.matrix)
      end
    end
  end

  describe "encode-decode with forced compact" do
    test "compact mode roundtrip" do
      data = "HELLO"
      assert {:ok, code} = AztecEx.encode(data, compact: true)
      assert code.compact == true
      assert {:ok, ^data} = AztecEx.decode(code.matrix)
    end
  end

  describe "encode-decode with forced full" do
    test "full mode roundtrip" do
      data = "HELLO WORLD"
      assert {:ok, code} = AztecEx.encode(data, compact: false)
      assert code.compact == false
      assert {:ok, ^data} = AztecEx.decode(code.matrix)
    end
  end

  describe "code struct integrity" do
    test "compact code has correct structure" do
      {:ok, code} = AztecEx.encode("TEST")
      assert code.compact == true
      assert code.layers >= 1
      assert code.codeword_size in [4, 6, 8, 10, 12]
      assert code.data_codewords >= 1
      assert code.size > 0
      {w, h} = AztecEx.BitMatrix.dimensions(code.matrix)
      assert w == code.size
      assert h == code.size
    end

    test "full code has correct structure" do
      {:ok, code} = AztecEx.encode("FULL CODE TEST", compact: false)
      assert code.compact == false
      assert code.layers >= 1
      assert code.codeword_size in [6, 8, 10, 12]
      assert code.data_codewords >= 1
      assert code.size > 0
    end
  end

  describe "public API render integration" do
    test "to_svg returns valid SVG" do
      {:ok, code} = AztecEx.encode("HELLO")
      svg = AztecEx.to_svg(code)
      assert String.starts_with?(svg, "<?xml")
      assert String.contains?(svg, "</svg>")
    end

    test "to_text returns multi-line string" do
      {:ok, code} = AztecEx.encode("HELLO")
      text = AztecEx.to_text(code)
      lines = String.split(text, "\n")
      assert length(lines) == code.size
    end

    test "encode then render then decode roundtrip" do
      data = "RENDER TEST"
      {:ok, code} = AztecEx.encode(data)

      svg = AztecEx.to_svg(code, module_size: 8)
      assert String.contains?(svg, "<svg")

      text = AztecEx.to_text(code, dark: "#", light: ".")
      assert String.contains?(text, "#")

      {:ok, ^data} = AztecEx.decode(code.matrix)
    end
  end

  describe "error handling" do
    test "decode empty matrix returns error" do
      matrix = AztecEx.BitMatrix.new(10)
      assert {:error, _} = AztecEx.decode(matrix)
    end

    test "encode empty string produces valid code" do
      assert {:ok, %AztecEx.Code{data_codewords: 0}} = AztecEx.encode("")
    end
  end
end
