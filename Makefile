.PHONY: build test bundle clean

build:
	swift build

test:
	swift test

bundle:
	bash scripts/bundle.sh

clean:
	swift package clean
	rm -rf KeepGoing.app
