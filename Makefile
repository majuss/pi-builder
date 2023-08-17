# ========================================================================== #
#                                                                            #
#    pi-builder - extensible tool to build Arch Linux ARM for Raspberry Pi   #
#                 on x86_64 host using Docker.                               #
#                                                                            #
#    Copyright (C) 2019  Maxim Devaev <mdevaev@gmail.com>                    #
#                                                                            #
#    This program is free software: you can redistribute it and/or modify    #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation, either version 3 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    This program is distributed in the hope that it will be useful,         #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License       #
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.  #
#                                                                            #
# ========================================================================== #


-include config.mk

PROJECT ?= common
BOARD ?= rpi4
ARCH ?= aarch64
UBOOT ?=
STAGES ?= __init__ os pikvm-repo watchdog no-bluetooth no-audit ro ssh-keygen __cleanup__
#DOCKER ?= podman #--storage-driver=vfs
DOCKER ?= docker

HOSTNAME ?= pi
LOCALE ?= en_US
TIMEZONE ?= Europe/Berlin
#REPO_URL ?= http://mirror.yandex.ru/archlinux-arm
REPO_URL ?= http://de3.mirror.archlinuxarm.org
PIKVM_REPO_URL ?= https://files.pikvm.org/repos/arch/
PIKVM_REPO_KEY ?= 912C773ABBD1B584
BUILD_OPTS ?=

CARD ?= /dev/sdd

QEMU_PREFIX ?= /usr
QEMU_RM ?= 1


# =====
_IMAGES_PREFIX = pi-builder-$(ARCH)
_TOOLBOX_IMAGE = $(_IMAGES_PREFIX)-toolbox
_PIOS_IMAGE_NAME = pi_image.img.xz

_CACHE_DIR = ./.cache
_BUILD_DIR = ./.build
_BUILT_IMAGE_CONFIG = ./.built.conf

_QEMU_GUEST_ARCH = $(ARCH)
_QEMU_STATIC_BASE_URL = http://mirror.yandex.ru/debian/pool/main/q/qemu
_QEMU_COLLECTION = qemu
_QEMU_STATIC = $(_QEMU_COLLECTION)/qemu-$(_QEMU_GUEST_ARCH)-static
_QEMU_STATIC_GUEST_PATH ?= $(QEMU_PREFIX)/bin/qemu-$(_QEMU_GUEST_ARCH)-static

_RPI_ROOTFS_TYPE = ${shell bash -c " \
	case '$(ARCH)' in \
		arm) \
			case '$(BOARD)' in \
				rpi2|rpi3|rpi4|zero2w) echo 'rpi-armv7';; \
				generic) echo 'armv7';; \
			esac;; \
		aarch64) \
			case '$(BOARD)' in \
				rpi3|rpi4) echo 'rpi-aarch64';; \
				generic) echo 'aarch64';; \
			esac;; \
	esac \
"}
ifeq ($(_RPI_ROOTFS_TYPE),)
$(error Invalid board and architecture combination: $(BOARD)-$(ARCH))
endif


# _RPI_ROOTFS_URL = https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-02-22/2023-02-21-raspios-bullseye-arm64-lite.img.xz
_RPI_ROOTFS_URL = https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-02-22/2023-02-21-raspios-bullseye-armhf-lite.img.xz
# https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-02-22/2023-02-21-raspios-bullseye-armhf-lite.img.xz

#_RPI_ROOTFS_URL = $(REPO_URL)/os/ArchLinuxARM-$(_RPI_ROOTFS_TYPE)-latest.tar.gz

_RPI_BASE_ROOTFS_TGZ = $(_CACHE_DIR)/base-rootfs-$(BOARD).tar.gz
_RPI_BASE_IMAGE = $(_IMAGES_PREFIX)-base-$(BOARD)
_RPI_RESULT_IMAGE = $(PROJECT)-$(_IMAGES_PREFIX)-result-$(BOARD)
_RPI_RESULT_ROOTFS_TAR = $(_CACHE_DIR)/result-rootfs.tar
_RPI_RESULT_ROOTFS = $(_CACHE_DIR)/result-rootfs


