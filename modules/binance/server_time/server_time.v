module server_time

import net.http
import json

struct Response {
	server_time i64 [json: serverTime]
}

pub fn get() !i64 {
	resp := http.get('https://testnet.binance.vision/api/v3/time')!
	return (json.decode(Response, resp.body)!).server_time
}
