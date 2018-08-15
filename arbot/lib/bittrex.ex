defmodule Bittrex do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(state) do
  	spawn(Bittrex, :priceTicker, [])
    {:ok, state}
  end

  HTTPotion.start

  :mnesia.create_schema([])
  :mnesia.start()
  :mnesia.create_table(Ethereum, [attributes: [:exchange, :price]])







  def buy_order(amount) do
    IO.inspect("Placing ETH buy order for #{amount}")
  end


  def priceTicker() do
    price_uri = "https://bittrex.com/api/v1.1/public/getticker?market=USDT-ETH"
    response = HTTPotion.get(price_uri, [body: "", headers: ["Content-type": "application/json"]])
    case response do
      %{body: body, headers: _headers} -> 
         {:ok, data} = Poison.decode(body)
         %{"Ask" => _ask,
           "Bid" => _bid,
           "Last"=> price} = data["result"]
         :mnesia.dirty_write({Ethereum, :bittrex, price})
         :timer.sleep(2000)
         Bittrex.priceTicker
      %{message: error} ->       #RIGHT FAILURE CATCH??
        :timer.sleep(4000)
        Bittrex.priceTicker
    end
  end


  def read_price_bittrex() do
    state = :mnesia.dirty_read({Ethereum, :bittrex})
    case state do
      [] -> "empty"
      [{Ethereum, :bittrex, price}] -> price
    end
  end

end