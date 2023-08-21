module bot

import os
import time
import json
import log
import db.sqlite
import math { abs }
import vanillaiice.vbinance as binance

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
	percent_change_buy                    f32    [json: percentChangeBuy]
	percent_change_sell                   f32    [json: percentChangeSell]
	trailing_stop_loss_margin     f32    [json: trailingStopLossMargin]
	stop_entry_price_margin  f32    [json: stopEntryPriceMargin]
	first_tx                      LastTx [json: firstTx]
	skip_first_tx                 bool   [json: skipFirstTx]
	adjust_trading_balance_loss   bool   [json: adjustTradingBalanceLoss]
	adjust_trading_balance_profit bool   [json: adjustTradingBalanceProfit]
	log_tx_to_db                  bool   [json: logTxToDb]
pub:
	log_price_to_db      bool   [json: logPriceToDb]
	decision_interval_ms int    [json: decisionIntervalMs]
	output_target        string [json: outputTarget]
	log_level            string [json: logLevel]
	server_base_endpoint string [json: serverBaseEndpoint]
	base                 string
	quote                string
mut:
	trading_balance  f32 [json: tradingBalance]
	stop_entry_price f32 [json: stopEntryPrice]
}

struct BotData {
mut:
	db              sqlite.DB
	logger          log.Log
	last_buy_price  f32
	last_sell_price f32
	last_tx         LastTx
	config_path     string
}

[table: 'tx_history']
struct TxHistory {
	id         int    [primary; sql: serial]
	@type      string [nonull]
	amount     string [nonull]
	price      string [nonull]
	profit     string [nonull]
	cum_profit string [nonull]
	timestamp  i64    [nonull]
}

pub fn start(mut bot_config BotConfig, config_path string, mut binance_client binance.Binance, price_received chan bool, mut last_price &f32, mut logger log.Log) {
	state_file_path := 'state/${bot_config.base.to_lower()}_${bot_config.quote.to_lower()}.json'

	if os.exists(state_file_path) == false {
		logger.debug('BOT: creating state file.')

		initial_state := State{
			last_tx: .first
			last_sell_price: 0
			last_buy_price: 0
		}

		os.write_file(state_file_path, json.encode_pretty(initial_state)) or {
			logger.fatal('BOT: ${err}')
		}
	}

	state_file := os.read_file(state_file_path) or { logger.fatal('BOT: ${err}') }
	state := json.decode(State, state_file) or { logger.fatal('BOT: ${err}') }

	mut db := sqlite.connect('db/tx_history/${bot_config.base.to_lower()}_${bot_config.quote.to_lower()}.db') or {
		logger.fatal('BOT: ${err}')
	}

	db.synchronization_mode(sqlite.SyncMode.off) or { logger.fatal('BOT: ${err}') }
	db.journal_mode(sqlite.JournalMode.memory) or { logger.fatal('BOT: ${err}') }

	_ := <-price_received

	mut last_tx, mut last_sell_price, mut last_buy_price := state.last_tx, state.last_sell_price, state.last_buy_price

	mut bot_data := &BotData{
		db: db
		logger: logger
		last_buy_price: last_buy_price
		last_sell_price: last_sell_price
		last_tx: last_tx
		config_path: config_path
	}

	if bot_config.log_tx_to_db == true {
		sql bot_data.db {
			create table TxHistory
		} or { logger.fatal('BOT: ${err}') }
	}

	logger.warn('BOT: trading ${bot_config.trading_balance:.5f} ${bot_config.base}/${bot_config.quote}, BUY margin @${bot_config.percent_change_buy:.5f}%, SELL margin @${bot_config.percent_change_sell:.5f}%, current price @${*last_price:.5f} ${bot_config.base}/${bot_config.quote}')

	for {
		match bot_data.last_tx {
			.first {
				if bot_config.skip_first_tx == false {
					match bot_config.first_tx {
						.buy { buy(mut bot_data, *last_price, 0, mut binance_client, mut
								bot_config) }
						.sell { sell(mut bot_data, *last_price, 0, mut binance_client, mut
								bot_config) }
						else { 
							logger.error("BOT: tx type does not match 'buy' or 'sell', exiting")
							exit(1)
						}
					}
				} else {
					match bot_config.first_tx {
						.buy { bot_data.last_tx = LastTx.buy }
						.sell { bot_data.last_tx = LastTx.sell }
						else {
							logger.error("BOT: tx type does not match 'buy' or 'sell', exiting")
							exit(1)
						}
					}
				}
			}
			.buy {
				try_sell_tx(mut bot_data, mut *last_price, mut binance_client, mut bot_config)
			}
			.sell {
				try_buy_tx(mut bot_data, mut *last_price, mut binance_client, mut bot_config)
			}
		}

		last_state := State{
			last_tx: bot_data.last_tx
			last_sell_price: bot_data.last_sell_price
			last_buy_price: bot_data.last_buy_price
		}

		os.write_file(state_file_path, json.encode_pretty(last_state)) or {
			logger.fatal('BOT: ${err}')
		}

		_ := <-price_received
	}
}

