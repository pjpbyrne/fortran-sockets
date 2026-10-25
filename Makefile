all: main.exe


FLAGS := -fmax-errors=5 -Wall -Wextra

BUILD_DIR := obj
SRC_DIR := src
FMODFLAGS := -J $(BUILD_DIR)

$(BUILD_DIR):
	mkdir $@

main.exe: obj/main.o obj/tcpsockets.o obj/sockets.o
	gfortran -o $@ $^

obj/main.o: test/test_prog.f90 obj/tcpsockets.o
	gfortran ${FMODFLAGS} -c -o $@ $<	

src/%.f90: src/%.fypp
	fypp $< $@

obj/%.o: src/%.c $(BUILD_DIR)
	gcc ${FLAGS} -c -o $@ $<

obj/%.o: src/%.f90 $(BUILD_DIR)
	gfortran ${FMODFLAGS} ${FLAGS} -c -o $@ $<

clean:
	rm -f main.exe
	rm -rf obj
