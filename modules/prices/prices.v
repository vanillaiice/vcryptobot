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
	result Result
}

struct Result {
	symbol string
	price  string
}

pub fn start(server_url string, refresh_time_ms int, base string, quote string, ch chan bool, mut logger log.Log, mut last_price &f32, mut last_price_timestamp &i64) ! {
	mut db := sqlite.connect('db/prices/prices_${base.to_lower()}_${quote.to_lower()}.db') or {
		logger.error('PRICES: error opening db')
		exit(1)
	}

	mut ws := websocket.new_client(server_url, unsafe { websocket.ClientOpt{ logger: logger } })!

	defer {
		db.close() or {
			logger.error('PRICES: error closing db')
			exit(1)
		}

		ws.close(0, 'PRICES: closing websocket connection') or {
			logger.error('PRICES: error closing websocket connection')
			exit(1)
		}
	}

	db.synchronization_mode(sqlite.SyncMode.off)
	db.journal_mode(sqlite.JournalMode.memory)

	sql db {
		create table Prices
	}!

	setup_client(mut ws, mut last_price, mut logger, mut &db)!

	spawn fetch_price(mut ws, refresh_time_ms, base + quote)
	spawn update_data(mut logger, mut last_price, mut last_price_timestamp, refresh_time_ms + 125,
		ch, base, quote)

	ws.listen()!
}

fn setup_client(mut ws websocket.Client, mut price &f32, mut logger log.Log, mut db sqlite.DB) ! {
	ws.on_open(fn (mut ws websocket.Client) ! {})
	ws.on_error(fn [mut logger] (mut ws websocket.Client, err string) ! {
		logger.error('PRICES: ${err}')
	})
	ws.on_close(fn [mut logger] (mut ws websocket.Client, code int, reason string) ! {
		logger.error('PRICES: socket closed:\ncode: ${code}\nreason: ${reason}')
	})
	ws.on_message(fn [mut price, mut logger, mut db] (mut ws websocket.Client, msg &websocket.Message) ! {
		if msg.payload.len > 0 {
			handle_message(msg.payload.bytestr(), mut price, mut logger, mut db)!
		}
	})
	ws.connect() or {
		logger.error('PRICES: unable to connect to websocket')
		exit(1)
	}
}

fn fetch_price(mut ws websocket.Client, refresh_time_ms int, symbol string) ! {
	ws.write_string('{ "id": "0", "method": "ticker.price", "params": { "symbol": "${symbol}" } }')!
	time.sleep(refresh_time_ms * time.millisecond)
	fetch_price(mut ws, refresh_time_ms, symbol)!
}

fn handle_message(msg string, mut last_price &f32, mut logger log.Log, mut db sqlite.DB) ! {
	msg_json := json.decode(Price, msg)!

	match msg_json.status {
		429 {
			logger.warn('PRICES: received status code 429 (slow down API calls), exiting')
			logger.debug(msg_json.str())
			exit(1)
		}
		418 {
			logger.warn('PRICES: received status code 418 (IP address banned), exiting')
			logger.debug(msg_json.str())
			exit(1)
		}
		200 {
			last_price = msg_json.result.price.f32()

			p := Prices{
				price: msg_json.result.price
				timestamp: time.now().unix_time().str()
			}

			sql db {
				insert p into Prices
			}!

			logger.debug('PRICES: inserted price and timestamp (${p.price}; ${p.timestamp}) into db')
		}
		else {
			logger.error('PRICES: ${msg_json}')
		}
	}
}

fn update_data(mut logger log.Log, mut last_price &f32, mut last_price_timestamp &i64, refresh_time_ms int, ch chan bool, base string, quote string) {
	mut db := sqlite.connect('db/prices/prices_${base.to_lower()}_${quote.to_lower()}.db') or {
		logger.error('PRICES: error opening db')
		exit(1)
	}

	for {
		mut p, mut t := get_latest_price_from_db(mut db)

		if p != 0 && t != 0 {
			last_price = p
			last_price_timestamp = t
			if ch.closed == false {
				logger.info('PRICES: READY')
				ch <- true
			}
		} else {
			logger.error('PRICES: invalid price from db (${p})')
		}

		time.sleep(refresh_time_ms * time.millisecond)
	}
}

fn get_latest_price_from_db(mut db sqlite.DB) (f32, i64) {
	row, code := db.exec('select * from prices order by id desc limit 1')

	if code == 101 && row.len > 0 {
		p, t := row[0].vals[1].f32(), row[0].vals[2].i64()
		return p, t
	} else {
		return 0, 0
	}
}
