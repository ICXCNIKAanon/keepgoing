.PHONY: build test bundle release clean

build:
	swift build

test:
	swift test

bundle:
	bash scripts/bundle.sh

release: bundle
	cd KeepGoing.app && zip -r ../KeepGoing-macos.zip .
	@echo "Release artifact: KeepGoing-macos.zip"

clean:
	swift package clean
	rm -rf KeepGoing.app KeepGoing-macos.zip
