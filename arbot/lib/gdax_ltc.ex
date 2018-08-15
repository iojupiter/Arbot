defmodule Gdax_LTC do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(state) do
  	spawn(Gdax_LTC, :priceTicker, [])
    {:ok, state}
  end

  HTTPotion.start

  :mnesia.create_schema([])
  :mnesia.start()
  :mnesia.create_table(Litecoin, [attributes: [:exchange, :price]])




    def priceTicker() do
        response = HTTPotion.get("https://api.gdax.com/products/LTC-EUR/ticker", [body: "", headers: ["Content-type": "application/json", "User-Agent": "arbot"]])
        case response do
            %{:body => body, :headers => _headers} ->
                case Poison.decode(body) do
                    {:ok, decoded_body} ->
                        %{"ask" => _ask, 
                          "bid" => _bid, 
                          "price" => price, 
                          "size" => _size, 
                          "time" => _time, 
                          "trade_id" => _trade_id, 
                          "volume" => _vol
                        } = decoded_body
                        :mnesia.dirty_write({Litecoin, :gdax, String.to_float(price)})
                        :timer.sleep(3000)
                        Gdax_LTC.priceTicker
                        %{"message" => message} -> IO.inspect("[X] GDAX LTC #{message}")
                    {:error, decoded_error} -> 
                        IO.inspect "GDAX DECODE ERROR: #{decoded_error}"
                        :timer.sleep(3000)
                        Gdax_LTC.priceTicker
                end
            %{message: message} -> 
                IO.inspect "GDAX REQUEST ERROR: #{message}"
                :timer.sleep(3000)
                Gdax_LTC.priceTicker
        end
    end

    def get_price() do
        state = :mnesia.dirty_read({Litecoin, :gdax})
        case state do
            [] -> "empty"
            [{Litecoin, :gdax, price}] -> price
        end
    end

    def get_timestamp() do
    	tr = HTTPotion.get("https://api.gdax.com/time", [body: "", headers: ["Content-type": "application/json", "User-Agent": "arbot"]])
        case tr do
            %{:body => body, :headers => _headers} ->
                case Poison.decode(body) do
                    {:ok, %{"epoch" => timestamp, "iso" => _iso}} -> Kernel.inspect(timestamp)
                    {:error, decoded_error} -> 
                        IO.inspect "[X] GDAX TIMESTAMP DECODE ERROR: #{decoded_error}"
                        Gdax_LTC.get_timestamp
                end
            %{message: message} -> 
                IO.inspect "[X] GDAX TIMESTAMP REQUEST ERROR: #{message}"
                Gdax_LTC.get_timestamp
        end
    end


end