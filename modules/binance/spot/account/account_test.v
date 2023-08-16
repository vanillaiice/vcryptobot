module account

import os
import zztkm.vdotenv

fn test_spot_account_info() {
	vdotenv.load('.env')
	skey := os.getenv('SECRET_KEY')
	apikey := os.getenv('API_KEY')

	r := spot_account_info_pretty('testnet.binance.vision', skey, apikey)!

	println(r)
}
