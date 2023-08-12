module bot

import os
import time
import json
import log
import db.sqlite
import binance

pub enum LastTx {
	first
	sell
	buy
}

struct State {
	last_tx         LastTx [json: lastTx]
	last_sell_price f32    [json: lastSellprice]
	last_buy_price  f32    [json: lastBuyPrice]
}

pub struct BotConfig {
	trading_balance  f32    [json: tradingBalance]
	buy_margin       f32    [json: buyMargin]
	sell_margin      f32    [json: sellMargin]
	stop_loss_margin f32    [json: stopLossMargin]
	first_tx         LastTx [json: firstTx]
	skip_first_tx    bool   [json: skipFirstTx]
pub:
	decision_interval_ms int    [json: decisionIntervalMs]
	output_target        string [json: outputTarget]
	log_level            string [json: logLevel]
	ws_server_url        string [json: wsServerUrl]
	server_url           string [json: serverUrl]
	base                 string
	quote                string
}

struct BotData {
mut:
	db              sqlite.DB
	logger          log.Log
	last_buy_price  f32
	last_sell_price f32
	last_tx         LastTx
}

[table: 'tx_history']
struct TxHistory {
	id           int    [primary; sql: serial]
	tx_type      string [nonull]
	tx_amount    string [nonull]
	tx_price     string [nonull]
	profit       string [nonull]
	cumul_profit string [nonull]
	timestamp    string [nonull]
}

pub fn start(bot_config &BotConfig, mut binance_client binance.Binance, ch chan bool, mut last_price &f32, mut logger log.Log) ! {
	state_file_path := 'state/state_${bot_config.base.to_lower()}_${bot_config.quote.to_lower()}.json'

	if os.exists(state_file_path) == false {
		logger.warn('BOT: creating state file.')

		initial_state := State{
			last_tx: .first
			last_sell_price: 0
			last_buy_price: 0
		}

		os.write_file(state_file_path, json.encode_pretty(initial_state))!
	}

	state_file := os.read_file(state_file_path)!
	state := json.decode(State, state_file)!

	mut db := sqlite.connect('db/tx_history/tx_history_${bot_config.base.to_lower()}_${bot_config.quote.to_lower()}.db') or {
		logger.error('BOT: error opening db')
		exit(1)
	}

	_ := <-ch
	ch.close()

	mut last_tx, mut last_sell_price, mut last_buy_price := state.last_tx, state.last_sell_price, state.last_buy_price

	mut bot_data := &BotData{
		db: db
		logger: logger
		last_buy_price: last_buy_price
		last_sell_price: last_sell_price
		last_tx: last_tx
	}

	sql bot_data.db {
		create table TxHistory
	}!

	logger.warn('BOT: trading ${bot_config.trading_balance} ${bot_config.base}/${bot_config.quote}, BUY margin @${bot_config.buy_margin}%, SELL margin @${bot_config.sell_margin}% current price @${last_price} ${bot_config.base}/${bot_config.quote}')

	for {
		match bot_data.last_tx {
			.first {
				if bot_config.skip_first_tx == false {
					match bot_config.first_tx {
						.buy {
							buy(mut bot_data, mut last_price, mut binance_client, bot_config)!
						}
						.sell {
							sell(mut bot_data, mut last_price, mut binance_client, bot_config)!
						}
						else {}
					}
				} else {
					match bot_config.first_tx {
						.buy { bot_data.last_tx = LastTx.buy }
						.sell { bot_data.last_tx = LastTx.sell }
						else {}
					}
				}
			}
			.buy {
				try_sell_tx(mut bot_data, mut last_price, mut binance_client, bot_config)!
			}
			.sell {
				try_buy_tx(mut bot_data, mut last_price, mut binance_client, bot_config)!
			}
		}

		last_state := State{
			last_tx: bot_data.last_tx
			last_sell_price: bot_data.last_sell_price
			last_buy_price: bot_data.last_buy_price
		}

		os.write_file(state_file_path, json.encode_pretty(last_state))!

		// change
		time.sleep((bot_config.decision_interval_ms + 100) * time.millisecond)
	}
}

