defmodule AztecExTest do
  use ExUnit.Case, async: true

  test "module exists" do
    assert Code.ensure_loaded?(AztecEx)
  end

  test "encode/1 produces a valid Code struct" do
    assert {:ok, %AztecEx.Code{} = code} = AztecEx.encode("Hello")
    assert code.compact == true
    assert code.layers >= 1
    assert code.size > 0
    assert code.matrix != nil
  end

  test "encode/1 handles empty string" do
    assert {:ok, %AztecEx.Code{}} = AztecEx.encode("")
  end

  test "encode then decode roundtrip" do
    {:ok, code} = AztecEx.encode("HELLO")
    {:ok, decoded} = AztecEx.decode(code.matrix)
    assert decoded == "HELLO"
  end

  test "AztecEx.Code struct has expected fields" do
    code = %AztecEx.Code{}
    assert Map.has_key?(code, :matrix)
    assert Map.has_key?(code, :compact)
    assert Map.has_key?(code, :layers)
    assert Map.has_key?(code, :codeword_size)
    assert Map.has_key?(code, :data_codewords)
    assert Map.has_key?(code, :size)
  end
end
