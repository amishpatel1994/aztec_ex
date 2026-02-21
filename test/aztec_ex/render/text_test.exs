defmodule AztecEx.Render.TextTest do
  use ExUnit.Case, async: true

  alias AztecEx.{BitMatrix, Encoder}
  alias AztecEx.Render.Text

  describe "render/2" do
    test "renders 2x2 matrix with default chars" do
      matrix =
        BitMatrix.from_list([
          [true, false],
          [false, true]
        ])

      result = Text.render(matrix)
      lines = String.split(result, "\n")
      assert length(lines) == 2
      assert Enum.at(lines, 0) == "██  "
      assert Enum.at(lines, 1) == "  ██"
    end

    test "renders with custom dark/light characters" do
      matrix = BitMatrix.from_list([[true, false, true]])
      result = Text.render(matrix, dark: "#", light: ".")
      assert result == "#.#"
    end

    test "renders with custom newline" do
      matrix =
        BitMatrix.from_list([
          [true],
          [false]
        ])

      result = Text.render(matrix, dark: "X", light: ".", newline: "|")
      assert result == "X|."
    end

    test "renders empty matrix" do
      matrix = BitMatrix.new(0, 0)
      result = Text.render(matrix)
      assert result == ""
    end

    test "renders all-black matrix" do
      matrix =
        BitMatrix.from_list([
          [true, true],
          [true, true]
        ])

      result = Text.render(matrix, dark: "#", light: ".")
      assert result == "##\n##"
    end
  end

  describe "render_code/2" do
    test "renders encoded Aztec code as text" do
      {:ok, code} = Encoder.encode("HELLO")
      result = Text.render_code(code)
      lines = String.split(result, "\n")
      assert length(lines) == code.size
    end

    test "renders with custom single-char options" do
      {:ok, code} = Encoder.encode("A")
      result = Text.render_code(code, dark: "X", light: " ")
      assert String.contains?(result, "X")
      assert String.contains?(result, " ")
    end
  end
end