fn try_buy_tx(mut bot_data BotData, mut current_price &f32, mut binance_client binance.Binance, bot_config &BotConfig) ! {
	delta, res := check_price_delta(bot_data.last_sell_price, current_price, bot_config.buy_margin)
	if res == true {
		buy(mut bot_data, mut current_price, mut binance_client, bot_config)!
	} else {
		bot_data.logger.info('BOT: not buying, price difference @${delta}%')
	}
}

fn try_sell_tx(mut bot_data BotData, mut current_price &f32, mut binance_client binance.Binance, bot_config &BotConfig) ! {
	delta, res := check_price_delta(current_price, bot_data.last_buy_price, bot_config.sell_margin)
	if res == true {
		sell(mut bot_data, mut current_price, mut binance_client, bot_config)!
	} else {
		if delta <= bot_config.stop_loss_margin {
			bot_data.logger.warn('BOT: activating STOP LOSS ORDER, price difference @${delta}%')
			sell(mut bot_data, mut current_price, mut binance_client, bot_config)!
		} else {
			bot_data.logger.info('BOT: not selling, price difference @${delta}%')
		}
	}
}

fn buy(mut bot_data BotData, mut current_price &f32, mut binance_client binance.Binance, bot_config &BotConfig) ! {
	bot_data.logger.warn('BOT: buying, price @${current_price}, last sell price @${bot_data.last_sell_price}')

	order_status, order_resp := binance_client.market_buy(bot_config.trading_balance.str())!

	if order_status != 'FILLED' {
		bot_data.logger.error('BOT: order request returned with status ${order_status}\n${order_resp}')
	} else {
		last_profit := get_last_profit_from_db(mut bot_data.db)

		tx := TxHistory{
			tx_type: 'buy'
			tx_amount: (bot_config.trading_balance).str()
			tx_price: (*current_price).str()
			profit: '0'
			cumul_profit: last_profit.str()
			timestamp: time.now().unix_time().str()
		}

		sql bot_data.db {
			insert tx into TxHistory
		}!

		bot_data.last_tx = LastTx.buy
		bot_data.last_buy_price = current_price
	}
}

fn sell(mut bot_data BotData, mut current_price &f32, mut binance_client binance.Binance, bot_config &BotConfig) ! {
	bot_data.logger.warn('BOT: selling, price @${current_price}, last buy price @${bot_data.last_buy_price}')

	order_status, order_resp := binance_client.market_buy(bot_config.trading_balance.str())!

	if order_status != 'FILLED' {
		bot_data.logger.error('BOT: order request returned with status ${order_status}\n${order_resp}')
	} else {
		profit := (*current_price - bot_data.last_buy_price) * (bot_config.trading_balance)
		last_profit := get_last_profit_from_db(mut bot_data.db)

		tx := TxHistory{
			tx_type: 'sell'
			tx_amount: (bot_config.trading_balance).str()
			tx_price: (*current_price).str()
			profit: profit.str()
			cumul_profit: (last_profit + profit).str()
			timestamp: time.now().unix_time().str()
		}

		sql bot_data.db {
			insert tx into TxHistory
		}!

		bot_data.last_tx = LastTx.sell
		bot_data.last_sell_price = current_price
	}
}

fn get_last_profit_from_db(mut db sqlite.DB) f32 {
	row, code := db.exec('select * from tx_history order by id desc limit 1')

	// return error instead of 0 ?
	if row.len != 0 {
		if code == 101 {
			p := row[0].vals[5]
			return p.f32()
		} else {
			return 0
		}
	} else {
		return 0
	}
}

fn check_price_delta(a f32, b f32, c f32) (f32, bool) {
	delta := ((a - b) / a * 100)
	return delta, delta >= c
}
