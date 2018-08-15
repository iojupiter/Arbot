defmodule Arbot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      #%{id: Arbot, start: {Arbot, :start_link, []}},
      %{id: Gdax_ETH, start: {Gdax_ETH, :start_link, []}},
      %{id: Kraken_ETH, start: {Kraken_ETH, :start_link, []}},
      #%{id: WebsocketServer, start: {WebsocketServer, :start_link, []}},
      %{id: Gdax_LTC, start: {Gdax_LTC, :start_link, []}},
      %{id: Kraken_LTC, start: {Kraken_LTC, :start_link, []}},
      #%{id: Bitstamp_ETH, start: {Bitstamp_ETH, :start_link, []}},
      %{id: Main, start: {Main, :start_link, []}},
      #%{id: Poloniex, start: {Poloniex, :start_link, []}},
      #%{id: Bittrex, start: {Bittrex, :start_link, []}},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Arbot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end