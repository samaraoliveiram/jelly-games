defmodule Jelly.Game.PlayerTest do
  use ExUnit.Case
  alias Jelly.Guess.Player

  describe "new/1" do
    test "returns a valid player" do
      nickname = "nickname"
      params = %{nickname: nickname}
      assert {:ok, %Player{nickname: ^nickname}} = Player.new(params)
    end

    test "return error if required values are missing" do
      assert {:error, %{errors: [nickname: {"can't be blank", _}]}} = Player.new(%{})
    end

    test "return error if nickname is short" do
      params = %{nickname: "A"}
      assert {:error, %{errors: [nickname: {_, _}]}} = Player.new(params)
    end
  end
end
