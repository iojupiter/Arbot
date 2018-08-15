defmodule Gdax_ETH do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(state) do
  	:timer.sleep(5000)
  	spawn(Gdax_ETH, :priceTicker, [])
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
    @other_g @path<>"other_g"

    case File.read @other_g do
      {:ok, data} ->
        data = String.split(data) |> List.to_tuple
        @a elem(data, 0)
        @s elem(data, 1)
        @p elem(data, 2)
      {:error, error} -> IO.inspect error
    end


  def log_filled(s, p) do
    {{_y, mo, d}, {h, m, ss}} = :calendar.local_time()
    f = String.to_float(s) * String.to_float(p)
    File.write(@filled_orders, "S--------#{d}/#{mo}--#{h}:#{m}:#{ss}---------\n")
    File.write(@filled_orders, "Gdax sell: #{s} @ #{p} = #{f}\n")
  end

	def watch_order(order_id) do
    	{:ok, sd} = Base.decode64(@s)
    	timestamp = Gdax_ETH.get_timestamp
    	prehash = timestamp<>"GET"<>"/orders/"<>order_id<>""
		  signature = Base.encode64(:crypto.hmac(:sha256, sd, prehash))

    	watch_order = HTTPotion.get("https://api.gdax.com/orders/#{order_id}", 
    		[body: "",
      		headers: [
      			"Content-type": "application/json", 
      			"User-Agent": "arbot",
      			"CB-ACCESS-KEY": @a,
      			"CB-ACCESS-SIGN": signature,
      			"CB-ACCESS-TIMESTAMP": timestamp,
      			"CB-ACCESS-PASSPHRASE": @p]
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
                			"settled" => settled} -> 
                				IO.inspect "STATUS: #{status}, SETTLED: #{settled}"
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
                			"settled" => _settled} -> 
                  				case status do
                    				"open" -> 
                      					IO.inspect "[-] Gdax sell order status: #{status}"
                      					:timer.sleep(3000)
                      					Gdax_ETH.watch_order(order_id)
                	    			"done" -> 
                    	  				IO.inspect "[*] Gdax sell order completed: #{status}"
                                Gdax_ETH.log_filled(s, p)
                      					#spawn(Gdax_ETH, :withdraw, [amount])
                      					Kraken_ETH.buy_order(s)
                  				end
              				%{"message" => message} ->
                				IO.inspect message
                        IO.inspect "[X] ORDER NOT FOUND, may have been removed"
                        IO.inspect "NEW ARB WATCH?!?" #need entry price and arb leve!
            			end
          			{:error, decoded_error} -> 
            			IO.inspect "[X] GDAX PLACE ORDER DECODE ERROR: #{decoded_error}"
        		end
        	%{message: message} ->
        		IO.inspect "[X] GDAX WATCH ORDER REQUEST ERROR: #{message}"
        end
	end

    def sell_order(g, po, v) do

        {:ok, sd} = Base.decode64(@s)
        timestamp = Gdax_ETH.get_timestamp

        price = g + po |> :erlang.float_to_binary([decimals: 2]) |> String.to_float
        #price = g + 0.1 |> :erlang.float_to_binary([decimals: 2]) |> String.to_float
        #price = g + 300 |> :erlang.float_to_binary([decimals: 2]) |> String.to_float
        body = Poison.encode!(%{"price"=> price,
    						"size" => v,
                "type" => "limit",
    						"side" => "sell", 
    						"product_id" => "ETH-EUR"})
        prehash = timestamp<>"POST"<>"/orders"<>body
        signature = Base.encode64(:crypto.hmac(:sha256, sd, prehash))

        order = HTTPotion.post("https://api.gdax.com/orders", 
        [body: body,
        headers: [
        "Content-type": "application/json", 
        "User-Agent": "arbot",
        "CB-ACCESS-KEY": @a,
        "CB-ACCESS-SIGN": signature,
        "CB-ACCESS-TIMESTAMP": timestamp,
        "CB-ACCESS-PASSPHRASE": @p]])

        case order do
            %{:body => body, :headers => _headers} ->
                case Poison.decode(body) do
                    {:ok, order_reponse} ->
                        case order_reponse do
                            %{"id" => order_id,
                              "price" => _op,
                              "size" => _amnt,
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
                                IO.inspect "[*] Gdax sell order placed: #{order_id}"
                                Gdax_ETH.watch_order(order_id)
                            %{"message" => message} ->
                                IO.inspect message
                        end
                    {:error, decoded_error} -> 
                        IO.inspect "[X] GDAX PLACE ORDER DECODE ERROR: #{decoded_error}"
                end
            %{message: message} ->
                IO.inspect "[X] GDAX PLACE ORDER REQUEST ERROR: #{message}"
        end
    end

    #Start here: entry_price, profit, arbitrage, volume
    def probe_profit(arb, po, v) do
      g = Gdax_ETH.get_price
      k = Kraken_ETH.get_price
      case g do
        g when is_float(g) -> 
          cond do
            g - k >= arb ->
              IO.inspect "[*] Arbitrage Found! Above: #{arb}"
              Gdax_ETH.sell_order(g, po, v)
            g - k <= arb ->
              IO.inspect "[-] Arbitrage not found"
              :timer.sleep(3000)
              Gdax_ETH.probe_profit(arb, po, v)
          end
        g when is_bitstring(g) ->
          IO.inspect "[X] not a price value!"
          :timer.sleep(1000)
          Gdax_ETH.probe_profit(arb, po, v)
      end
    end

    def priceTicker() do
        response = HTTPotion.get("https://api.gdax.com/products/ETH-EUR/ticker", [body: "", headers: ["Content-type": "application/json", "User-Agent": "arbot"]])
        #pattern match the ETH-EUR ticker and decode information to variables
        case response do
            %{:body => body, :headers => _headers} ->
                case Poison.decode(body) do
                    {:ok, decoded_body} ->
                    	case decoded_body do
                    		%{"ask" => _ask, 
                          	  "bid" => _bid, 
                          	  "price" => price, 
                              "size" => _size, 
                              "time" => _time, 
                              "trade_id" => _trade_id, 
                              "volume" => _vol} ->
                        		:mnesia.dirty_write({Ethereum, :gdax, String.to_float(price)})
                        		:timer.sleep(3000)
                        		Gdax_ETH.priceTicker
                        	%{"message" => message} -> IO.inspect("[X] GDAX #{message}")
                    	end
                    {:error, decoded_error} -> 
                      File.write(@error_log_path, "GDAX DECODE ERROR: #{decoded_error} \n")
                        :timer.sleep(3000)
                        Gdax_ETH.priceTicker

                end
            %{message: message} -> 
              File.write(@error_log_path, "GDAX REQUEST ERROR: #{message} \n")
                :timer.sleep(3000)
                Gdax_ETH.priceTicker
            %{"message" => message} ->
              File.write(@error_log_path, "GDAX REQUEST ERROR: #{message} \n")
                :timer.sleep(3000)
                Gdax_ETH.priceTicker
        end
    end

    def get_price() do
        state = :mnesia.dirty_read({Ethereum, :gdax})
        case state do
            [] -> "empty"
            [{Ethereum, :gdax, price}] -> price
        end
    end

    def get_timestamp() do
    	tr = HTTPotion.get("https://api.gdax.com/time", [body: "", headers: ["Content-type": "application/json", "User-Agent": "arbot"]])
        case tr do
            %{:body => body, :headers => _headers} ->
                case Poison.decode(body) do
                    {:ok, %{"epoch" => timestamp, "iso" => _iso}} -> Kernel.inspect(timestamp)
                    {:error, decoded_error} -> 
                        File.write(@error_log_path, "GDAX TIMESTAMP DECODE ERROR: #{decoded_error} \n")
                        Gdax_ETH.get_timestamp
                end
            %{message: message} -> 
                File.write(@error_log_path, "GDAX TIMESTAMP REQUEST ERROR: #{message} \n")
                Gdax_ETH.get_timestamp
        end
    end
end