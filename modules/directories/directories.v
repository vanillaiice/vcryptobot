module directories

import log
import os

pub fn setup(mut logger log.Log) {
	dirs := [
		'db/prices',
		'db/tx_history',
		// "logs",
		'state',
	]

	for d in dirs {
		if os.exists(d) == false {
			os.mkdir_all(d) or { logger.fatal('${err}') }
			logger.debug("creating directory '${d}'")
		}
	}
}
