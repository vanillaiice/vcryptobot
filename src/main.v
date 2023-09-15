module main

import os
import json
import flag
import zztkm.vdotenv
import vanillaiice.vbinance as binance
import logger
import price_websocket as price_ws
import bot
import config
import directories
import metadata

const (
	n         = 'n'
	no        = 'no'
	empty_str = ''
)

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application(metadata.name)
	fp.version(metadata.version)
	fp.description(metadata.description)
	fp.usage_example('vcryptobot [option] [argument]')
	mut config_file_path := fp.string('config', `c`, empty_str, '--config <CONFIG_FILE_NAME>.json or -c <CONFIG_FILE_NAME>.json')
	fp.finalize()!

	mut bot_config := bot.BotConfig{}
	mut config_file := ''

	if config_file_path == empty_str {
		ans := os.input('config file not provided, create one ? (y/N)\n-> ').to_lower()

		if ans == n || ans == no {
			println('not creating config file, exiting')
			exit(1)
		}

		bot_config = json.decode(bot.BotConfig, config.new())!

		if os.exists('bot_config') == false {
			os.mkdir('bot_config')!
		}

		os.write_file('bot_config/${bot_config.base.to_lower()}_${bot_config.quote.to_lower()}.json',
			json.encode_pretty(bot_config))!
	} else {
		config_file = os.read_file(config_file_path) or {
			eprintln('ERROR: error reading config file, exiting\n${err}')
			exit(1)
		}

		bot_config = json.decode(bot.BotConfig, config_file)!
	}

	if os.exists('.env') == false {
		ans := os.input('.env file not found, create one ? (y/N)\n-> ').to_lower()

		if ans == n || ans == no {
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
		if value != empty_str {
			keys_map[k] = value
		} else {
			eprintln("ERROR: value for '${k}' not found in .env file, exiting")
			exit(1)
		}
	}

	mut new_logger := logger.new(bot_config.log_level, bot_config.output_target, bot_config.base,
		bot_config.quote)!

	directories.setup(mut new_logger)

	mut b := binance.new(bot_config.server_base_endpoint, keys_map['SECRET_KEY'], keys_map['API_KEY'])
	mut last_price, mut last_price_timestamp := f32(0), i64(0)
	price_received := chan bool{}

	spawn price_ws.start(bot_config.server_base_endpoint, bot_config.decision_interval_ms,
		bot_config.base, bot_config.quote, bot_config.log_price_to_db, price_received, mut
		new_logger, mut &last_price, mut &last_price_timestamp)

	bot.start(mut &bot_config, config_file_path, mut b, price_received, mut &last_price, mut
		new_logger)
}
