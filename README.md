# V Crypto Bot

Simple Crypto Trading Bot using Binance Spot and Websocket API.
This Bot buys and sells crypto at user specified margins.

## Usage

```
vbot --config <PATH TO CONFIG.JSON>
```

- Omitting the ```--config``` option will trigger the config file creation interactive prompt.
- Also, you can reate an .env file containing your binance api key and secret key in the following format:

```
SECRET_KEY = "<YOUR SECRET KEY>"
API_KEY = "<YOUR API KEY>"
```

- If the .env file is not present, the .env file creation interactive prompt will be trigerred.
- **Testnet** secret and api keys can be created at https://testnet.binance.vision/

## Config File

- **tradingBalance**, the bot's trading allowance.
> example value for BTC: 0.0025 

> example value for TRX: 500

- **firstTx**, the type of the first transaction the bot will execute.
> accepted values: "buy" or "sell"

- **skipFirstTx**, if the bot should skip the first transaction.
> accepted values: true or false

- **buyMargin**, the margin at which the bot should buy an asset (difference between last sell price and current price).
> example value in %: 0.1

- **sellMargin**, the margin at which the bot should sell an asset (difference between last buy price and current price).
> example value in %: 0.1

- **decisionIntervalMs**, the time in milliseconds at which the bot will decide to buy or sell.
> example value in ms: 1500

- **wsServerUrl**, URL of the websocket server .
> example URL for testnet server: "wss://testnet.binance.vision/ws-api/v3"

> example URL for normal server: "wss://ws-api.binance.com:443/ws-api/v3"

- **serverUrl**, URL of the Spot API server.
> example URL for testnet server: "https://testnet.binance.vision/api/v3"

> example URL for normal server: "https://api.binance.com/api/v3"

- **base**, base currency of the trading pair.
> example value: "BTC"

- **quote**, quote currency of the trading pair.
> exmample value: "USDT"

- **logLevel**, log level of the bot.
> accepted values: "fatal", "error", "warn", "info", "debug"

- **outputTarget**, output target of the content of the bot's log.
> accepted values: "console", "file", "both"

# Installation

```
> git clone https://github.com/vanillaiice/v-crypto-bot
> cd v-crypto-bot
> v .
// or
> make
```

## Development dependencies

- v
- sqlite
- zzktm.vdotenv
- make (optional)
- MinGW-w64 (optional, for windows cross compilation)

## Acknowledgments

- [zzktm.vdotenv](https://github.com/zztkm/vdotenv), MIT License

## Disclaimer

- This project is still in alpha stage
- No warranty whatsoever, use at your own risk
- Trading crypto is *very* risky, only invest in what you can afford to lose

## Licence

BSD-3-Clause
