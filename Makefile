.PHONY: all clean distclean check install

SRC = c-format.coffee c-format-stream.coffee
OBJ = $(patsubst %.coffee, obj/%.js, $(SRC))

DRIVER = c-format
DRIVER_JS = $(patsubst %, obj/%.js, $(DRIVER))

TEST_IN = test/problem_a.cpp
TEST_CHECK = $(patsubst %.cpp, %_check_out.cpp, $(TEST_IN))
TEST_OUT = $(patsubst %.cpp, %_test_out.cpp, $(TEST_IN))

DEPS = node_modules

all: $(DEPS) $(OBJ)

obj/%.js: %.coffee
	@./install_coffee_if_not.sh
	coffee -o obj -bc $<

$(DEPS):
	@echo "Install required packages..."
	@npm install

clean:
	@rm -f $(OBJ)

distclean: clean
	@rm -rf $(DEPS)

test/%_test_out.cpp: test/%.cpp all
	node obj/c-format.js $< $@ -n0

check: $(TEST_OUT)
	diff $(TEST_CHECK) $(TEST_OUT)

install: all
	cp -r . /usr/bin
	ln -s /usr/bin/c-format/c-format /usr/bin/c-format
