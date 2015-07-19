DATAROOT = /Volumes/photos

.PHONY : all build run logs

all: build

build:
	docker build -t photobot_img .

mount:
	boot2docker down
	VBoxManage sharedfolder add boot2docker-vm -name Volumes -hostpath /Volumes
	boot2docker up
	boot2docker ssh "sudo mkdir /Volumes"
	boot2docker ssh "sudo mount -t vboxsf -o uid=1000,gid=50 Volumes /Volumes"

run:
	docker run -ti --rm -v "$(DATAROOT)":/data/photos photobot_img

logs:
	cat "$(DATAROOT)/logs/sync.log"
