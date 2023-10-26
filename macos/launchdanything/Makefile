# build the golang app

.DEFAULT_GOAL := build

sign:
	codesign -s "Apple Development: Sam McLeod-Jones (S64522742G)" launchdanything -v || true

# Build the app
build:
	go build -o launchdanything main.go
	chmod +x launchdanything
	make sign
	ls -lah launchdanything
