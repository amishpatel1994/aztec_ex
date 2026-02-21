defmodule AztecExTest do
  use ExUnit.Case, async: true

  test "module exists" do
    assert Code.ensure_loaded?(AztecEx)
  end

  test "encode/1 returns not yet implemented stub" do
    assert {:error, "not yet implemented"} = AztecEx.encode("test")
  end

  test "decode/1 returns not yet implemented stub" do
    assert {:error, "not yet implemented"} = AztecEx.decode(nil)
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
