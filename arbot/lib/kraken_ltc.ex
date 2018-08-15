defmodule Kraken_LTC do
    use GenServer

    def start_link do
      GenServer.start_link(__MODULE__, :ok, [])
    end

    def init(state) do
      spawn(Kraken_LTC, :priceTicker, [])
      {:ok, state}
    end

    HTTPotion.start

    :mnesia.create_schema([])
    :mnesia.start()
    :mnesia.create_table(Litecoin, [attributes: [:exchange, :price]])






  def priceTicker() do
    
    response = HTTPotion.get("https://api.kraken.com/0/public/Ticker?pair=LTCEUR", [body: "", headers: ["Content-type": "application/json", "User-Agent": "arbot"]])
    #pattern match kraken ETH-EUR ticker information and decode to variables
    case response do
      %{:body => body, :headers => _headers} ->
        case Poison.decode(body) do
          {:ok, decoded_body} -> 
            %{"error" => _error, "result" =>
            %{"XLTCZEUR" =>
              %{"a" => ask,
                "b" => _bid,
                "c" => _last,
                "v" => _vol,
                "p" => _prices,
                "t" => _trades,
                "l" => _low,
                "h" => _high,
                "o" => _opening}
              }
            } = decoded_body
            String.to_float((List.first(ask))) #function return with last asking price.
            :mnesia.dirty_write({Litecoin, :kraken, String.to_float((List.first(ask)))})
            :timer.sleep(3000)
            Kraken_LTC.priceTicker
          {:error, decoded_error} -> 
            IO.inspect "KRAKEN DECODE ERROR..May have encountered Kraken DDOS protection"
            :timer.sleep(3000)
            Kraken_LTC.priceTicker
        end
      %{message: message} -> 
        IO.inspect "KRAKEN REQUEST ERROR: #{message}"
        :timer.sleep(3000)
        Kraken_LTC.priceTicker
      _ -> 
        IO.inspect "May have encountered Kraken DDOS protection"
        :timer.sleep(5000)
        Kraken_LTC.priceTicker
    end
  end

  def get_price() do
      state = :mnesia.dirty_read({Litecoin, :kraken})
      case state do
        [] -> "empty"
        [{Litecoin, :kraken, price}] -> price
      end
  end

end