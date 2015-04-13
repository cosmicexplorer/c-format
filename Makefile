.PHONY: all clean distclean check install

SRC = format-c.coffee format-c-stream.coffee
OBJ = $(patsubst %.coffee, obj/%.js, $(SRC))

DRIVER = format-c
DRIVER_JS = $(patsubst %, obj/%.js, $(DRIVER))

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
	coffee -o obj -c $<

$(DEPS):
	@echo "Install required packages..."
	@npm install

clean:
	@rm -f $(OBJ) $(DRIVER)

distclean: clean
	@rm -rf $(DEPS)

check: all
	@echo "error: no check target yet" 1>&2
	@exit -1

install: all
	@echo "error: no install target yet" 1>&2
	@exit -1
