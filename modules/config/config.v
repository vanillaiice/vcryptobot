module config

import os { input }

pub fn new() string {
	default_decision_interval_ms := '5000'
	default_first_tx := "buy"
	default_skip_first_tx := 'false'
	default_server_url := 'https://testnet.binance.vision/api/v3'
	default_ws_server_url := 'wss://testnet.binance.vision/ws-api/v3'
	default_output_target := 'both'
	default_log_level := 'info'

	base := is_letter_only(input('Enter base currency symbol:\n-> ').to_upper())
	quote := is_letter_only(input('Enter quote currency symbol:\n-> ').to_upper())
	trading_balance := is_float(input('Enter bot trading balance:\n-> '))
	first_tx := is_tx(return_default(input('Enter type of first transaction (buy or sell), default ${default_first_tx}:\n-> '), default_first_tx))
	skip_first_tx := is_yes_no(return_default(input('Skip first transaction (y/N) ? (default ${default_skip_first_tx}):\n-> '), default_skip_first_tx))
	buy_margin := is_float(input('Enter buy margin (%):\n-> '))
	sell_margin := is_float(input('Enter sell margin (%):\n-> '))
	decision_interval_ms := is_int(return_default(input('Enter price refresh time (milliseconds), default ${default_decision_interval_ms}:\n-> '),
		default_decision_interval_ms))
	server_url := return_default(input('Enter server url (default ${default_server_url}):\n-> '),
		default_server_url)
	ws_server_url := return_default(input('Enter websocket server url (default ${default_ws_server_url}):\n-> '),
		default_ws_server_url)
	output_target := is_output_target(return_default(input('Enter log output target (console, file, both), default ${default_output_target}:\n-> '),
		default_output_target))
	log_level := is_log_level(return_default(input('Enter log level (fatal, error, warn, info, debug), default ${default_log_level}:\n-> '),
		default_log_level))

	return '{
    "base": "${base}",
    "quote": "${quote}",
    "tradingBalance": ${trading_balance},
    "firstTx": "${first_tx}",
    "skipFirstTx": "${skip_first_tx}",
    "buyMargin": ${buy_margin},
    "sellMargin": ${sell_margin},
    "decisionIntervalMs": ${decision_interval_ms},
    "serverUrl": "${server_url}",
    "wsServerUrl": "${ws_server_url}",
    "outputTarget": "${output_target}",
    "logLevel": "${log_level}"
  }'
}

fn return_default(value string, default_value string) string {
	if value == '' {
		return default_value
	} else {
		return value
	}
}

fn is_float(num string) f32 {
	if num.contains_only('0123456789.') == false {
		eprintln("${num} should only contain digits or '.', exiting")
		exit(1)
	}

	return num.f32()
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
		eprintln('Invalid value for transacation type (buy, sell)')
		exit(1)
	}
}

fn is_yes_no(str string) bool {
	str_lower := str.to_lower()
	
	if str_lower == 'yes' || str_lower == 'y' {
		return true
	} else {
		return false
	}
}

fn is_output_target(target string) string {
	if target in ['console', 'file', 'both'] {
		return target
	} else {
		eprintln('Invalid value for target (console, file, both)')
		exit(1)
	}
}

fn is_log_level(level string) string {
	if level in ['fatal', 'error', 'warn', 'info', 'debug'] {
		return level
	} else {
		eprintln('Invalid value for level (fatal, error, warn, info, debug)')
		exit(1)
	}
}
