defmodule Bitstamp_ETH do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(state) do
  	spawn(Bitstamp_ETH, :priceTicker, [])
    {:ok, state}
  end

  HTTPotion.start

  :mnesia.create_schema([])
  :mnesia.start()
  :mnesia.create_table(Ethereum, [attributes: [:exchange, :price]])


    


    def priceTicker() do
        response = HTTPotion.get("https://www.bitstamp.net/api/v2/ticker/etheur/", [body: "", headers: ["Content-type": "application/json", "User-Agent": "arbot"]])
        case response do
            %{:body => body, :headers => _headers} ->
                case Poison.decode(body) do
                    {:ok, decoded_body} ->
                        %{"ask" => _ask, 
                          "bid" => _bid, 
                          "last" => price, 
                          "high" => _high,
                          "low" => _low,
                          "timestamp" => _time, 
                          "vwap" => _vwap, 
                          "volume" => _vol,
                          "open" => _open
                        } = decoded_body
                        :mnesia.dirty_write({Ethereum, :bitstamp, String.to_float(price)})
                        :timer.sleep(3000)
                        Bitstamp_ETH.priceTicker
                        %{"message" => message} -> IO.inspect("[X] BITSTAMP ETH #{message}")
                    {:error, decoded_error} -> 
                        IO.inspect "BITSTAMP DECODE ERROR: #{decoded_error}"
                        :timer.sleep(3000)
                        Bitstamp_ETH.priceTicker
                end
            %{message: message} -> 
                IO.inspect "BITSTAMP REQUEST ERROR: #{message}"
                :timer.sleep(3000)
                Bitstamp_ETH.priceTicker
        end
    end

    def get_price() do
        state = :mnesia.dirty_read({Ethereum, :bitstamp})
        case state do
            [] -> "empty"
            [{Ethereum, :bitstamp, price}] -> price
        end
    end

end