# =====
define optbool
$(filter $(shell echo $(1) | tr A-Z a-z),yes on 1)
endef

define say
@ tput -Txterm bold
@ tput -Txterm setaf 2
@ echo "===== $1 ====="
@ tput -Txterm sgr0
endef

define die
@ tput -Txterm bold
@ tput -Txterm setaf 1
@ echo "===== $1 ====="
@ tput -Txterm sgr0
@ exit 1
endef

define read_built_config
$(shell grep "^$(1)=" $(_BUILT_IMAGE_CONFIG) | cut -d"=" -f2)
endef

define show_running_config # 5.1th step in make
$(call say,"Running configuration")
@ echo "    PROJECT = $(PROJECT)"
@ echo "    BOARD   = $(BOARD)"
@ echo "    ARCH    = $(ARCH)"
@ echo "    STAGES  = $(STAGES)"
@ echo
@ echo "    BUILD_OPTS = $(BUILD_OPTS)"
@ echo "    HOSTNAME   = $(HOSTNAME)"
@ echo "    LOCALE     = $(LOCALE)"
@ echo "    TIMEZONE   = $(TIMEZONE)"
@ echo "    REPO_URL   = $(REPO_URL)"
@ echo "    PIKVM_REPO_URL   = $(PIKVM_REPO_URL)"
@ echo "    PIKVM_REPO_KEY   = $(PIKVM_REPO_KEY)"
@ echo
@ echo "    CARD = $(CARD)"
@ echo
@ echo "    QEMU_PREFIX = $(QEMU_PREFIX)"
@ echo "    QEMU_RM     = $(QEMU_RM)"
endef

define check_build
$(if $(wildcard $(_BUILT_IMAGE_CONFIG)),,$(call die,"Not built yet"))
endef


# =====
__DEP_BINFMT := $(if $(call optbool,$(PASS_ENSURE_BINFMT)),,binfmt)
__DEP_TOOLBOX := $(if $(call optbool,$(PASS_ENSURE_TOOLBOX)),,toolbox)


# =====
all:
	@ echo
	$(call say,"Available commands")
	@ echo "    make                     # Print this help"
	@ echo "    make rpi2|rpi3|rpi4|zero2w  # Build Arch-ARM rootfs with pre-defined config"
	@ echo "    make shell               # Run Arch-ARM shell"
	@ echo "    make toolbox             # Build the toolbox image"
	@ echo "    make binfmt              # Configure ARM binfmt on the host system"
	@ echo "    make scan                # Find all RPi devices in the local network"
	@ echo "    make clean               # Remove the generated rootfs"
	@ echo "    make format              # Format $(CARD)"
	@ echo "    make install             # Install rootfs to partitions on $(CARD)"
	@ echo
	$(call show_running_config)
	@ echo


rpi2: BOARD=rpi2
rpi3: BOARD=rpi3
rpi4: BOARD=rpi4
zero2w: BOARD=zero2w
generic: BOARD=generic
rpi2 rpi3 rpi4 zero2w generic: os


run: $(__DEP_BINFMT)
	$(call check_build)
	$(DOCKER) run \
			--rm \
			--tty \
			--hostname $(call read_built_config,HOSTNAME) \
			$(if $(RUN_CMD),$(RUN_OPTS),--interactive) \
		$(call read_built_config,IMAGE) \
		$(if $(RUN_CMD),$(RUN_CMD),/bin/bash)


shell: override RUN_OPTS:="$(RUN_OPTS) -i"
shell: run


toolbox: # 1st step in make
	$(call say,"Ensuring toolbox image")
	$(DOCKER) build \
			--rm \
			--tag $(_TOOLBOX_IMAGE) \
			$(if $(TAG),--tag $(TAG),) \
			--file toolbox/Dockerfile.root \
		toolbox
	$(call say,"Toolbox image is ready")


