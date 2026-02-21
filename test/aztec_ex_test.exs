defmodule AztecExTest do
  use ExUnit.Case, async: true

  test "module exists" do
    assert Code.ensure_loaded?(AztecEx)
  end
end
