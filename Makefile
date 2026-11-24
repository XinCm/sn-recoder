.PHONY: build run test preview icon clean

build:
	./scripts/build.sh

run: build
	-@killall MemoBar 2>/dev/null || true
	@sleep 0.5
	@open build/MemoBar.app
	@echo "MemoBar running. Click the calendar icon in the menu bar."

test:
	./scripts/test.sh

preview:
	./scripts/render-preview.sh

icon:
	python3 scripts/make-icon.py

clean:
	rm -rf build .build