binfmt: $(__DEP_TOOLBOX) # 2nd step in make
	$(call say,"Ensuring $(_QEMU_GUEST_ARCH) binfmt")
	$(DOCKER) run \
			--rm \
			--tty \
			--privileged \
		$(_TOOLBOX_IMAGE) /tools/install-binfmt \
			--mount \
			$(_QEMU_GUEST_ARCH) \
			$(_QEMU_STATIC_GUEST_PATH)
	$(call say,"Binfmt $(_QEMU_GUEST_ARCH) is ready")


scan: $(__DEP_TOOLBOX)
	$(call say,"Searching for Pis in the local network")
	$(DOCKER) run \
			--rm \
			--tty \
			--net host \
		$(_TOOLBOX_IMAGE) arp-scan --localnet | grep -Pi "\s(b8:27:eb:|dc:a6:32:)" || true


os: $(__DEP_BINFMT) _buildctx # 5th step in make and last step TODO analyse env vars what they are doing
	$(call say,"Building OS")
	rm -f $(_BUILT_IMAGE_CONFIG)
	$(DOCKER) build \
			--rm \
			--tag $(_RPI_RESULT_IMAGE) \
			$(if $(TAG),--tag $(TAG),) \
			$(if $(call optbool,$(NC)),--no-cache,) \
			--build-arg "BOARD=$(BOARD)" \
			--build-arg "ARCH=$(ARCH)" \
			--build-arg "LOCALE=$(LOCALE)" \
			--build-arg "TIMEZONE=$(TIMEZONE)" \
			--build-arg "REPO_URL=$(REPO_URL)" \
			--build-arg "PIKVM_REPO_URL=$(PIKVM_REPO_URL)" \
			--build-arg "PIKVM_REPO_KEY=$(PIKVM_REPO_KEY)" \
			--build-arg "REBUILD=$(shell uuidgen)" \
			$(BUILD_OPTS) \
		$(_BUILD_DIR)
	echo "IMAGE=$(_RPI_RESULT_IMAGE)" > $(_BUILT_IMAGE_CONFIG)
	echo "HOSTNAME=$(HOSTNAME)" >> $(_BUILT_IMAGE_CONFIG)
	$(call show_running_config)
	$(call say,"Build complete") 


# =====
_buildctx: _rpi_base_rootfs_tgz qemu # 4th step in make
	$(call say,"Assembling main Dockerfile")
	rm -rf $(_BUILD_DIR)
	mkdir -p $(_BUILD_DIR)
	echo "Signature: 8a477f597d28d172789f06886806bc55" > "$(_BUILD_DIR)/CACHEDIR.TAG"
	ln $(_RPI_BASE_ROOTFS_TGZ) $(_BUILD_DIR)/$(PROJECT)-$(_IMAGES_PREFIX)-base-rootfs-$(BOARD).tgz
	cp $(_QEMU_STATIC) $(_QEMU_STATIC)-orig $(_BUILD_DIR)
	cp -r stages $(_BUILD_DIR)
	sed -i \
			-e 's|%BASE_ROOTFS_TGZ%|$(PROJECT)-$(_IMAGES_PREFIX)-base-rootfs-$(BOARD).tgz|g' \
			-e 's|%QEMU_GUEST_ARCH%|$(_QEMU_GUEST_ARCH)|g' \
			-e 's|%QEMU_STATIC_GUEST_PATH%|$(_QEMU_STATIC_GUEST_PATH)|g ' \
		$(_BUILD_DIR)/stages/__init__/Dockerfile.part
	echo -n > $(_BUILD_DIR)/Dockerfile
	for stage in $(STAGES); do \
		cat $(_BUILD_DIR)/stages/$$stage/Dockerfile.part >> $(_BUILD_DIR)/Dockerfile; \
	done
	$(call say,"Main Dockerfile is ready")

_rpi_base_rootfs_tgz: # 3rd step in make - downloads base root fs as tgz file not an image
	$(call say,"Ensuring base rootfs")
	if [ ! -e $(_RPI_BASE_ROOTFS_TGZ) ]; then \
		mkdir -p $(_CACHE_DIR) \
		&& cp base-rootfs-rpi4.tar.gz $(_CACHE_DIR)/ \
		&& echo "Signature: 8a477f597d28d172789f06886806bc55" > "../.$(_CACHE_DIR)/CACHEDIR.TAG" \
	; fi
	
	$(call say,"Base rootfs is ready")

