defmodule AztecEx.Render.SVGTest do
  use ExUnit.Case, async: true

  alias AztecEx.{BitMatrix, Encoder}
  alias AztecEx.Render.SVG

  describe "render/2" do
    test "produces valid SVG string" do
      matrix =
        BitMatrix.from_list([
          [true, false],
          [false, true]
        ])

      svg = SVG.render(matrix)
      assert String.starts_with?(svg, "<?xml")
      assert String.contains?(svg, "<svg")
      assert String.contains?(svg, "</svg>")
    end

    test "contains correct number of dark module rects" do
      matrix =
        BitMatrix.from_list([
          [true, false, true],
          [false, true, false],
          [true, false, true]
        ])

      svg = SVG.render(matrix)
      rect_count = length(String.split(svg, "<rect")) - 1
      # 5 dark modules + 1 background rect = 6 total rects
      assert rect_count == 6
    end

    test "respects module_size option" do
      matrix = BitMatrix.from_list([[true]])
      svg = SVG.render(matrix, module_size: 10)
      assert String.contains?(svg, ~s(width="10"))
      assert String.contains?(svg, ~s(height="10"))
    end

    test "respects custom colors" do
      matrix = BitMatrix.from_list([[true]])
      svg = SVG.render(matrix, dark_color: "#FF0000", light_color: "#00FF00")
      assert String.contains?(svg, "#FF0000")
      assert String.contains?(svg, "#00FF00")
    end

    test "respects margin option" do
      matrix = BitMatrix.from_list([[true]])
      svg = SVG.render(matrix, module_size: 1, margin: 5)
      # Total size: (1 + 2*5) * 1 = 11
      assert String.contains?(svg, ~s(viewBox="0 0 11 11"))
    end

    test "empty matrix produces just background" do
      matrix = BitMatrix.new(0, 0)
      svg = SVG.render(matrix)
      assert String.contains?(svg, "<svg")
      assert String.contains?(svg, "</svg>")
    end
  end

  describe "render_code/2" do
    test "renders encoded Aztec code" do
      {:ok, code} = Encoder.encode("HELLO")
      svg = SVG.render_code(code)
      assert String.starts_with?(svg, "<?xml")
      assert String.contains?(svg, "<svg")
      assert String.contains?(svg, "</svg>")
      assert String.contains?(svg, "<rect")
    end

    test "rendered SVG has correct total dimensions" do
      {:ok, code} = Encoder.encode("TEST")
      svg = SVG.render_code(code, module_size: 4, margin: 2)
      expected_size = (code.size + 4) * 4
      assert String.contains?(svg, ~s(width="#{expected_size}"))
    end
  end
end
