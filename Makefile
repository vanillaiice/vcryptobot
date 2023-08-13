all: linux windows
linux:
	v -cg -keepc . -o bin/vcryptobot
windows:
	v -cg -keepc . -os windows -o bin/vcryptobot.exe
