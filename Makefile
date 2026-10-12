objects = build/main.o build/brainfuck.o build/read_file.o
.PHONY: clean benchmark

brainfuck: $(objects)
	$(CC) -no-pie -o "$@" $^

benchmark: brainfuck
	python3 tests/performance.py --binary ./brainfuck

build:
	mkdir build

build/%.o: %.s | build
	$(CC) -no-pie -c -o "$@" "$<"

clean:
	rm -rf brainfuck build
