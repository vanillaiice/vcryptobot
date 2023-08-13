# Create the 'bin' directory if it doesn't exist
$(shell mkdir -p bin)

# Compile depending on OS
os:
ifeq ($(OS), Windows_NT)
	$(MAKE) windows
else
	$(MAKE) linux
endif

# Compile for both linux and windows
all: linux windows

# Compile for linux
linux:
	v -cg -keepc . -o ./bin/vcryptobot

# Compile for windows
windows:
	v -cg -keepc . -os windows -o ./bin/vcryptobot.exe
