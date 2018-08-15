defmodule Main do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(state) do
  	:ets.new(:prices, [:set, :public, :named_table])
  	:ets.new(:cycles, [:set, :public, :named_table])
  	spawn(Main, :get_all_prices, [])
    {:ok, state}
  end

  HTTPotion.start

  :mnesia.create_schema([])
  :mnesia.start()
  :mnesia.create_table(Ethereum, [attributes: [:exchange, :price]])
  :mnesia.create_table(Litecoin, [attributes: [:exchange, :price]])

    #gen paths
    case File.cwd do
      {:ok, path} -> 
        @path String.trim_trailing(path, "arbot")
      {:error, reason} -> IO.inspect reason
    end

    @prices_log_path @path<>"prices"

  def get_all_prices do
  	
  	time = Integer.to_string(:os.system_time(:seconds))

  	gdax_eth = Gdax_ETH.get_price
  	kraken_eth = Kraken_ETH.get_price
  	gdax_ltc = Gdax_LTC.get_price
  	kraken_ltc = Kraken_LTC.get_price
  	bitstamp_eth = Bitstamp_ETH.get_price

  	:ets.insert_new(:prices, {time, [gdax_eth, kraken_eth, gdax_ltc, kraken_ltc, bitstamp_eth]})
  	[{_t, prices}] = :ets.lookup(:prices, time)
  	
  	File.write(@prices_log_path, inspect prices)
  	File.write(@prices_log_path, "\n")
  	:timer.sleep(5000)
  	Main.get_all_prices
  end

  #entry_price, profit_level, arbitrage, volume, count, time_intervals
  def run_arbot(arb, po, v, c, ti) do
  	:ets.insert(:cycles, {"Arbot", [arb, po, v, c, ti]})
  	IO.puts "[--------------------------------STARTED ARB--------------------------------]"
  	Gdax_ETH.probe_profit(arb, po, v)
  end

  def stop_bot() do
  	IO.puts "Stopping arbot"
  end



end