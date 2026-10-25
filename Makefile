all: test.exe

FLAGS := -fmax-errors=5 -Wall -Wextra

BUILD_DIR := obj
SRC_DIR := src
FMODFLAGS := -J $(BUILD_DIR) -I $(BUILD_DIR)

.PHONY: clean all test
.SECONDARY: src/tcpsockets.f90

test: test.exe
	test/python-server.py &
	sleep 1
	./test.exe

test.exe: obj/main.o obj/tcpsockets.o obj/sockets.o
	gfortran -o $@ $^

obj/main.o: test/test_prog.f90 obj/tcpsockets.o
	gfortran ${FMODFLAGS} -c -o $@ $<	

src/%.f90: src/%.fypp
	fypp $< $@

obj/%.o: src/%.c | $(BUILD_DIR)
	gcc ${FLAGS} -c -o $@ $<

obj/%.o: src/%.f90 | $(BUILD_DIR)
	gfortran ${FMODFLAGS} ${FLAGS} -c -o $@ $<

clean:
	rm -f *.exe
	rm -rf obj

$(BUILD_DIR):
	mkdir $@
