defmodule Poloniex do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(state) do
  	spawn(Poloniex, :priceTicker, [])
  	#:timer.sleep(5000)
  	#spawn(Poloniex, :probe_profit, [466])
    {:ok, state}
  end

  HTTPotion.start

  :mnesia.create_schema([])
  :mnesia.start()
  :mnesia.create_table(Ethereum, [attributes: [:exchange, :price]])

  	def watch_new_deposits() do
  		
  	end


  	def withdrawal(total) do
  		IO.inspect("Preparing withdrawal of #{total} USDT to Bittrex")
   		api_key = "Z6334NU4-0KQJL1FB-1PCK4T1I-5DLFMLFC"
		sec = "74e02e881a538f648cbaa5869f56d8f9b6dcb9d3f14a002a9b74bdb50b859edfce874b81b284475d6b93a4da085edc74e97a912c8348bcda45d0e3c5eaac4be7"
		nonce = Integer.to_string(:os.system_time(:seconds))
		command = "withdraw"
		address = "1JhRjNrhoLw5exhK9h3PkzbiD324NBhKzv"
		postdata = "nonce=#{nonce}&command=#{command}&currency=USDT&amount=#{total}&address=#{address}"
		signature = Base.encode16 :crypto.hmac(:sha512, sec, postdata)
		request = HTTPotion.post("https://poloniex.com/tradingApi",
      		[body: postdata,
       		headers: [
      		"Content-type": "application/x-www-form-urlencoded", 
      		"Sign": signature,
      		"Key": api_key
         	]  
      	]) 

      	case request do
      		%{body: body, headers: _headers} ->
      			case Poison.decode(body) do
      				{:ok, withdraw_status} ->
      					case withdraw_status do
      						%{"error" => withdraw_error} ->
      							IO.inspect(withdraw_error)
      						%{"response" => withdraw_response} ->
      							IO.inspect(withdraw_response)
      					end
      				{:error, decoded_error} -> 
            			IO.inspect decoded_error
            	end
            %{message: error} ->
           		IO.inspect("#{error} on withdrawal")
      	end
  	end


  	def watch_order_completed(orderNumber) do
  		api_key = "Z6334NU4-0KQJL1FB-1PCK4T1I-5DLFMLFC"
		sec = "74e02e881a538f648cbaa5869f56d8f9b6dcb9d3f14a002a9b74bdb50b859edfce874b81b284475d6b93a4da085edc74e97a912c8348bcda45d0e3c5eaac4be7"
		nonce = Integer.to_string(:os.system_time(:seconds))
		command = "returnOrderTrades"
		postdata = "nonce=#{nonce}&command=#{command}&orderNumber=#{orderNumber}"
		signature = Base.encode16 :crypto.hmac(:sha512, sec, postdata)
		request = HTTPotion.post("https://poloniex.com/tradingApi",
      		[body: postdata,
       		headers: [
      		"Content-type": "application/x-www-form-urlencoded", 
      		"Sign": signature,
      		"Key": api_key
         	]  
      	])

      	case request do
      		%{body: body, headers: _headers} -> 
      			case Poison.decode(body) do
      				{:ok, order_status} ->
      					case order_status do
      						%{"error" => order_error} ->
      							IO.inspect("#{order_error} ORDER: #{orderNumber}")
      							:timer.sleep(1000)
      							Poloniex.watch_order_completed(orderNumber)
      						[%{"amount" => amount,
      						   "currencyPair" => _pair,
      						   "date" => _date,
      						   "fee" => _fee,
      						   "globalTradeID" => _gtid,
      						   "rate" => _rate, 
      						   "total" => total, 
      						   "tradeID" => _tid, 
      						   "type" => _type}] ->
      						   	IO.inspect("#{orderNumber} filled")
      						   	spawn(Bittrex, :buy_order, [amount])
      						   	Poloniex.withdrawal(total)
      					end
      				{:error, decoded_error} -> 
            			IO.inspect decoded_error
            			Poloniex.watch_order_completed(orderNumber)
            	end
           	%{message: error} ->
           		IO.inspect("#{error} on order: #{orderNumber}")
           		Poloniex.watch_order_completed(orderNumber)
      	end
  	end


  	def sell_order(polo_price) do
  		api_key = "Z6334NU4-0KQJL1FB-1PCK4T1I-5DLFMLFC"
		sec = "74e02e881a538f648cbaa5869f56d8f9b6dcb9d3f14a002a9b74bdb50b859edfce874b81b284475d6b93a4da085edc74e97a912c8348bcda45d0e3c5eaac4be7"
		nonce = Integer.to_string(:os.system_time(:seconds))
		command = "sell"
		amount = Float.to_string(0.002)
		postdata = "nonce=#{nonce}&command=#{command}&currencyPair=USDT_ETH&rate=#{polo_price}&amount=#{amount}"
		signature = Base.encode16 :crypto.hmac(:sha512, sec, postdata)
		request = HTTPotion.post("https://poloniex.com/tradingApi",
      		[body: postdata,
       		headers: [
      		"Content-type": "application/x-www-form-urlencoded", 
      		"Sign": signature,
      		"Key": api_key
         	]  
      	])

      	case request do
      		%{body: body, headers: _headers} -> 
      			case Poison.decode(body) do
      				{:ok, order_reponse} ->
      					IO.inspect order_reponse
      					case order_reponse do
      						%{"orderNumber" => orderNumber,
      						 "resultingTrades" => _trade} ->
      						 	IO.inspect "ORDER PLACED : #{orderNumber}"
      						 	Poloniex.watch_order_completed(orderNumber)
      						%{"error" => error} ->
                				IO.inspect error
      					end
      				{:error, decoded_error} -> 
            			IO.inspect decoded_error
      			end
      		%{message: error} ->
      			IO.inspect(error)
      	end
  	end


	#starts here
  	def probe_profit(entry) do
  		polo_price = Poloniex.read_price_poloniex
  		bitt_price = Bittrex.read_price_bittrex
  		case polo_price do
  			polo_price when is_float(polo_price) ->
  				case polo_price do
  					polo_price when polo_price - entry >= 3.0 -> 
  						IO.inspect "Profit above"
  						cond do
  							polo_price - bitt_price >= 0.2 ->
  								IO.inspect "Arbitrage above"
  								IO.inspect "ENGAGING SWITCH"
  								Poloniex.sell_order(polo_price)
  							polo_price - bitt_price <= 0.2 ->
  								IO.inspect "Arbitrage below"
  								:timer.sleep(3000)
  								Poloniex.probe_profit(entry)
  						end
  					polo_price when polo_price - entry <= 3.0 ->
  						IO.inspect "Profit below"
  						:timer.sleep(3000)
  						Poloniex.probe_profit(entry)
  				end
  			polo_price when is_bitstring(polo_price) -> 
        		IO.puts "not price value"
        		:timer.sleep(10000)
        		Poloniex.probe_profit(entry)
  		end
  	end


    def priceTicker() do
      price_uri = "https://poloniex.com/public?command=returnTicker"
      response = HTTPotion.get(price_uri, [body: "", headers: ["Content-type": "application/json"]])
      case response do
	    %{body: body, headers: _headers} -> 
		    {:ok, data} = Poison.decode(body)
		     %{"baseVolume" => _bv,
		       "high24hr" => _h24r,
  		       "highestBid" => _hb,
  		       "id" => _id,
  		       "isFrozen" => _if,
  		       "last" => price,
  		       "low24hr" => _low,
  		       "lowestAsk" => _la,
  		       "percentChange" => _pc,
  		       "quoteVolume" => _qv} = data["USDT_ETH"]
  		    :mnesia.dirty_write({Ethereum, :poloniex, String.to_float(price)})
  		    :timer.sleep(2000)
  		    Poloniex.priceTicker
  		%{message: error} ->
  			IO.inspect(error)
  			:timer.sleep(4000)
  		    Poloniex.priceTicker
      end	
    end

    def read_price_poloniex() do
    	state = :mnesia.dirty_read({Ethereum, :poloniex})
    	case state do
    		[] -> "empty"
    		[{Ethereum, :poloniex, price}] -> price
    	end
    end

    def start_probe do
    	spawn(Poloniex, :probe_profit, [420])
    end

end

