.PHONY : all build run logs

all: build

build:
	docker build -t photobot_img .

run:
	docker run -ti --rm -v "$$(pwd)/data":/data/photos photobot_img

logs:
	cat data/logs/sync.log
