# V Crypto Bot

Simple Crypto Trading Bot using Binance Spot and Websocket API.
This Bot buys and sells crypto at user specified margins.

## Usage

```
vcryptobot --config <PATH TO CONFIG.JSON>
```

- Omitting the ```--config``` option will trigger the config file creation interactive prompt.
- Also, you can reate an .env file containing your binance api key and secret key in the following format:

```
SECRET_KEY = "<YOUR SECRET KEY>"
API_KEY = "<YOUR API KEY>"
```

- If the .env file is not present, the .env file creation interactive prompt will be trigerred.
- **Testnet** secret and api keys can be created [here](https://testnet.binance.vision)

## Dependencies

- [sqlite](https://modules.vlang.io/db.sqlite.html)
- [zztkm.vdotenv](https://github.com/zztkm/vdotenv)
- [vanillaiice.vbinance](https://github.com/vanillaiice/vbinance)
- make (optional)
- MinGW-w64 (optional, for windows cross compilation)

## Installation

First, make sure that you have [V](https://github.com/vlang/v/blob/master/README.md#installing-v-from-source) 
and [sqlite](https://modules.vlang.io/db.sqlite.html) (should already be installed for MacOS users) installed on your machine. Then, you can do the following:

```
> git clone https://github.com/vanillaiice/vcryptobot
> cd v-crypto-bot
> v install
> v .
// or
> make
```

## Config File

- ```base```, base currency of the trading pair.
> example: "BTC"

- ```quote```, quote currency of the trading pair.
> example: "USDT"

- ```tradingBalance```, initial trading balance of the bot.
> example for BTC: 0.01

- ```firstTx```, type of the first transaction executed by the bot.
> accepted values: "buy" or "sell"

- ```skipFirstTx```, if the bot should skip the first transaction (firstTx).
> accepted values: true or false

- ```percentChangeBuy```, percent change between the last sell price and current price, at which the bot will buy.
> example value (%): 5.0

- ```percentChangeSell```, percent change between the current price and last buy price, at which the bot will sell.
> example value (%): 5.0

- ```trailingStopLossMargin``` (optional), percent change between the current price and last buy price, at which the bot will sell to limit losses.
> example value (%): 2.5

- ```stopEntryPrice``` (optional), entry price at which the bot will buy.
> example value for BTC: 0.011

- ```stopEntryPriceMargin``` (optional), minimum percent change between the current price and the stop entry price, at which the bot will buy. 
> example value (%): 0.1 

- ```adjustTradingBalanceLoss```, if the bot should substract losses from the trading balance.
> accepted values: true or false

- ```adjustTradingBalanceProfit```, if the bot should add profits to the trading balance.
> accepted values: true or false

- ```decisionIntervalMs```, time in milliseconds at which the bot will decide to buy or sell.
> example value in ms: 1500

- ```serverBaseEndpoint```, base endpoint of the Binance API server.
> example base endpoint for testnet server: "testnet.binance.vision"

> example base endpoint for normal server: "api.binance.com"

- ```outputTarget```, output target of the content of the bot's log.
> accepted values: "console", "file", "both"

- ```logLevel```, log level of the bot.
> accepted values: "fatal", "error", "warn", "info", "debug"

- ```logPriceToDb```, if the bot should log the prices fetched in a sqlite database.
> accepted values: true or false

- ```logTxToDb```, if the bot should log the transaction receipt in a sqlite database.
> accepted values: true or false

## Acknowledgments

- [zztkm.vdotenv](https://github.com/zztkm/vdotenv), MIT License

## Disclaimer

- No warranty whatsoever, use at your own risk
- Trading crypto is very risky, *only invest in what you can afford to lose*

## Licence

BSD-3-Clause
