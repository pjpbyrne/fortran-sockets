all: test.exe

FLAGS := -fmax-errors=5 -Wall -Wextra

BUILD_DIR := obj
SRC_DIR := src
FMODFLAGS := -J $(BUILD_DIR) -I $(BUILD_DIR)

.PHONY: clean all test
.SECONDARY: src/tcpsockets.f90

test: test.exe
	test/run_test.py ./test.exe

test.exe: $(BUILD_DIR)/main.o $(BUILD_DIR)/arg_get_port.o $(BUILD_DIR)/tcpsockets.o $(BUILD_DIR)/sockets.o | $(BUILD_DIR)
	gfortran -o $@ $^

$(BUILD_DIR)/arg_get_port.o: test/arg_get_port.f90 | $(BUILD_DIR)
	gfortran ${FMODFLAGS} -c -o $@ $<

$(BUILD_DIR)/main.o: test/test_full.f90 $(BUILD_DIR)/arg_get_port.o $(BUILD_DIR)/tcpsockets.o | $(BUILD_DIR)
	gfortran ${FMODFLAGS} -c -o $@ $<

src/%.f90: src/%.fypp
	fypp $< $@

$(BUILD_DIR)/%.o: src/%.c | $(BUILD_DIR)
	gcc ${FLAGS} -c -o $@ $<

$(BUILD_DIR)/%.o: src/%.f90 | $(BUILD_DIR)
	gfortran ${FMODFLAGS} ${FLAGS} -c -o $@ $<

clean:
	rm -f *.exe
	rm -rf $(BUILD_DIR)

spotless: clean
	rm -f src/tcpsockets.f90

$(BUILD_DIR):
	mkdir $@
