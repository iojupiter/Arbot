defmodule Arbot do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(state) do
    #spawn(Arbot, :gdax, [])
    #spawn(Arbot, :kraken, [])
    {:ok, state}
  end

  #start HTTPotion HTTP request builder application
  HTTPotion.start

  :mnesia.create_schema([])
  :mnesia.start()
  :mnesia.create_table(Ethereum, [attributes: [:exchange, :price]])


  def main(entry_price, arb_level) do
    #get the gdax ETH-EUR price
    gdax_price = Arbot.gdax()

    case gdax_price do
      gdax_price when is_float(gdax_price) ->
        case gdax_price do
          gdax_price when gdax_price - entry_price >= arb_level ->
            IO.puts "GDAX position + #{arb_level} Euro. ACTUAL GDAX: #{gdax_price}, ENTRY GDAX: #{entry_price}"
            IO.puts "Checking possible arbitrage of + #{arb_level} Euro...GDAX/Kraken"
            kraken_price = Arbot.kraken()
            case kraken_price do
              kraken_price when is_float(kraken_price) ->
                if gdax_price - kraken_price >= arb_level do
                  IO.puts "Aribtrage found!"
                  IO.puts "GDAX: #{gdax_price}, KRAKEN: #{kraken_price}, Arbitrage: #{gdax_price-kraken_price} Euro"
                  IO.puts "CONTROL TO ACTION"
                  IO.puts("-----------------------------------------------------------------------------------------")
                  Arbot.sell_order(gdax_price)
                else
                  IO.puts "No arbitrage found"
                  IO.puts "GDAX: #{gdax_price}, KRAKEN: #{kraken_price}, Arbitrage: #{gdax_price-kraken_price} Euro"
                  IO.puts("-----------------------------------------------------------------------------------------")
                  :timer.sleep(5000)
                  Arbot.main(entry_price, arb_level)
                end
              kraken_price when is_bitstring(kraken_price) -> 
                IO.puts "NOT price value: '#{kraken_price}', value from kraken, request again"
                IO.puts("-----------------------------------------------------------------------------------------")
                :timer.sleep(10000)
                Arbot.main(entry_price, arb_level)
            end
          gdax_price when gdax_price - entry_price <= arb_level ->
            IO.puts "Below + #{arb_level} eur. ACTUAL GDAX: #{gdax_price}, ENTRY GDAX: #{entry_price}"
            IO.puts("-----------------------------------------------------------------------------------------")
            :timer.sleep(5000)
            Arbot.main(entry_price, arb_level)
        end
      gdax_price when is_bitstring(gdax_price) -> 
        IO.puts "NOT price value: '#{gdax_price}', value from gdax, request again"
        IO.puts("-----------------------------------------------------------------------------------------")
        :timer.sleep(10000)
        Arbot.main(entry_price, arb_level)
    end
  end


  def sell_order(gdax_price) do
    IO.puts "Placing sell orders"
    
    a = "" #api key
    s = "" #secret
    {:ok, sd} = Base.decode64(s)
    p = "" #passkey
    
    #bad timestamp response.
    time_req = HTTPotion.get("https://api.gdax.com/time", [body: "", headers: ["Content-type": "application/json", "User-Agent": "arbot"]])
    case time_req do
      %{:body => body, :headers => _headers} ->
        case Poison.decode(body) do
          {:ok, %{"epoch" => epoch, "iso" => _iso}} -> 
            timestamp = epoch
          {:error, decoded_error} -> 
            IO.inspect "GDAX TIMESTAMP DECODE ERROR: #{decoded_error}"
        end
      %{message: message} -> 
        IO.inspect "GDAX TIMESTAMP REQUEST ERROR: #{message}"
    end

    method = "POST"
    requestPath = "/orders"

    price = gdax_price + 0.1 
    |> :erlang.float_to_binary([decimals: 2]) |> String.to_float()
    amount = 0.01
    #order_body = Poison.encode!(%{"price"=> price,"size" => amount, "side" => "buy", "product_id" => "ETH-EUR"})
    order_body = Poison.encode!(%{"price"=> price,"size" => amount, "side" => "sell", "product_id" => "LTC-EUR"})
    prehash = Kernel.inspect(timestamp) <> method <> requestPath <> order_body
    signature = Base.encode64(:crypto.hmac(:sha256, sd, prehash))


    order = HTTPotion.post("https://api.gdax.com/orders", [body: order_body,
      headers: [
      "Content-type": "application/json", 
      "User-Agent": "arbot",
      "CB-ACCESS-KEY": a,
      "CB-ACCESS-SIGN": signature,
      "CB-ACCESS-TIMESTAMP": timestamp,
      "CB-ACCESS-PASSPHRASE": p
         ]
      ])

    case order do
      %{:body => body, :headers => _headers} ->
        case Poison.decode(body) do
          {:ok, order_reponse} ->
            case order_reponse do
              %{"id" => order_id,
                "price" => op,
                "size" => amnt,
                "product_id" => _product_id,
                "side" => _side,
                "stp" => _stp,
                "type" => _type,
                "time_in_force" => _tif,
                "post_only" => _post_only,
                "created_at" => _created_at,
                "fill_fees" => _fees,
                "filled_size" => _filled_size,
                "executed_value" => _executed_value,
                "status" => _status,
                "settled" => _settled} ->
                  IO.inspect "ORDER PLACE"
                  IO.inspect "Order ID #{order_id}"
                  IO.inspect "Price #{op} Eur"
                  IO.inspect "Amount #{amnt} ETH"
                  Arbot.watch_order(order_id)
              %{"message" => message} ->
                IO.inspect message
            end
          {:error, decoded_error} -> 
            IO.inspect "GDAX PLACE ORDER DECODE ERROR: #{decoded_error}"
        end
      %{message: message} ->
        IO.inspect "GDAX PLACE ORDER REQUEST ERROR: #{message}"
    end
  end


  def watch_order(order_id) do
    IO.inspect "Watching order #{order_id}"

    a = "" #api key
    s = "" #secret
    {:ok, sd} = Base.decode64(s)
    p = "11igj8xgx87k"

    time_req = HTTPotion.get("https://api.gdax.com/time", [body: "", headers: ["Content-type": "application/json", "User-Agent": "arbot"]])
    case time_req do
      %{:body => body, :headers => _headers} ->
        case Poison.decode(body) do
          {:ok, %{"epoch" => epoch, "iso" => _iso}} -> 
            timestamp = epoch
          {:error, decoded_error} -> 
            IO.inspect "GDAX TIMESTAMP DECODE ERROR: #{decoded_error}"
        end
      %{message: message} -> 
        IO.inspect "GDAX TIMESTAMP REQUEST ERROR: #{message}"
    end

    method = "GET"
    requestPath = "/orders/" <> order_id

    prehash = Kernel.inspect(timestamp) <> method <> requestPath <> ""
    signature = Base.encode64(:crypto.hmac(:sha256, sd, prehash))

    watch_order = HTTPotion.get("https://api.gdax.com/orders/#{order_id}", [body: "",
      headers: [
      "Content-type": "application/json", 
      "User-Agent": "arbot",
      "CB-ACCESS-KEY": a,
      "CB-ACCESS-SIGN": signature,
      "CB-ACCESS-TIMESTAMP": timestamp,
      "CB-ACCESS-PASSPHRASE": p
         ]  
      ])

    case watch_order do
      %{:body => body, :headers => _headers} ->
        case Poison.decode(body) do
          {:ok, order_state} ->
            case order_state do
              %{"id" => _id,
                "price" => _p,
                "size" => _size,
                "product_id" => _pid,
                "side" => _side,
                "stp" => _stp,
                "funds" => _funds,
                "specified_funds" => _sf,
                "type" => _t,
                "post_only" => _po,
                "created_at" => _ca,
                "done_at" => _da,
                "done_reason" => _done_reason,
                "fill_fees" => _ff,
                "filled_size" => _fs,
                "executed_value" => _ev,
                "status" => status,
                "time_in_force" => _tif,
                "settled" => settled} -> IO.inspect "STATUS: #{status}, SETTLED: #{settled}"
              %{"id" => _id,
                "price" => p,
                "size" => s,
                "product_id" => _pid,
                "side" => _side,
                "stp" => _stp,
                "type" => _t,
                "post_only" => _po,
                "created_at" => _ca,
                "fill_fees" => _ff,
                "filled_size" => _fs,
                "executed_value" => _ev,
                "status" => status,
                "time_in_force" => _tif,
                "settled" => settled} -> 
                  case status do
                    "open" -> 
                      IO.inspect "STATUS: #{status}, SETTLED: #{settled}"
                      :timer.sleep(3000)
                      Arbot.watch_order(order_id)
                    "done" -> 
                      IO.inspect "STATUS: #{status}, SETTLED: #{settled}"
                      Arbot.buy_order_kraken(s)
                    "NotFound" -> 
                      IO.inspect "ORDER NOT FOUND, may have been removed"
                      IO.inspect "NEW ARB WATCH" #need entry price and arb leve!
                  end
              %{"message" => message} ->
                IO.inspect message
            end
          {:error, decoded_error} -> 
            IO.inspect "GDAX PLACE ORDER DECODE ERROR: #{decoded_error}"
        end

    end
  end


  def buy_order_kraken(s) do
    IO.inspect "SETTING BUY ORDER KRAKEN FOR #{s} ETHER"

    a = "" #api key?
    sec = "" #secret
    {:ok, sd} = Base.decode64(sec)

    uri = "/0/private/AddOrder"
    nonce = Integer.to_string(:os.system_time(:milli_seconds)) # <> "0"
    body = "nonce="<>nonce
    signature = Base.encode64(:crypto.hmac(:sha512, sd, uri<>:crypto.hash(:sha256, nonce<>body)))
 
    HTTPotion.post("https://api.kraken.com/0/private/AddOrder",
      [body: body,
      headers: [
      "Content-type": "application/json", 
      "User-Agent": "arbot",
      "API-Key": a,
      "API-Sign": signature,
         ]  
      ])

  end





  #PRICE TICKERS#
  def gdax() do

    response = HTTPotion.get("https://api.gdax.com/products/ETH-EUR/ticker", [body: "", headers: ["Content-type": "application/json", "User-Agent": "arbot"]])
    #pattern match the ETH-EUR ticker and decode information to variables
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
          :mnesia.dirty_write({Ethereum, :gdax, String.to_float(price)})
          :timer.sleep(3000)
          Arbot.gdax
          {:error, decoded_error} -> 
            IO.inspect "GDAX DECODE ERROR: #{decoded_error}"
            :timer.sleep(3000)
            Arbot.gdax
        end
      %{message: message} -> 
        IO.inspect "GDAX REQUEST ERROR: #{message}"
        :timer.sleep(3000)
        Arbot.gdax
    end
  end

  def kraken() do
    
    response = HTTPotion.get("https://api.kraken.com/0/public/Ticker?pair=ETHEUR", [body: "", headers: ["Content-type": "application/json", "User-Agent": "arbot"]])
    #pattern match kraken ETH-EUR ticker information and decode to variables
    case response do
      %{:body => body, :headers => _headers} ->
        case Poison.decode(body) do
          {:ok, decoded_body} -> 
            %{"error" => _error, "result" =>
            %{"XETHZEUR" =>
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
            :mnesia.dirty_write({Ethereum, :kraken, String.to_float((List.first(ask)))})
            :timer.sleep(3000)
            Arbot.kraken
          {:error, decoded_error} -> 
            IO.inspect "KRAKEN DECODE ERROR: #{decoded_error}"
            :timer.sleep(3000)
            Arbot.kraken
        end
      %{message: message} -> 
        IO.inspect "KRAKEN REQUEST ERROR: #{message}"
        :timer.sleep(3000)
        Arbot.kraken
    end
  end
  #PRICE TICKERS#

  def get_price(exchange) do
    state = :mnesia.dirty_read({Ethereum, exchange})
    case state do
      [] -> "empty"
      [{Ethereum, exchange, price}] -> price
    end
  end

end
