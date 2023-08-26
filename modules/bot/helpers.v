module bot

import db.sqlite
import os
import json
import log
import time

fn insert_tx_in_db(mut db sqlite.DB, mut logger log.Log, fields []string) {
	last_profit := get_last_profit_from_db(mut db)
	tx := TxHistory {
		@type: fields[0]
		amount: fields[1]
		price: fields[2]
		profit: fields[3]
		cum_profit: '${last_profit + fields[3].f32():.5f}'
		timestamp: time.now().unix_time()
	}

	sql db {
		insert tx into TxHistory
	} or { logger.fatal('${err}') }
}

fn get_last_profit_from_db(mut db sqlite.DB) f32 {
	row := db.exec_one('select * from tx_history order by id desc limit 1') or { return 0 }
	return row.vals[5].f32()
}

fn check_price_delta_sell(a f32, b f32, c f32) (f32, bool) {
	delta := (b - a) * 100 / a
	return delta, delta >= c
}

fn check_price_delta_buy(a f32, b f32, c f32) (f32, bool) {
	delta := (a - b) * 100 / a
	return delta, delta >= c
}

fn check_stop_after_tx(mut state State, base string, quote string, stop_after_tx int, mut logger log.Log) {
	if state.stop_after_tx_flag == true && state.stop_after_tx != 0 {
		state.stop_after_tx--
		if state.stop_after_tx == 0 {
			logger.warn('BOT: transaction count @${stop_after_tx} reached, exiting')
			os.write_file('state/${base.to_lower()}_${quote.to_lower()}.json', json.encode_pretty(state)) or {
				logger.fatal('BOT: ${err}')
			}
			exit(0)
		}
	}
}
