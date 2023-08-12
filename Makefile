all: linux win
linux:
	v -cg -keepc . -o bin/vcryptobot
win:
	v -cg -keepc . -os windows -o bin/vcryptobot.exe
