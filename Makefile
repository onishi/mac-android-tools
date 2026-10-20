INSTALL_DIR ?= $(HOME)/Applications

.PHONY: build install uninstall test clean

build:
	./scripts/build-apps.sh

install: build
	./scripts/install-apps.sh "$(INSTALL_DIR)"

uninstall:
	./scripts/uninstall-apps.sh "$(INSTALL_DIR)"

test:
	swift test --disable-sandbox

clean:
	swift package clean
	rm -rf dist