fn try_buy_tx(mut bot_data BotData, mut current_price &f32, mut binance_client binance.Binance, mut bot_config BotConfig) {
	delta, res := check_price_delta_buy(bot_data.last_sell_price, current_price, bot_config.percent_change_buy)
	if res == true {
		buy(mut bot_data, *current_price, -delta, mut binance_client, mut bot_config)
	} else {
		bot_data.logger.info('BOT: not buying, price difference @${-delta:.5f}%')
	}
}

fn try_sell_tx(mut bot_data BotData, mut current_price &f32, mut binance_client binance.Binance, mut bot_config BotConfig) {
	delta, res := check_price_delta_sell(bot_data.last_buy_price, current_price, bot_config.percent_change_sell)
	if res == true {
		sell(mut bot_data, *current_price, delta, mut binance_client, mut bot_config)
	} else {
		if delta <= -bot_config.trailing_stop_loss_margin {
			bot_data.logger.warn('BOT: triggering STOP LOSS order')
			sell(mut bot_data, *current_price, delta, mut binance_client, mut bot_config)
		} else {
			bot_data.logger.info('BOT: not selling, price difference @${delta:.5f}%')
		}
	}
}

fn buy(mut bot_data BotData, current_price f32, price_delta f32, mut binance_client binance.Binance, mut bot_config BotConfig) {
	if bot_config.stop_entry_price != 0 {
		delta := abs((bot_config.stop_entry_price - current_price) * 100 / current_price)
		if delta >= bot_config.stop_entry_price_margin {
			bot_data.logger.info('BOT: not buying, difference between price and stop entry price @${delta:.5f}')
			return
		} else {
			bot_data.logger.warn('BOT: triggering STOP ENTRY order')
			bot_config.stop_entry_price = 0
			bot_data.logger.debug('BOT: reset stop entry balance to 0')
			os.write_file(bot_data.config_path, json.encode_pretty(bot_config)) or {
				bot_data.logger.fatal('BOT: ${err}')
			}
		}
	}

	bot_data.logger.warn('BOT: buying @${current_price:.5f}, price difference @${price_delta:.5f}%')

	order_status, order_resp, code := binance_client.market_buy('${bot_config.trading_balance:.5f}')

	if order_status != 'FILLED' {
		bot_data.logger.error('BOT: order request returned with status "${order_status}" & code "${code}"\n${order_resp}')
	} else {
		bot_data.last_tx = LastTx.buy
		bot_data.last_buy_price = current_price

		if bot_config.log_tx_to_db == true {
			last_profit := get_last_profit_from_db(mut bot_data.db)

			tx := TxHistory{
				@type: 'buy'
				amount: '${bot_config.trading_balance:.5f}'
				price: '${current_price:.5f}'
				profit: '0'
				cum_profit: '${last_profit:.5f}'
				timestamp: time.now().unix_time()
			}

			sql bot_data.db {
				insert tx into TxHistory
			} or { bot_data.logger.fatal('${err}') }
		}
	}
}

fn sell(mut bot_data BotData, current_price f32, price_delta f32, mut binance_client binance.Binance, mut bot_config BotConfig) {
	bot_data.logger.warn('BOT: selling @${current_price:.5f}, price difference @${price_delta:.5f}%')

	order_status, order_resp, code := binance_client.market_buy('${bot_config.trading_balance:.5f}')

	if order_status != 'FILLED' {
		bot_data.logger.error('BOT: order request returned with status "${order_status}" & code "${code}"\n${order_resp}')
	} else {
		price := current_price
		profit := (price - bot_data.last_buy_price) * (bot_config.trading_balance)

		bot_data.last_tx = LastTx.sell
		bot_data.last_sell_price = current_price
		tx_trading_balance := bot_config.trading_balance

		if (profit < 0 && bot_config.adjust_trading_balance_loss == true)
			|| (profit > 0 && bot_config.adjust_trading_balance_profit == true) {
			bot_config.trading_balance = '${bot_config.trading_balance + (profit / price):.5f}'.f32()
			bot_data.logger.warn('BOT: adjusted trading balance to ${bot_config.trading_balance:.5f} ${bot_config.base}')
			os.write_file(bot_data.config_path, json.encode_pretty(bot_config)) or {
				bot_data.logger.fatal('BOT: ${err}')
			}
		}

		if bot_config.log_tx_to_db == true {
			last_profit := get_last_profit_from_db(mut bot_data.db)

			tx := TxHistory{
				@type: 'sell'
				amount: '${tx_trading_balance:.5f}'
				price: '${current_price:.5f}'
				profit: '${profit:.5f}'
				cum_profit: '${last_profit + profit:.5f}'
				timestamp: time.now().unix_time()
			}

			sql bot_data.db {
				insert tx into TxHistory
			} or { bot_data.logger.fatal('BOT: ${err}') }
		}
	}
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
