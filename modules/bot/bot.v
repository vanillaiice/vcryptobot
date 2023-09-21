module bot

import os
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

pub struct BotConfig {
	percent_change_buy            string [json: percentChangeBuy]
	percent_change_sell           string [json: percentChangeSell]
	trailing_stop_loss_margin     string [json: trailingStopLossMargin]
	stop_entry_price_margin       string [json: stopEntryPriceMargin]
	first_tx                      LastTx [json: firstTx]
	skip_first_tx                 bool   [json: skipFirstTx]
	adjust_trading_balance_loss   bool   [json: adjustTradingBalanceLoss]
	adjust_trading_balance_profit bool   [json: adjustTradingBalanceProfit]
	log_tx_to_db                  bool   [json: logTxToDb]
	stop_after_tx                 int    [json: stopAfterTx]
	trading_balance               string [json: tradingBalance]
	stop_entry_price              string [json: stopEntryPrice]
pub:
	log_price_to_db      bool   [json: logPriceToDb]
	decision_interval_ms int    [json: decisionIntervalMs]
	output_target        string [json: outputTarget]
	log_level            string [json: logLevel]
	server_base_endpoint string [json: serverBaseEndpoint]
	ws_server_base_endpoint string [json: wsServerBaseEndpoint]
	base                 string
	quote                string
}

struct State {
mut:
	last_tx            LastTx [json: lastTx]
	last_sell_price    f32    [json: lastSellprice]
	last_buy_price     f32    [json: lastBuyPrice]
	stop_after_tx      int    [json: stopAfterTx]
	stop_after_tx_flag bool   [json: stopAfterTxFlag]
	trading_balance    f32    [json: tradingBalance]
	stop_entry_price   f32    [json: stopEntryPrice]
	symbol             string
	symbol_step_size   string [json: symbolStepSize]
}

struct BotData {
mut:
	db          sqlite.DB
	logger      log.Log
	config_path string
	state       &State
}

[table: 'tx_history']
struct TxHistory {
	id         int    [primary; sql: serial]
	@type      string [nonull]
	amount     f64    [nonull]
	price      f64    [nonull]
	profit     f64    [nonull]
	cum_profit f64    [nonull]
	timestamp  i64    [nonull; sql_type: 'TIMESTAMP']
}

pub fn start(mut bot_config BotConfig, config_path string, mut client binance.Binance, price_received chan bool, mut price &f32, mut logger log.Log) {
	state_file_path := 'state/${bot_config.base.to_lower()}_${bot_config.quote.to_lower()}.json'

	if os.exists(state_file_path) == false {
		logger.debug('BOT: creating state file.')

		mut stop_after_tx_flag := false

		if bot_config.stop_after_tx != 0 {
			stop_after_tx_flag = true
		}

		symbol := bot_config.base.to_upper() + bot_config.quote.to_upper()
		step_size, _ := client.step_size([symbol]) or { logger.fatal('BOT: ${err}') }

		initial_state := State{
			last_tx: .first
			last_sell_price: 0
			last_buy_price: 0
			stop_after_tx: bot_config.stop_after_tx
			stop_after_tx_flag: stop_after_tx_flag
			trading_balance: bot_config.trading_balance.f32()
			symbol: symbol
			symbol_step_size: step_size[symbol]
		}

		os.write_file(state_file_path, json.encode_pretty(initial_state)) or {
			logger.fatal('BOT: ${err}')
		}
	}

	state_file := os.read_file(state_file_path) or { logger.fatal('BOT: ${err}') }
	mut state := json.decode(State, state_file) or { logger.fatal('BOT: ${err}') }

	mut db := sqlite.connect('db/tx_history/${bot_config.base.to_lower()}_${bot_config.quote.to_lower()}.db') or {
		logger.fatal('BOT: ${err}')
	}

	db.synchronization_mode(sqlite.SyncMode.off) or { logger.fatal('BOT: ${err}') }
	db.journal_mode(sqlite.JournalMode.memory) or { logger.fatal('BOT: ${err}') }

	_ := <-price_received

	mut bot_data := &BotData{
		db: db
		logger: logger
		config_path: config_path
		state: &state
	}

	if bot_config.log_tx_to_db == true {
		sql bot_data.db {
			create table TxHistory
		} or { logger.fatal('BOT: ${err}') }
	}

	logger.warn('BOT: trading ${state.trading_balance:.5f} ${bot_config.base}/${bot_config.quote}, BUY margin @${bot_config.percent_change_buy}%, SELL margin @${bot_config.percent_change_sell}%, current price @${*price:.5f} ${bot_config.base}/${bot_config.quote}')

	for {
		match bot_data.state.last_tx {
			.first {
				if bot_config.skip_first_tx == false {
					match bot_config.first_tx {
						.buy {
							buy(mut bot_data, *price, 0, mut client, mut bot_config)
						}
						.sell {
							sell(mut bot_data, *price, 0, mut client, mut bot_config)
						}
						else {
							logger.fatal("BOT: tx type does not match 'buy' or 'sell', exiting")
						}
					}
				} else {
					match bot_config.first_tx {
						.buy {
							bot_data.state.last_tx = LastTx.buy
						}
						.sell {
							bot_data.state.last_tx = LastTx.sell
						}
						else {
							logger.fatal("BOT: tx type does not match 'buy' or 'sell', exiting")
						}
					}
				}
			}
			.buy {
				try_sell_tx(mut bot_data, mut *price, mut client, mut bot_config)
			}
			.sell {
				try_buy_tx(mut bot_data, mut *price, mut client, mut bot_config)
			}
		}

		os.write_file(state_file_path, json.encode_pretty(bot_data.state)) or {
			logger.fatal('BOT: ${err}')
		}

		_ := <-price_received
	}
}

