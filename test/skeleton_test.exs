defmodule Veggy.SkeletonTest do
  use ExUnit.Case, async: true
  use Plug.Test

  setup_all do
    Mongo.run_command(Veggy.MongoDB, [dropDatabase: 1])
  end

  test "GET /ping" do
    conn = conn(:get, "/ping") |> call

    assert conn.status == 200
    assert conn.resp_body == "pong"
  end

  test "anything else returns 404" do
    conn = conn(:get, "/not-a-valid-route") |> call

    assert conn.status == 404
    assert conn.resp_body == "oops"
  end

  @opts Veggy.HTTP.init([])

  defp call(conn), do: Veggy.HTTP.call(conn, @opts)
end
