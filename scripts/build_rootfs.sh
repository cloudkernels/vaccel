#!/usr/bin/env bash

# retrieve path
SCRIPTPATH=$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )

# Build directory
BUILD_DIR=build

# Default installation directory
INSTALL_PREFIX=output

# Dockerfiles path
DOCKERFILES_PATH="dockerfiles"

# Base image to use
BASE_IMAGE="ubuntu:latest"

# script name for logging
LOG_NAME="$(basename $0)"

source $SCRIPTPATH/utils.sh

fetch_from_git() {
	local git_url="https://github.com/$1"
	local dest_dir="$2"

	svn export $git_url $dest_dir
}

print_help() {
	echo ""
	echo "Usage: build_rootfs.sh [<args>]"
	echo ""
	echo "Arguments:"
	echo "    --help|-h          Print this message and exit"
	echo "    --build_dir        Directory to use for building (default: 'build')"
	echo "    --install_prefix   Directory to install library (default: 'output')"
	echo "    --base_image       Base image to use (default: ubuntu:latest)"
	echo "    --dockerfiles_path Path to find dockerfiles for base images (default: dockerfiles)"
	echo ""
	echo "Available sub-commands"
	echo ""
	echo "    build_base_rootfs"
	echo "        Build the base root file system (without vAccel binaries installed)"
	echo ""
	echo "    install_vaccel"
	echo "        Install vAccel binaries inside root file system"
	echo ""
	echo "    all"
	echo "        Build the base rootfs and then install the vAccel binaries in it"
	echo ""
	echo "    help"
	echo "        Print this message"
	echo ""
}


build_base_rootfs() {
	info "Building base Firecracker root filesystem"
	mkdir -p ${BUILD_DIR}/rootfs
	cd ${BUILD_DIR}/rootfs

	# Fetch Dockerfile on which we'll base the image
	local image=$(echo "${BASE_IMAGE}" | awk -F ":" '{print $1}')
	local tag=$(echo "${BASE_IMAGE}" | awk -F ":" '{print $2}')

	info "Copying Dockerfile from: ${DOCKERFILES_PATH}/${image}/${tag}"
	if [ ! -f "${DOCKERFILES_PATH}/${image}/${tag}/Dockerfile" ]; then
		die "Could not find base image"
	fi

	cp ${DOCKERFILES_PATH}/${image}/${tag}/Dockerfile .
	ok_or_die "Could not find Dockerfile for ${BASE_IMAGE}"

	info "Build root filesystem from Dockerfile"
	# Create root filesystem
	DOCKER_BUILDKIT=1 docker build \
		--network=host \
		-t vaccel-rootfs \
		--build-arg "KERNEL_VERSION=4.20.0" \
		--output type=local,dest=. .
	ok_or_die "Could not build the base rootfs"

	info "Prepare rootfs.img"
	dd if=/dev/zero of=rootfs.img bs=1M count=0 seek=1024
	sudo mkfs.ext4 rootfs.img
	ok_or_die "Could not create filesystem for rootfs"

	info "Copy rootfs in img file"
	mkdir -p mnt
	mnt="$(mktemp -d)"
	sudo mount rootfs.img $mnt
	ok_or_die "Could not mount rootfs"

	sudo rsync -aogxvPH rootfs/* $mnt

	# Setup nameserver
	# We need to do it here, because Docker does not let us change its
	# rootfs
	echo "nameserver 8.8.8.8" > $mnt/etc/resolv.conf

	sudo chown -R root:root $mnt/root
	ok_or_die "Could not populate rootfs"

	sudo umount $mnt
	ok_or_die "Could not unmount rootfs"

	sudo sync
	sudo rmdir $mnt

	info "Install rootfs.img under ${INSTALL_PREFIX}/share"
	cp rootfs.img ${INSTALL_PREFIX}/share/
}

install_vaccel() {
	info "Installing vAccel in root filesystem"
	mkdir -p ${BUILD_DIR}/rootfs
	cd ${BUILD_DIR}/rootfs

	if [ ! -f $INSTALL_PREFIX/share/rootfs.img ]; then
		die "Base root file system is not built"
	fi

	mnt="$(mktemp -d)"
	sudo mount $INSTALL_PREFIX/share/rootfs.img $mnt
	ok_or_die "Could not mount rootfs"

	if [[ ! -d $mnt/opt/vaccel ]] ; then
		die "Base rootfs is not built properly"
	fi

	info "Copying files"
	cp -r $INSTALL_PREFIX/{bin,lib,include} $mnt/opt/vaccel/

	mkdir -p $mnt/opt/vaccel/share
	cp -r $INSTALL_PREFIX/share/models $mnt/opt/vaccel/share
	ok_or_die "Could not copy ML models"

	mkdir -p $mnt/opt/vaccel/share/images
	fetch_from_git dusty-nv/jetson-inference/trunk/data/images/dog_1.jpg $mnt/opt/vaccel/share/images/dog_1.jpg
	ok_or_die "Could not download example image"

	info "Setup VirtIO module"
	# Setup VirtIO module (hardcoded kernel version)
	mkdir -p $mnt/lib/modules/4.20.0
	cp $INSTALL_PREFIX/share/virtio_accel.ko $mnt/lib/modules/4.20.0
	touch $mnt/lib/modules/4.20.0/modules.order
	touch $mnt/lib/modules/4.20.0/modules.builtin
	echo "virtio_accel" >> $mnt/etc/modules
	sudo chroot $mnt /sbin/depmod 4.20.0

	sudo sync
	sudo umount $mnt
	ok_or_die "Could not unmount root file system"
}

all() {
	build_base_rootfs
	install_vaccel
}

main() {
	if [ $# == 0 ]; then
		die "Insufficient script arguments. Use \`$0 --help\'."
	fi

	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)          { print_help; exit 1;         };;
			--build_dir)        { BUILD_DIR=$2; shift;        };;
			--install_prefix)   { INSTALL_PREFIX=$2; shift;   };;
			--base_image)       { BASE_IMAGE=$2; shift;       };;
			--dockerfiles_path) { DOCKERFILES_PATH=$2; shift; };;
			*-)
				die "Unknown argument: \"$1\". Please use \`$0 --help\`."
				;;
			*)
				break;
				;;
		esac
		shift
	done

	# Make sure that $1 is a valid command
	declare -f "$1" > /dev/null
	ok_or_die "Unknown command: '$1'. Please use \`$0 --help\`."

	$1 "$@"
}

main "$@"
