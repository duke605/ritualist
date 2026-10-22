LUA ?= lua5.4

.PHONY: test check fmt lint package data

test:
	$(LUA) tests/run.lua

# Syntax-checks every Lua file.
check:
	@find plugin tests -name '*.lua' -exec luac5.4 -p {} + && echo "Syntax OK"

fmt:
	stylua plugin tests types

# Formatting plus lua-language-server diagnostics (uses .luarc.json and types/).
lint:
	stylua --check plugin tests types
	lua-language-server --check=. --checklevel=Warning --check_format=pretty

package: check
	scripts/package.py

# Regenerates plugin/src/data/*.lua from the web app's JSON. Set NRC to a local checkout to skip the clone.
NRC_REPO ?= https://github.com/duke605/necromancy-ritual-calculator
data:
	@if [ -n "$(NRC)" ]; then scripts/gen-data.py "$(NRC)"; else \
		tmp=$$(mktemp -d) && trap 'rm -rf "$$tmp"' EXIT && \
		git clone -q --depth 1 $(NRC_REPO) "$$tmp" && scripts/gen-data.py "$$tmp"; fi
	stylua plugin/src/data
