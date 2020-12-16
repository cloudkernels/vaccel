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

print_help() {
	echo ""
	echo "Usage: build_rootfs.sh [<args>]"
	echo ""
	echo "Arguments:"
	echo "    --build_dir        Directory to use for building (default: 'build')"
	echo "    --install_prefix   Directory to install library (default: 'output')"
	echo "    --base_image       Base image to use (default: ubuntu:latest)"
	echo "    --dockerfiles_path Path to find dockerfiles for base images (default: dockerfiles)"
	echo ""
}

fetch_images() {
	svn export https://github.com/dusty-nv/jetson-inference/trunk/data/images images
}

prepare_env() {
	if [ -d ${BUILD_DIR}/rootfs ]; then
		rm -rf ${BUILD_DIR}/rootfs/*
	else
		mkdir -p ${BUILD_DIR}/rootfs
	fi

	pushd ${BUILD_DIR}/rootfs > /dev/null

	# Bring other components
	cp -r ${INSTALL_PREFIX}/* .

	# Fetch Dockerfile on which we'll base the image
	local image=$(echo "${BASE_IMAGE}" | awk -F ":" '{print $1}')
	local tag=$(echo "${BASE_IMAGE}" | awk -F ":" '{print $2}')

	info "Copying Dockerfile from: ${DOCKERFILES_PATH}/${image}/${tag}"
	if [ ! -f "${DOCKERFILES_PATH}/${image}/${tag}/Dockerfile" ]; then
		die "Could not find base image"
	fi

	cp ${DOCKERFILES_PATH}/${image}/${tag}/Dockerfile .

	# Fetch imagenet
	mkdir -p imagenet
	pushd imagenet > /dev/null

	fetch_images

	popd > /dev/null
	popd > /dev/null
}

build() {
	cd ${BUILD_DIR}/rootfs

	# Create root filesystem
	DOCKER_BUILDKIT=1 docker build \
		--network=host \
		-t vaccel-rootfs \
		--build-arg "KERNEL_VERSION=4.20.0" \
		--output type=local,dest=. .

	dd if=/dev/zero of=rootfs.img bs=1M count=0 seek=512
	sudo mkfs.ext4 rootfs.img
	ok_or_die "Could not create filesystem for rootfs"

	mkdir -p mnt
	sudo mount rootfs.img mnt
	ok_or_die "Could not mount rootfs"

	sudo rsync -aogxvPH rootfs/* mnt
	ok_or_die "Could not populate rootfs"

	sudo rsync -aogxvPH imagenet/images mnt/root/
	ok_or_die "Could not add images"

	sudo umount mnt
	ok_or_die "Could unmount rootfs"

	sudo sync
	sudo rmdir mnt

	cp rootfs.img ${INSTALL_PREFIX}/share/
}

main() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)          { print_help; exit 1;         };;
			--build_dir)        { BUILD_DIR=$2; shift;        };;
			--install_prefix)   { INSTALL_PREFIX=$2; shift;   };;
			--base_image)       { BASE_IMAGE=$2; shift;       };;
			--dockerfiles_path) { DOCKERFILES_PATH=$2; shift; };;
			*)
				die "Unknown argument: \"$1\". Please use \`$0 --help\`."
				;;
		esac
		shift
	done

	# Prepare build environment
	prepare_env

	# and build
	build
}

main "$@"