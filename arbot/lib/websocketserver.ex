defmodule WebsocketServer do
  use GenServer
  require Socket.Web

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(state) do
    :ets.new(:ws_clients, [:set, :public, :named_table])
    server = Socket.Web.listen!(8080)
    spawn(fn -> accept(server) end)
    {:ok, state}
  end

  defp accept(server) do
    client = Socket.Web.accept!(server)
    Socket.Web.accept!(client)
    :ets.insert_new(:ws_clients, {"client", [client]})

    Socket.Web.send!(client, {:text, "prices"})
    spawn(fn -> fromclient(client, server) end)
  end

  defp fromclient(client, server) do
    Socket.Web.recv!(client)
    |> IO.inspect
  end
  	#start server
  	#server = Socket.Web.listen!(8080)
  	#clients
  	#client = Socket.Web.accept!(server)
  	#accept client
  	#Socket.Web.accept!(client)

  	#server page

  def server_send(data) do
    [{"client", [client]}] = :ets.lookup(:ws_clients, "client")
    Socket.Web.send!(client, {:text, data})
  end
end