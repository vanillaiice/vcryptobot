module binance

import binance.spot.order
import binance.spot.account
import binance.server_time

pub struct Binance {
	server_base_endpoint string
	symbol               string
	secret_key           string
	api_key              string
}

pub fn new(server_base_endpoint string, symbol string, keys map[string]string) &Binance {
	return &Binance{
		server_base_endpoint: server_base_endpoint
		symbol: symbol
		secret_key: keys['SECRET_KEY']
		api_key: keys['API_KEY']
	}
}

pub fn (b Binance) market_buy(quantity string) !(string, string) {
	return order.market_buy(b.server_base_endpoint, b.secret_key, b.api_key, b.symbol,
		quantity)!
}

pub fn (b Binance) market_sell(quantity string) !(string, string) {
	return order.market_sell(b.server_base_endpoint, b.secret_key, b.api_key, b.symbol,
		quantity)!
}

pub fn (b Binance) account_info() !(spot.account.Response, string) {
	return account.info(b.server_base_endpoint, b.secret_key, b.api_key)!
}

pub fn (b Binance) account_info_pretty() !string {
	return account.info_pretty(b.server_base_endpoint, b.secret_key, b.api_key)!
}

pub fn (b Binance) server_time() !i64 {
	return server_time.get(b.server_base_endpoint)!
}
