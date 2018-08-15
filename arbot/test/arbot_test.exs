defmodule ArbotTest do
  use ExUnit.Case
  doctest Arbot

  test "greets the world" do
    assert Arbot.hello() == :world
  end
end
