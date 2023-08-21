module prices

import net.websocket
import time
import json
import db.sqlite
import log

[table: 'prices']
struct Prices {
	id        int    [primary; sql: serial]
	price     string [nonull]
	timestamp string [nonull]
}

struct Price {
	id     string
	status int
	result struct {
		symbol string
		price  string
	}
}

const (
	slow_down = 429
	ip_banned = 418
	ok        = 200
)

pub fn start(server_url string, refresh_time_ms int, base string, quote string, log_price_to_db bool, price_received chan bool, mut logger log.Log, mut last_price &f32, mut last_price_timestamp &i64) ! {
	mut db := sqlite.connect('db/prices/${base.to_lower()}_${quote.to_lower()}.db') or {
		logger.fatal('PRICES: ${err}')
	}

	mut ws := websocket.new_client('wss://${server_url}/ws-api/v3', unsafe {
		websocket.ClientOpt{
			logger: logger
		}
	}) or { logger.fatal('PRICES: ${err}') }

	defer {
		db.close() or { logger.fatal('PRICES: ${err}') }

		ws.close(0, 'PRICES: closing websocket connection') or { logger.fatal('PRICES: ${err}') }
	}

	db.synchronization_mode(sqlite.SyncMode.off) or { logger.fatal('PRICES: ${err}') }
	db.journal_mode(sqlite.JournalMode.memory) or { logger.fatal('PRICES: ${err}') }

	sql db {
		create table Prices
	} or { logger.fatal('PRICES: ${err}') }

	setup_client(mut ws, mut last_price, mut last_price_timestamp, mut logger, mut &db,
		price_received, log_price_to_db) or { logger.fatal('PRICES: ${err}') }

	spawn fetch_price(mut ws, refresh_time_ms, base + quote)

	ws.listen() or { logger.fatal('PRICES: ${err}') }
}

fn setup_client(mut ws websocket.Client, mut price &f32, mut price_timestamp &i64, mut logger log.Log, mut db sqlite.DB, price_received chan bool, log_price_to_db bool) ! {
	ws.on_open(fn [mut logger] (mut ws websocket.Client) ! {
		logger.debug('PRICES: ws connection open')
	})
	ws.on_error(fn [mut logger] (mut ws websocket.Client, err string) ! {
		logger.error('PRICES: ${err}')
	})
	ws.on_close(fn [mut logger] (mut ws websocket.Client, code int, reason string) ! {
		logger.error('PRICES: socket closed:\ncode: ${code}\nreason: ${reason}')
	})
	ws.on_message(fn [mut price, mut price_timestamp, mut logger, mut db, price_received, log_price_to_db] (mut ws websocket.Client, msg &websocket.Message) ! {
		if msg.payload.len > 0 {
			handle_message(msg.payload.bytestr(), mut price, mut price_timestamp, mut
				logger, mut db, price_received, log_price_to_db) or {
				logger.fatal('PRICES: ${err}')
			}
		}
	})
	ws.connect() or { logger.fatal('PRICES: ${err}') }
}

fn fetch_price(mut ws websocket.Client, refresh_time_ms int, symbol string) ! {
	ws.write_string('{ "id": "0", "method": "ticker.price", "params": { "symbol": "${symbol}" } }')!
	time.sleep(refresh_time_ms * time.millisecond)
	fetch_price(mut ws, refresh_time_ms, symbol)!
}

fn handle_message(msg string, mut price &f32, mut price_timestamp &i64, mut logger log.Log, mut db sqlite.DB, price_received chan bool, log_price_to_db bool) ! {
	msg_json := json.decode(Price, msg)!

	match msg_json.status {
		prices.slow_down {
			logger.warn('PRICES: received status code 429 (slow down API calls), exiting')
			logger.debug(msg_json.str())
			exit(1)
		}
		prices.ip_banned {
			logger.warn('PRICES: received status code 418 (IP address banned), exiting')
			logger.debug(msg_json.str())
			exit(1)
		}
		prices.ok {
			p := msg_json.result.price.f32()
			if p != 0 {
				price = p
				price_timestamp = time.now().unix_time()

				price_received <- true
				logger.debug('PRICES: received @${*price:.5f}')

				if log_price_to_db == true {
					row := Prices{
						price: '${p:.5f}'
						timestamp: (*price_timestamp).str()
					}

					sql db {
						insert row into Prices
					} or {
						logger.error('PRICES: ${err}')
						return
					}

					logger.debug('PRICES: inserted price and timestamp (${row.price}; ${row.timestamp.str()}) into db')
				}
			} else {
				logger.error('PRICES: invalid price (${p})')
			}
		}
		else {
			logger.error('PRICES: ${msg_json}')
		}
	}
}

/*
fn get_latest_price_from_db(mut db sqlite.DB) (f32, i64) {
	row := db.exec('select * from prices order by id desc limit 1') or { return 0, 0 }

	if row.len > 0 {
		p, t := row[0].vals[1].f32(), row[0].vals[2].i64()
		return p, t
	} else {
		return 0, 0
	}
}
*/
