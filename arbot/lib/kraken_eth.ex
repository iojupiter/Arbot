defmodule Kraken_ETH do
    use GenServer

    def start_link do
      GenServer.start_link(__MODULE__, :ok, [])
    end

    def init(state) do
      spawn(Kraken_ETH, :priceTicker, [])
      {:ok, state}
    end

    HTTPotion.start

    :mnesia.create_schema([])
    :mnesia.start()
    :mnesia.create_table(Ethereum, [attributes: [:exchange, :price]])

    #gen paths
    case File.cwd do
      {:ok, path} -> 
        @path String.trim_trailing(path, "arbot")
      {:error, reason} -> IO.inspect reason
    end

    #aliases
    @error_log_path @path<>"error_log"
    @filled_orders @path<>"filled_orders"
    @other_k @path<>"other_k"

    case File.read @other_k do
      {:ok, data} ->
        data = String.split(data) |> List.to_tuple
        @a elem(data, 0)
        @sec elem(data, 1)
      {:error, error} -> IO.inspect error
    end

  def start_new_cycle do
    [{"Arbot", [arb, po, v, c, ti]}] = :ets.lookup(:cycles, "Arbot")
    case c-1 do
      x when x >= 1 -> 
        {{_y, _mo, _d}, {h, m, ss}} = :calendar.local_time()
        IO.inspect "[*] Starting next arbitrage cycle (#{x}), in #{ti} minutes after #{h}:#{m}:#{ss}"
        IO.puts "[---------------------------------ENDED ARB---------------------------------] \n \n"
        :timer.sleep(:timer.minutes(ti)) 
        #:ets.insert(:cycles, {"Arbot", [arb, po, v, c-1, ti]})
        Main.run_arbot(arb, po, v, c-1, ti)
      x when x <= 0 ->
        IO.puts "[----------------------------Arbot cycle finished----------------------------] \n \n"
    end
  end

  def log_filled(s) do
    p = Kraken_ETH.get_price
    f = String.to_float(s) * p
    {{_y, mo, d}, {h, m, ss}} = :calendar.local_time()
    File.write(@filled_orders, "Kraken buy: #{s} @ #{p} = #{f}\n")
    File.write(@filled_orders, "F--------#{d}/#{mo}--#{h}:#{m}:#{ss}---------\n \n \n \n")
    Kraken_ETH.start_new_cycle
  end

  def watch_order(s, time) do
    IO.inspect "[*] Checking if order was filled after DDOS response.."
    {:ok, sd} = Base.decode64(@sec)
    uri = "/0/private/ClosedOrders"
    nonce = :os.system_time(:seconds)*1000
    nonceString = Integer.to_string(nonce)
    start = time - 10
    postdata = "nonce=#{nonceString}&start=#{start}"
    signature = Base.encode64(:crypto.hmac(:sha512, sd, uri<>:crypto.hash(:sha256, nonceString<>postdata)))
    
    watchorder = HTTPotion.post("https://api.kraken.com/0/private/ClosedOrders",
      [body: postdata,
       headers: [
        "User-Agent": "arbot",
        "Content-type": "application/x-www-form-urlencoded",
        "API-Key": @a,
        "API-Sign": signature], timeout: 100_000]) #!timeout may affect request

    case watchorder do
      %{:body => body, :headers => _headers} ->
        case Poison.decode(body) do
          {:ok, %{"error" => [], "result" => %{"closed" => %{}, "count" => 0}}} ->
            IO.inspect "[X] Kraken buy order was not filled, placing new buy order"
            Kraken_ETH.buy_order(s)
          {:ok, %{"error" => [], "result" => %{"closed" => _closed,"count" => 1}}} ->
            IO.inspect "[*] Kraken buy order was filled!"
            Kraken_ETH.start_new_cycle
          {:error, {:invalid, "<", 0}} -> 
            IO.inspect "[X] Kraken DDOS protection on request: get recent fills..trying again"
            Kraken_ETH.watch_order(s, time)
        end
      %{message: message} ->
        IO.inspect "[X] Kraken watch order request error: #{message}"
    end
  end

  def buy_order(s) do
    IO.inspect "[*] Placing Kraken buy order for #{s} ether..."
    {:ok, sd} = Base.decode64(@sec)
    uri = "/0/private/AddOrder"
    nonce = :os.system_time(:seconds)*1000
    nonceString = Integer.to_string(nonce)
    pair = "ETHEUR"
    type = "buy"
    ordertype = "market"
    postdata = "nonce=#{nonceString}&pair=#{pair}&volume=#{s}&type=#{type}&ordertype=#{ordertype}"
    signature = Base.encode64(:crypto.hmac(:sha512, sd, uri<>:crypto.hash(:sha256, nonceString<>postdata)))
    
    buyorder = HTTPotion.post("https://api.kraken.com/0/private/AddOrder",
      [body: postdata,
       headers: [
        "User-Agent": "arbot",
        "Content-type": "application/x-www-form-urlencoded",
        "API-Key": @a,
        "API-Sign": signature], timeout: 100_000]) #!timeout may affect request

    time = :os.system_time(:seconds) #time we place buy order

    case buyorder do
      %{:body => body, :headers => _headers} ->
        #IO.inspect body
        case Poison.decode(body) do
          {:ok, %{"error" => [], "result" => _result}} ->
            IO.inspect "[*] Kraken buy order successful!"
            Kraken_ETH.log_filled(s)
          {:ok, %{"error" => error}} ->
            case error do
              {:error, {:invalid, "<", 0}} -> 
                IO.inspect "[X] Kraken DDOS protection. However, order may have been filled!"
                IO.inspect "[X] Checking whether order was filled..."
                Kraken_ETH.watch_order(s, time)
              other -> IO.inspect "[X] Some error was responded by Kraken: #{other}. Arbot stopped"
            end
          {:error, {:invalid, "<", 0}} -> 
            IO.inspect "[X] Kraken DDOS protection. However, order may have been filled!"
            IO.inspect "[X] Checking whether order was filled..."
            Kraken_ETH.watch_order(s, time)
          _other -> IO.inspect "[XXX] Some other response was produced."
        end
      %{message: message} -> 
        IO.inspect "[X] KRAKEN BUY ORDER REQUEST ERROR: #{message} consider increasing timeout..persisting in 5 secs"
    end
  end

  def priceTicker() do
    
    response = HTTPotion.get("https://api.kraken.com/0/public/Ticker?pair=ETHEUR", 
      [body: "", 
       headers: ["Content-type": "application/json", "User-Agent": "arbot"], timeout: 10_000])
    #pattern match kraken ETH-EUR ticker information and decode to variables
    case response do
      %{:body => body, :headers => _headers} ->
        case Poison.decode(body) do
          {:ok, %{"error" => [error]}} ->
            IO.inspect "[XXX] Kraken produced a fatal error: #{error}."
            IO.inspect "[XXX] Exchange may be down. Unable to fetch prices." #DOUBLE CHECK !!!
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
            :mnesia.dirty_write({Ethereum, :kraken, String.to_float((List.first(ask)))})
            :timer.sleep(3000)
            Kraken_ETH.priceTicker
          {:error, _decoded_error} -> 
            File.write(@error_log_path, "KRAKEN DECODE ERROR..May have encountered Kraken DDOS protection \n")
            :timer.sleep(3000)
            Kraken_ETH.priceTicker
        end
      %{message: message} -> 
        File.write(@error_log_path, "KRAKEN PRICE REQUEST ERROR: #{message} \n")
        :timer.sleep(3000)
        Kraken_ETH.priceTicker
      _x -> 
        File.write(@error_log_path, "May have encountered Kraken DDOS protection \n")
        :timer.sleep(5000)
        Kraken_ETH.priceTicker
    end
  end

  def get_price() do
      state = :mnesia.dirty_read({Ethereum, :kraken})
      case state do
        [] -> "empty"
        [{Ethereum, :kraken, price}] -> price
      end
  end
  
end