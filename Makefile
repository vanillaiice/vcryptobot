os:
ifeq ($(OS), Windows_NT)
	v -cg -keepc . -os windows -o bin/vcryptobot.exe
else
	v -cg -keepc . -o bin/vcryptobot
endif

all: linux windows

linux:
	v -cg -keepc . -o bin/vcryptobot

windows:
	v -cg -keepc . -os windows -o bin/vcryptobot.exe
