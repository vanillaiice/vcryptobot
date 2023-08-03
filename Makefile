all: linux win
linux:
	v -cg -keepc . -o bin/vbot
win:
	v -cg -keepc . -os windows -o bin/vbot.exe
