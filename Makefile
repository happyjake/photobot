DATAROOT = /Volumes/photo

.PHONY : all build run logs

all: build

build:
	docker build -t photobot_img .

mount:
	echo "mount with /Volumes enable on osx. use script from [here](git@github.com:happyjake/docker_home.git)."
	#docker-machine ssh "sudo mkdir /Volumes"
	#docker-machine ssh "sudo mount -t vboxsf -o uid=1000,gid=50,,iocharset=utf8 Volumes /Volumes"

run:
	docker run --privileged -ti --rm -v "$(DATAROOT)":/data/photos photobot_img

test:
	docker run --privileged -ti --rm -v "$(DATAROOT)":/data/photos ubuntu

shell:
	docker run --privileged -ti --rm -v $(DATAROOT):/data/photos photobot_img bash

logs:
	cat "$(DATAROOT)/logs/sync.log"
