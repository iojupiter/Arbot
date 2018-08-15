# Arbot
Arbitrage trader for Ethereum


What is it?
A crypto trader that exploits Ether price arbitrage between GDAX and Kraken.
However this trader was more profitable at a time in the past.


How does it work?
Written with Elixir, a background process will keep synchronised with price tickers from respective gdax and kraken APIs.
Prices are placed in a distributed store and also written to a file on disk to be able to visualise it in terminal with UNIX cmd: 'tail -f /prices’.
Arbot equates arbitrage level and other parameters set by user and engages a sell on gdax ether and then a buy on kraken ether with euros.


How to start the app?
—Place API keys respectively Gdax in /other_g and /kraken other_k
—Place other Gdax secrets in function sell_order as commented in source
—Place other kraken secrets In function buy_order_kraken as commented in source

Navigate to elixir app root project /arbot/arbot and start mix project:
iex -S mix

Then start arbot with:
'Arbot.run_arbot(a, b, c, d, e)' where
a = entry price
b = profit level
c = volume per trade
d = number of cycles
e = time intervals 

You can tail -f the file /filled_orders in the main Arbot folder to view filled orders.
Same for /prices and same for /error_log

Typical problems

Mnesia distributed store holding prices may not recompile after a previous Arbot stop.
— open any elixir source in /lib and save the file so elixir can recompile project.
