.PHONY: all clean distclean check install

# required to build
NPM_BIN := $(shell npm bin)
COFFEE_CC := coffee

SRC := c-format.coffee c-format-stream.coffee
SRC_DIR := src
SRC_PATH := $(patsubst %, $(SRC_DIR)/%, $(SRC))
OBJ_DIR := lib/c-format-stream
OBJ := $(patsubst $(SRC_DIR)/%.coffee, $(OBJ_DIR)/%.js, $(SRC_PATH))

DRIVER := c-format
BIN_DIR := bin
BIN_DRIVER := $(BIN_DIR)/$(DRIVER)

TEST_DIR := test
TEST_IN := $(TEST_DIR)/problem_a.cpp
TEST_CHECK := $(patsubst %.cpp, %_check_out.cpp, $(TEST_IN))
TEST_OUT := $(patsubst %.cpp, %_test_out.cpp, $(TEST_IN))

DEPS := node_modules

all: $(BIN_DRIVER)

$(BIN_DRIVER): $(DEPS) $(OBJ)
	@cp $@-stub $@
	@chmod +x $@

$(OBJ_DIR)/%.js: $(SRC_DIR)/%.coffee
	$(COFFEE_CC) -o $(OBJ_DIR) -bc $<

$(DEPS):
	@echo "Install required packages..."
	@npm install

clean:
	@rm -f $(OBJ) $(TEST_OUT) $(BIN_DRIVER)

distclean: clean
	@rm -rf $(DEPS)

$(TEST_DIR)/%_test_out.cpp: $(TEST_DIR)/%_check_out.cpp all
	$(BIN_DRIVER) $< $@ -n0
	diff $< $@

check: $(TEST_OUT)

install:
	@npm install -g
