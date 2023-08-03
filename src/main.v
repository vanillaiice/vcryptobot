module main

import os
import json
import flag
import zztkm.vdotenv
import binance
import logger
import prices
import bot
import config
import directories

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.version('v0.1.0')
	fp.description('Simple trading bot using Binance API')
	fp.usage_example('vbot --config config.json')
	mut config_file := fp.string('config', `c`, '', '--config <CONFIG_FILE_NAME>.json or -c <CONFIG_FILE_NAME>.json')
	fp.finalize()!

	mut bot_config := bot.BotConfig{}

	if config_file == '' {
		ans := os.input('config file not provided, create one ? (y/N)\n-> ').to_lower()

		if ans == 'n' || ans == 'no' {
			println('not creating config file, exiting')
			exit(1)
		}

		bot_config = json.decode(bot.BotConfig, config.new())!

		os.write_file('bot_config_${bot_config.base.to_lower()}_${bot_config.quote.to_lower()}.json',
			json.encode_pretty(bot_config))!
	} else {
		config_file = os.read_file(config_file) or {
			eprintln('ERROR: error reading config file, exiting')
			exit(1)
		}

		bot_config = json.decode(bot.BotConfig, config_file)!
	}

	if os.exists('.env') == false {
		ans := os.input('.env file found, create one ? (y/N)\n-> ').to_lower()

		if ans == 'n' || ans == 'no' {
			println('not creating .env file, exiting')
			exit(1)
		}

		secret_key, api_key := os.input('Enter your Binance SECRET KEY:\n-> '), os.input('Enter your Binance API KEY:\n-> ')

		os.write_file('.env', 'SECRET_KEY = "${secret_key}"\nAPI_KEY = "${api_key}"')!
	}

	vdotenv.load()

	mut keys_map := map[string]string{}
	keys := ['API_KEY', 'SECRET_KEY']

	for k in keys {
		value := os.getenv(k)
		if value != '' {
			keys_map[k] = value
		} else {
			eprintln("ERROR: value for '${k}' not found in .env file, exiting")
			exit(1)
		}
	}

	mut new_logger := logger.new(bot_config.log_level, bot_config.output_target, bot_config.base,
		bot_config.quote)!

	directories.setup(mut new_logger)

	mut b := binance.new(bot_config.server_url, bot_config.base.to_upper() + bot_config.quote.to_upper(), keys_map)
	mut last_price, mut last_price_timestamp := f32(0), i64(0)
	prices_ready := chan bool{}

	spawn prices.start(bot_config.ws_server_url, bot_config.decision_interval_ms, bot_config.base, bot_config.quote, prices_ready, mut new_logger, mut &last_price, mut &last_price_timestamp)

	bot.start(&bot_config, mut b, prices_ready, mut &last_price, mut new_logger)!
}
