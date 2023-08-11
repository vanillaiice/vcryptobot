module logger

import os
import log

pub fn new(log_level string, output_target string, base string, quote string) !&log.Log {
	level := log.level_from_tag(log_level.to_upper()) or {
		eprintln('Invalid value for log level (fatal, error, warn, info, debug)')
		exit(1)
	}

	target := log.target_from_label(output_target) or {
		eprintln('Invalid value for output target (console, file, both)')
		exit(1)
	}

	mut logger := log.Log{
		level: level
	}

	if target == .file || target == .both {
		if os.exists('logs') == false {
			os.mkdir('logs')!
		}

		logger.set_full_logpath('logs/log_${base.to_lower()}_${quote.to_lower()}.txt')

		if target == .both {
			logger.log_to_console_too()
		}
	}

	return &logger
}
