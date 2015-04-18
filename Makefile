.PHONY: all clean distclean check install

SRC = c-format.coffee c-format-stream.coffee
SRC_DIR = src
SRC_PATH = $(patsubst %, $(SRC_DIR)/%, $(SRC))
OBJ_DIR = lib/c-format-stream
OBJ = $(patsubst $(SRC_DIR)/%.coffee, $(OBJ_DIR)/%.js, $(SRC_PATH))

BIN_DIR = bin
DRIVER = c-format
BIN_DRIVER = $(BIN_DIR)/$(DRIVER)
DRIVER_JS = $(patsubst %, $(OBJ_DIR)/%.js, $(DRIVER))

TEST_DIR = test
TEST_IN = $(TEST_DIR)/problem_a.cpp
TEST_CHECK = $(patsubst %.cpp, %_check_out.cpp, $(TEST_IN))
TEST_OUT = $(patsubst %.cpp, %_test_out.cpp, $(TEST_IN))

DEPS = node_modules

all: $(BIN_DRIVER)

$(BIN_DRIVER): $(DEPS) $(OBJ)
	@cp $(BIN_DIR)/c-format-stub $(BIN_DIR)/c-format
	@chmod +x $(BIN_DIR)/c-format

$(OBJ_DIR)/%.js: $(SRC_DIR)/%.coffee
	@./install_coffee_if_not.sh
	coffee -o $(OBJ_DIR) -bc $<

$(DEPS):
	@echo "Install required packages..."
	@npm install

clean:
	@rm -f $(OBJ) $(TEST_OUT) $(BIN_DRIVER)

distclean: clean
	@rm -rf $(DEPS)

$(TEST_DIR)/%_test_out.cpp: $(TEST_DIR)/%.cpp all
	$(BIN_DIR)/c-format $< $@ -n0

check: $(TEST_OUT)
	diff $(TEST_CHECK) $(TEST_OUT)

install: all
	npm install -g