# _rpi_base_rootfs_tgz: # 3rd step in make - downloads base root fs as tgz file not an image
# 	$(call say,"Ensuring base rootfs")
# 	if [ ! -e $(_RPI_BASE_ROOTFS_TGZ) ]; then \
# 		mkdir -p $(_CACHE_DIR) \
# 		&& cd $(_CACHE_DIR) \
# 		&& curl -L -f $(_RPI_ROOTFS_URL) -o $(_PIOS_IMAGE_NAME) \
# 		&& unxz -f $(_PIOS_IMAGE_NAME) \
# 		&& 7z x -aoa pi_image.img 1.img \
# 		&& mkdir -p root_fs \
# 		&& cd root_fs \
# 		&& 7z x -aoa ../1.img \
# 		&& rm -rf lib \
# 		&& ln -s usr/lib lib \
# 		&& cd ../.. \
# 		&& chmod -R +x .cache/root_fs/usr/bin/bash \
# 		&& cd .cache/root_fs \
# 		&& tar -czf ../.$(_RPI_BASE_ROOTFS_TGZ) * \
# 		&& echo "Signature: 8a477f597d28d172789f06886806bc55" > "../.$(_CACHE_DIR)/CACHEDIR.TAG" \
# 	; fi
	
# 	$(call say,"Base rootfs is ready")

# _rpi_base_rootfs_tgz: # 3rd step in make - downloads base root fs as tgz file not an image
# 	$(call say,"Ensuring base rootfs")
# 	if [ ! -e $(_RPI_BASE_ROOTFS_TGZ) ]; then \
# 		mkdir -p $(_CACHE_DIR) \
# 		&& cd $(_CACHE_DIR) \
# 		&& curl -L -f $(_RPI_ROOTFS_URL) -o base-rootfs-rpi4.tar.gz \
# 		&& echo "Signature: 8a477f597d28d172789f06886806bc55" > "CACHEDIR.TAG" \
# 	; fi
	
# 	$(call say,"Base rootfs is ready")

qemu: $(_QEMU_STATIC) $(_QEMU_STATIC)-orig


$(_QEMU_STATIC):
	mkdir -p $(_QEMU_COLLECTION)
	gcc -static -DQEMU_ARCH=\"$(ARCH)\" -m32 qemu-wrapper.c -o $(_QEMU_STATIC)
	$(call say,"QEMU wrapper is ready")


$(_QEMU_STATIC)-orig:
	$(call say,"Downloading QEMU")
	# Using i386 QEMU because of this:
	#   - https://bugs.launchpad.net/qemu/+bug/1805913
	#   - https://lkml.org/lkml/2018/12/27/155
	#   - https://stackoverflow.com/questions/27554325/readdir-32-64-compatibility-issues
	mkdir -p $(_QEMU_COLLECTION)
	mkdir -p $(_CACHE_DIR)/qemu-user-static-deb
	curl -L -f $(_QEMU_STATIC_BASE_URL)/`curl -s -S -L -f $(_QEMU_STATIC_BASE_URL)/ \
			-z $(_CACHE_DIR)/qemu-user-static-deb/qemu-user-static.deb \
				| grep qemu-user-static \
				| grep _$(if $(filter-out aarch64,$(ARCH)),i386,amd64).deb \
				| sort -n \
				| tail -n 1 \
				| sed -n 's/.*href="\([^"]*\).*/\1/p'` \
		-o $(_CACHE_DIR)/qemu-user-static-deb/qemu-user-static.deb \
		-z $(_CACHE_DIR)/qemu-user-static-deb/qemu-user-static.deb
	cd $(_CACHE_DIR)/qemu-user-static-deb \
		&& ar vx qemu-user-static.deb \
		&& tar -xJf data.tar.xz
	cp $(_CACHE_DIR)/qemu-user-static-deb/usr/bin/qemu-$(ARCH)-static $(_QEMU_STATIC)-orig
	$(call say,"QEMU is ready")


