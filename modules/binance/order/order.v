module order

import json
import net.http
import crypto.hmac
import crypto.sha256
import binance.server_time as bt

struct Response {
	symbol       string
	order_id     int     [json: orderId]
	executed_qty string  [json: executedQty]
	status       string
	fills        []Fills
}

struct Fills {
	price            string
	qty              string
	commission       string
	commission_asset string [json: commissionAsset]
}

pub fn market_buy(server_url string, secret_key string, api_key string, symbol string, qty string) !(string, string) {
	req := make_market_order_request(qty, 'BUY', symbol)!
	sig := sign(secret_key, req)
	mut request := http.new_request(.post, '${server_url}/order', req + '&signature=${sig}')
	request.add_custom_header('X-MBX-APIKEY', api_key)!

	resp := (request.do()!).body

	resp_json := json.decode(Response, resp)!

	return resp_json.status, resp.str()
}

pub fn market_sell(server_url string, secret_key string, api_key string, symbol string, qty string) !(string, string) {
	req := make_market_order_request(qty, 'SELL', symbol)!
	sig := sign(secret_key, req)
	mut request := http.new_request(.post, '${server_url}/order', req + '&signature=${sig}')
	request.add_custom_header('X-MBX-APIKEY', api_key)!

	resp := (request.do()!).body

	resp_json := json.decode(Response, resp)!

	return resp_json.status, resp.str()
}

fn make_market_order_request(qty string, side string, symbol string) !string {
	return 'side=${side}&symbol=${symbol}&quantity=${qty}&timestamp=${bt.get()!}&type=MARKET'
}

fn sign(secret_key string, msg string) string {
	return hmac.new(secret_key.bytes(), msg.bytes(), sha256.sum256, sha256.block_size).hex()
}
