module order

import json
import net.http
import binance.sign
import binance.server_time as bt

struct Response {
	symbol       string
	order_id     int     [json: orderId]
	executed_qty string  [json: executedQty]
	status       string
	fills        []struct {
			price            string
			qty              string
			commission       string
			commission_asset string [json: commissionAsset]
	}
}

pub fn market_buy(server_base_endpoint string, secret_key string, api_key string, symbol string, qty string) !(string, string) {
	req := make_market_order_request(qty, 'BUY', symbol, '${bt.get(server_base_endpoint)!}')
	sig := sign.sign(secret_key, req)
	mut request := http.new_request(.post, 'https://${server_base_endpoint}/api/v3/order',
		'${req}&signature=${sig}')
	request.add_custom_header('X-MBX-APIKEY', api_key)!

	resp_body := (request.do()!).body

	resp_json := json.decode(Response, resp_body)!

	return resp_json.status, resp_body
}

pub fn market_sell(server_base_endpoint string, secret_key string, api_key string, symbol string, qty string) !(string, string) {
	req := make_market_order_request(qty, 'SELL', symbol, '${bt.get(server_base_endpoint)!}')
	sig := sign.sign(secret_key, req)
	mut request := http.new_request(.post, 'https://${server_base_endpoint}/api/v3/order',
		'${req}&signature=${sig}')
	request.add_custom_header('X-MBX-APIKEY', api_key)!

	resp_body := (request.do()!).body

	resp_json := json.decode(Response, resp_body)!

	return resp_json.status, resp_body
}

fn make_market_order_request(qty string, side string, symbol string, timestamp string) string {
	return 'side=${side}&symbol=${symbol}&quantity=${qty}&timestamp=${timestamp}&type=MARKET'
}
