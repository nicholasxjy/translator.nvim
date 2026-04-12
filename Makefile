TESTS_INIT=tests/minimal_init.lua

.PHONY: test

test:
	@nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "lua require('tests.run').run()" \
		-c "qa!"
