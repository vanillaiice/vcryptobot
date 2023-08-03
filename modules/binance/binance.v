module binance

import binance.order
import binance.server_time

pub struct Binance {
	server_url string
	symbol     string
	secret_key string
	api_key    string
}

pub fn (b Binance) market_buy(quantity string) !(string, string) {
	return order.market_buy(b.server_url, b.secret_key, b.api_key, b.symbol, quantity)!
}

pub fn (b Binance) market_sell(quantity string) !(string, string) {
	return order.market_sell(b.server_url, b.secret_key, b.api_key, b.symbol, quantity)!
}

pub fn (b Binance) server_time() !i64 {
	return server_time.get()!
}

pub fn new(server_url string, symbol string, keys map[string]string) &Binance {
	return &Binance{
		server_url: server_url
		symbol: symbol
		secret_key: keys['SECRET_KEY']
		api_key: keys['API_KEY']
	}
}