fn try_buy_tx(mut bot_data BotData, mut current_price &f32, mut client binance.Binance, mut bot_config BotConfig) {
	delta, res := check_price_delta_buy(bot_data.state.last_sell_price, *current_price,
		bot_config.percent_change_buy.f32())
	if res == true {
		buy(mut bot_data, *current_price, -delta, mut client, mut bot_config)
	} else {
		bot_data.logger.info('BOT: not buying, price difference @${-delta:.5f}%')
	}
}

fn try_sell_tx(mut bot_data BotData, mut current_price &f32, mut client binance.Binance, mut bot_config BotConfig) {
	delta, res := check_price_delta_sell(bot_data.state.last_buy_price, *current_price,
		bot_config.percent_change_sell.f32())
	if res == true {
		sell(mut bot_data, *current_price, delta, mut client, mut bot_config)
	} else {
		if delta <= -bot_config.trailing_stop_loss_margin.f32() && bot_config.trailing_stop_loss_margin.f32() != 0 {
			bot_data.logger.warn('BOT: triggering STOP LOSS order')
			sell(mut bot_data, *current_price, delta, mut client, mut bot_config)
		} else {
			bot_data.logger.info('BOT: not selling, price difference @${delta:.5f}%')
		}
	}
}

fn buy(mut bot_data BotData, current_price f32, price_delta f32, mut client binance.Binance, mut bot_config BotConfig) {
	if bot_data.state.stop_entry_price != 0 {
		delta := abs((bot_config.stop_entry_price.f32() - current_price) * 100 / current_price)
		if delta >= bot_config.stop_entry_price_margin.f32() {
			bot_data.logger.info('BOT: not buying, difference between price and stop entry price @${delta:.5f}')
			return
		} else {
			bot_data.logger.warn('BOT: triggering STOP ENTRY order')
			bot_data.state.stop_entry_price = 0
			bot_data.logger.debug('BOT: reset stop entry balance to 0')
		}
	}

	bot_data.logger.warn('BOT: buying @${current_price:.5f} ${bot_config.base}/${bot_config.quote}, price difference @${price_delta:.5f}%')
	quantity := binance.round_step_size(bot_data.state.trading_balance, bot_data.state.symbol_step_size.f64())

	order, order_resp, code := client.market_buy('${quantity:.5f}', bot_data.state.symbol) or {
		bot_data.logger.error('BOT: ${err}')
		return
	}

	if order.status != 'FILLED' {
		bot_data.logger.error('BOT: order request returned with status "${order.status}" & code "${code}"\n${order_resp}')
	} else {
		bot_data.logger.info('BOT: bought ${order.executed_qty} ${bot_config.base} @{order.price} ${bot_config.quote}')
		bot_data.state.last_tx = LastTx.buy
		bot_data.state.last_buy_price = order.fills[0].price.f32()

		if bot_config.log_tx_to_db == true {
			insert_tx_in_db(mut bot_data.db, mut bot_data.logger, 'buy', [quantity, bot_data.state.last_buy_price,
				0])
		}

		check_stop_after_tx(mut bot_data.state, bot_config.base, bot_config.quote, bot_config.stop_after_tx, mut
			bot_data.logger)
	}
}

fn sell(mut bot_data BotData, current_price f32, price_delta f32, mut client binance.Binance, mut bot_config BotConfig) {
	bot_data.logger.warn('BOT: selling @${current_price:.5f} ${bot_config.base}/${bot_config.quote}, price difference @${price_delta:.5f}%')

	quantity := binance.round_step_size(bot_data.state.trading_balance, bot_data.state.symbol_step_size.f64())
	trading_balance := (bot_data.state.trading_balance - quantity) + quantity

	order, order_resp, code := client.market_sell('${quantity:.5f}', bot_data.state.symbol) or {
		bot_data.logger.error('BOT: ${err}')
		return
	}

	if order.status != 'FILLED' {
		bot_data.logger.error('BOT: order request returned with status "${order.status}" & code "${code}"\n${order_resp}')
	} else {
		mut profit := f64(0)
		bot_data.state.last_sell_price = order.fills[0].price.f32()
		if bot_data.state.last_tx != .first {
			profit = (bot_data.state.last_sell_price - bot_data.state.last_buy_price) * quantity
		}
		bot_data.logger.info('BOT: sold ${order.executed_qty} ${bot_config.base} @${order.price} ${bot_config.quote}, with profit of ${profit:.5f} ${bot_config.base}')
		bot_data.state.last_tx = LastTx.sell

		if (profit < 0 && bot_config.adjust_trading_balance_loss == true)
			|| (profit > 0 && bot_config.adjust_trading_balance_profit == true) {
			bot_data.state.trading_balance = '${trading_balance +
				(profit / bot_data.state.last_sell_price):.5f}'.f32()
			bot_data.logger.warn('BOT: adjusted trading balance to ${bot_data.state.trading_balance:.5f} ${bot_config.base}')
		}

		if bot_config.log_tx_to_db == true {
			insert_tx_in_db(mut bot_data.db, mut bot_data.logger, 'sell', [quantity, bot_data.state.last_sell_price,
				profit])
		}

		check_stop_after_tx(mut bot_data.state, bot_config.base, bot_config.quote, bot_config.stop_after_tx, mut
			bot_data.logger)
	}
}
