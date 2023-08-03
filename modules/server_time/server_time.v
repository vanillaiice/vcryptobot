module server_time

import net.websocket
import time
import json
import log

struct Time {
	id     string
	status int
	result Result
}

struct Result {
	server_time i64 [json: serverTime]
}

// start starts the websocket connection
pub fn start(server_url string, timestamp_refresh_ms int, ch chan int, mut logger log.Log, mut server_timestamp &i64) ! {
	mut ws := websocket.new_client(server_url, unsafe { websocket.ClientOpt{ logger: logger } })!

	defer {
		ws.close(0, 'SERVER TIME: closing websocket connection') or {
			logger.error('SERVER TIME: error closing websocket connection')
			exit(1)
		}
	}

	setup_client(mut ws, mut server_timestamp, mut logger, ch)!
	spawn fetch_timestamp(mut ws, timestamp_refresh_ms)

	ws.listen()!
}

fn setup_client(mut ws websocket.Client, mut server_timestamp &i64, mut logger log.Log, ch chan int) ! {
	ws.on_open(fn (mut ws websocket.Client) ! {})
	ws.on_error(fn [mut logger] (mut ws websocket.Client, err string) ! {
		logger.error('SERVER TIME: ${err}')
	})
	ws.on_close(fn [mut logger] (mut ws websocket.Client, code int, reason string) ! {
		logger.error('SERVER TIME: socket closed:\ncode: ${code}\nreason: ${reason}')
	})
	ws.on_message(fn [mut server_timestamp, mut logger, ch] (mut ws websocket.Client, msg &websocket.Message) ! {
		if msg.payload.len > 0 {
			handle_message(msg.payload.bytestr(), ch, mut server_timestamp, mut logger)!
		}
	})
	ws.connect() or {
		logger.error('SERVER TIME: unable to connect to websocket')
		exit(1)
	}
}

fn fetch_timestamp(mut ws websocket.Client, timestamp_refresh_ms int) ! {
	ws.write_string('{"id": "420", "method": "time"}')!
	time.sleep(timestamp_refresh_ms * time.millisecond)
	fetch_timestamp(mut ws, timestamp_refresh_ms)!
}

fn handle_message(msg string, ch chan int, mut server_timestamp &i64, mut logger log.Log) ! {
	mut msg_json := json.decode(Time, msg)!

	match msg_json.status {
		429 {
			logger.warn('SERVER TIME: received status code 429 (slow down API calls), exiting')
			logger.info(msg_json.str())
			exit(1)
		}
		418 {
			logger.warn('SERVER TIME: received status code 418 (IP address banned), exiting')
			logger.info(msg_json.str())
			exit(1)
		}
		200 {
			server_timestamp = msg_json.result.server_time
			logger.debug('SERVER TIME: latest server timestamp ${msg_json.result.server_time}')

			if ch.closed == false {
				logger.info('SERVER TIME: READY')
				ch <- 0
			}
		}
		else {
			logger.error('SERVER TIME: ${msg_json.status}')
		}
	}
}
