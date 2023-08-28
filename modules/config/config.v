module config

import os { input }

pub fn new() string {
	default_decision_interval_ms := '5000'
	default_first_tx := 'buy'
	default_skip_first_tx := 'false'
	default_server_base_endpoint := 'testnet.binance.vision'
	default_output_target := 'both'
	default_log_level := 'info'
	default_trailing_stop_loss_margin := '0'
	default_log_price_to_db := 'false'
	default_log_tx_to_db := 'yes'
	default_adjust_trading_balance_loss := 'false'
	default_adjust_trading_balance_profit := 'false'
	default_stop_entry_price := '0'
	default_stop_entry_price_margin := '0'
	default_stop_after_tx := '0'

	base := is_letter_only(is_not_empty_str(input('Enter base currency symbol:\n-> ').to_upper(),
		'Base currency'))
	quote := is_letter_only(is_not_empty_str(input('Enter quote currency symbol:\n-> ').to_upper(),
		'Quote currency'))
	trading_balance := is_float_str(is_not_empty_str(input('Enter bot trading balance:\n-> '),
		'Trading balance'))
	first_tx := is_tx(return_default(input('Enter type of first transaction (buy or sell), default ${default_first_tx}:\n-> '),
		default_first_tx))
	skip_first_tx := is_yes_no(return_default(input('Skip first transaction (y/N) ? (default ${default_skip_first_tx}):\n-> '),
		default_skip_first_tx))
	percent_change_buy := is_float_str(is_not_empty_str(input('Enter buy margin (%):\n-> '),
		'Buy margin'))
	percent_change_sell := is_float_str(is_not_empty_str(input('Enter sell margin (%):\n-> '),
		'Sell margin'))
	trailing_stop_loss_margin := is_float_str(return_default(input('Enter trailing stop loss margin (%), default ${default_trailing_stop_loss_margin}%:\n-> '),
		default_trailing_stop_loss_margin))
	stop_entry_price := is_float_str(return_default(input('Enter stop entry price, default ${default_stop_entry_price}:\n-> '),
		default_stop_entry_price))
	stop_entry_price_margin := is_float_str(return_default(input('Enter stop entry price margin (%), ${default_stop_entry_price_margin}:\n-> '),
		default_stop_entry_price_margin))
	adjust_trading_balance_loss := is_yes_no(return_default(input('Adjust trading balance after losses (y/N) ? (default ${default_adjust_trading_balance_loss}):\n-> '),
		default_adjust_trading_balance_loss))
	adjust_trading_balance_profit := is_yes_no(return_default(input('Adjust trading balance after profit (y/N) ? (default ${default_adjust_trading_balance_profit}):\n-> '),
		default_adjust_trading_balance_profit))
	stop_after_tx := is_int(return_default(input('Enter number of transactions to execute, default ${default_stop_after_tx}:\n-> '),
		default_stop_after_tx))
	decision_interval_ms := is_int(return_default(input('Enter buy/sell decision interval (milliseconds), default ${default_decision_interval_ms}:\n-> '),
		default_decision_interval_ms))
	server_base_endpoint := return_default(input('Enter server base endpoint (default ${default_server_base_endpoint}):\n-> '),
		default_server_base_endpoint)
	output_target := is_output_target(return_default(input('Enter log output target (console, file, both), default ${default_output_target}:\n-> '),
		default_output_target))
	log_level := is_log_level(return_default(input('Enter log level (fatal, error, warn, info, debug), default ${default_log_level}:\n-> '),
		default_log_level))
	log_price_to_db := is_yes_no(return_default(input('Log prices received in a database (y/N) ? (default ${default_log_price_to_db}):\n-> '),
		default_log_price_to_db))
	log_tx_to_db := is_yes_no(return_default(input('Log transaction history in a database (y/N) ? (default ${default_log_tx_to_db}):\n-> '),
		default_log_tx_to_db))

	return '{
    "base": "${base}",
    "quote": "${quote}",
    "tradingBalance": "${trading_balance}",
    "firstTx": "${first_tx}",
    "skipFirstTx": "${skip_first_tx}",
    "percentChangeBuy": "${percent_change_buy}",
    "percentChangeSell": "${percent_change_sell}",
    "trailingStopLossMargin": "${trailing_stop_loss_margin}",
    "stopEntryPrice": "${stop_entry_price}",
    "stopEntryPriceMargin": "${stop_entry_price_margin}", 
    "adjustTradingBalanceLoss": ${adjust_trading_balance_loss},
    "adjustTradingBalanceProfit": ${adjust_trading_balance_profit},
		"stopAfterTx": "${stop_after_tx}",
    "decisionIntervalMs": ${decision_interval_ms},
    "serverBaseEndpoint": "${server_base_endpoint}",
    "outputTarget": "${output_target}",
    "logLevel": "${log_level}",
    "logPriceToDb": ${log_price_to_db},
    "logTxToDb": ${log_tx_to_db}
  }'
}

fn return_default(value string, default_value string) string {
	if value == '' {
		return default_value
	} else {
		return value
	}
}

fn is_not_empty_str(str string, description string) string {
	if str == '' {
		eprintln('${description} cannot be empty, exiting')
		exit(1)
	}

	return str
}

fn is_float_str(num string) string {
	if num.contains_only('0123456789.') == false {
		eprintln("${num} should only contain digits or '.', exiting")
		exit(1)
	}

	return num
}

fn is_int(num string) int {
	if num.contains_only('0123456789') == false {
		eprintln('${num} should only contain digits, exiting')
		exit(1)
	}

	return num.int()
}

fn is_letter_only(str string) string {
	for b in str.bytes() {
		if b.is_letter() == false {
			eprintln('${str} should only contain letters, exiting')
			exit(1)
		}
	}

	return str
}

fn is_tx(tx string) string {
	if tx in ['buy', 'sell'] {
		return tx
	} else {
		eprintln('Invalid value for transacation type (buy, sell), exiting')
		exit(1)
	}
}

fn is_yes_no(str string) bool {
	if str.to_lower() in ['yes', 'y'] {
		return true
	} else {
		return false
	}
}

fn is_output_target(target string) string {
	if target in ['console', 'file', 'both'] {
		return target
	} else {
		eprintln('Invalid value for target (console, file, both), exiting')
		exit(1)
	}
}

fn is_log_level(level string) string {
	if level in ['fatal', 'error', 'warn', 'info', 'debug'] {
		return level
	} else {
		eprintln('Invalid value for level (fatal, error, warn, info, debug), exiting)')
		exit(1)
	}
}