# =====
clean:
	rm -rf $(_BUILD_DIR) $(_BUILT_IMAGE_CONFIG)


__DOCKER_RUN_TMP = $(DOCKER) run \
		--rm \
		--tty \
		--volume $(shell pwd)/$(_CACHE_DIR):/root/$(_CACHE_DIR) \
		--workdir /root/$(_CACHE_DIR)/.. \
	$(_TOOLBOX_IMAGE)


__DOCKER_RUN_TMP_PRIVILEGED = $(DOCKER) run \
		--rm \
		--interactive \
		--privileged \
		--volume $(shell pwd)/$(_CACHE_DIR):/root/$(_CACHE_DIR) \
		--workdir /root/$(_CACHE_DIR)/.. \
	$(_TOOLBOX_IMAGE)


clean-all: $(__DEP_TOOLBOX) clean
	$(__DOCKER_RUN_TMP) rm -rf $(_RPI_RESULT_ROOTFS)
	rm -rf base-rootfs-rpi4.tar.gz
	rm -rf originalimage.img
	rm -rf originalimage64.img
	rm -rf $(_CACHE_DIR)


# FIXME: add generic offset from 32Mb
format: $(__DEP_TOOLBOX)
	$(call check_build)
	$(call say,"Formatting $(CARD)")
	$(__DOCKER_RUN_TMP_PRIVILEGED) dd if=/dev/zero of=$(CARD) bs=1M count=32
	$(__DOCKER_RUN_TMP_PRIVILEGED) /sbin/partprobe $(CARD)
	cat disk.conf | $(__DOCKER_RUN_TMP_PRIVILEGED) /tools/disk format $(CARD)
	cat disk.conf | $(__DOCKER_RUN_TMP_PRIVILEGED) /tools/disk mkfs $(CARD)
	$(call say,"Format complete")


extract: $(__DEP_TOOLBOX)
	$(call check_build)
	$(call say,"Extracting image from Docker")
	$(__DOCKER_RUN_TMP) rm -rf $(_RPI_RESULT_ROOTFS)
	$(DOCKER) save --output $(_RPI_RESULT_ROOTFS_TAR) $(call read_built_config,IMAGE)
	$(__DOCKER_RUN_TMP) /tools/docker-extract --root $(_RPI_RESULT_ROOTFS) $(_RPI_RESULT_ROOTFS_TAR)
	$(__DOCKER_RUN_TMP) bash -c " \
		echo $(call read_built_config,HOSTNAME) > $(_RPI_RESULT_ROOTFS)/etc/hostname \
		&& (test -z '$(call optbool,$(QEMU_RM))' || rm $(_RPI_RESULT_ROOTFS)/$(_QEMU_STATIC_GUEST_PATH)) \
	"
	$(call say,"Extraction complete")


install: extract format install-uboot
	$(call say,"Installing to $(CARD)")
	cat disk.conf | $(__DOCKER_RUN_TMP_PRIVILEGED) bash -c ' \
		set -ex \
		&& DISK_CONF=$$(</dev/stdin) \
		&& (echo -e "$$DISK_CONF" | /tools/disk mount $(CARD) mnt) \
		&& rsync -a --quiet $(_RPI_RESULT_ROOTFS)/* mnt \
		&& (echo -e "$$DISK_CONF" | /tools/disk umount $(CARD)) \
	'
	$(call say,"Installation complete")


install-uboot:
ifneq ($(UBOOT),)
	$(call say,"Installing U-Boot $(UBOOT) to $(CARD)")
	$(call check_build)
	$(DOCKER) run \
		--rm \
		--tty \
		--volume `pwd`/$(_RPI_RESULT_ROOTFS)/boot:/tmp/boot \
		--device $(CARD):/dev/mmcblk0 \
		--hostname $(call read_built_config,HOSTNAME) \
		$(call read_built_config,IMAGE) \
		bash -c " \
			cp -a /boot/* /tmp/boot/ \
		"
	$(call say,"U-Boot installation complete")
endif	


.PHONY: toolbox qemu
.NOTPARALLEL: clean-all install
