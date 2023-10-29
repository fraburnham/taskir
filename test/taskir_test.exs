defmodule TaskirTest do
  use ExUnit.Case
  doctest Taskir

  test "greets the world" do
    assert Taskir.hello() == :world
  end
end
