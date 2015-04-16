.PHONY: all clean distclean check install

SRC = format-c.coffee format-c-stream.coffee
OBJ = $(patsubst %.coffee, obj/%.js, $(SRC))

DRIVER = format-c
DRIVER_JS = $(patsubst %, obj/%.js, $(DRIVER))

TEST_IN = test/problem_a.cpp
TEST_CHECK = $(patsubst %.cpp, %_check_out.cpp, $(TEST_IN))
TEST_OUT = $(patsubst %.cpp, %_test_out.cpp, $(TEST_IN))

DEPS = node_modules

all: $(DRIVER)

$(DRIVER): $(DEPS) $(OBJ)
	@echo "#!/bin/sh" > $@
	@echo "# generated driver script" >> $@
	@echo "WD=\$$(cd \"\$$(dirname \"\$${BASH_SOURCE[0]}\")\" && pwd)" >> $@
	@echo "driver=\"\$$(echo $(DRIVER_JS))\"" >> $@
	@echo >> $@
	@echo "# pass all arguments as args to node process" >> $@
	@echo "node \"\$$WD/\$$driver\" \$$@" >> $@
	@chmod +x $@

obj/%.js: %.coffee
	@./install_coffee_if_not.sh
	coffee -o obj -bc $<

$(DEPS):
	@echo "Install required packages..."
	@npm install

clean:
	@rm -f $(OBJ) $(DRIVER)

distclean: clean
	@rm -rf $(DEPS)

test/%_test_out.cpp: test/%.cpp all
	./format-c $< $@ -n0

check: $(TEST_OUT)
	diff $(TEST_CHECK) $(TEST_OUT)

install: all
	cp -r . /usr/bin
	ln -s /usr/bin/format-c/format-c /usr/bin/format-c
