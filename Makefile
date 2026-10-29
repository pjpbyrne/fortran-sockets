all: test.exe

# Compilers: overridable (make FC=... CC=...); make's built-in defaults
# (cc, f77) are replaced with gcc/gfortran, which the flags below assume
ifeq ($(origin CC),default)
CC := gcc
endif
ifeq ($(origin FC),default)
FC := gfortran
endif

# fypp is optional: if it is missing or does not run, use the checked-in copy
FYPP ?= fypp
FYPP_WORKS := $(shell $(FYPP) --version >/dev/null 2>&1 && echo yes)

FLAGS := -fmax-errors=5 -Wall -Wextra
# Tests compare round-tripped reals exactly on purpose
TEST_FLAGS := $(FLAGS) -Wno-compare-reals

BUILD_DIR := obj
SRC_DIR := src
FMODFLAGS := -J $(BUILD_DIR) -I $(BUILD_DIR)

.PHONY: clean spotless all test
.SECONDARY: src/tcpsockets.f90

test: test.exe
	test/run_test.py ./test.exe

test.exe: $(BUILD_DIR)/main.o $(BUILD_DIR)/arg_get_port.o $(BUILD_DIR)/tcpsockets.o $(BUILD_DIR)/sockets.o | $(BUILD_DIR)
	$(FC) -o $@ $^

$(BUILD_DIR)/arg_get_port.o: test/arg_get_port.f90 | $(BUILD_DIR)
	$(FC) ${FMODFLAGS} ${TEST_FLAGS} -c -o $@ $<

$(BUILD_DIR)/main.o: test/test_full.f90 $(BUILD_DIR)/arg_get_port.o $(BUILD_DIR)/tcpsockets.o | $(BUILD_DIR)
	$(FC) ${FMODFLAGS} ${TEST_FLAGS} -c -o $@ $<

src/%.f90: src/%.fypp
ifeq ($(FYPP_WORKS),yes)
	$(FYPP) $< $@
else
	@echo "fypp not available: using preprocessed/$*.f90"
	cp preprocessed/$*.f90 $@
endif

$(BUILD_DIR)/%.o: src/%.c | $(BUILD_DIR)
	$(CC) ${FLAGS} -c -o $@ $<

$(BUILD_DIR)/%.o: src/%.f90 | $(BUILD_DIR)
	$(FC) ${FMODFLAGS} ${FLAGS} -c -o $@ $<

clean:
	rm -f *.exe
	rm -rf $(BUILD_DIR)

spotless: clean
	rm -f src/tcpsockets.f90

$(BUILD_DIR):
	mkdir $@
