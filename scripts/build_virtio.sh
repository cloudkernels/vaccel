#!/usr/bin/env bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# retrieve script path
SCRIPTPATH=$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )

# virtio-accel source directory
SRC_DIR="$(pwd)/virtio-accel"

# build directory
BUILD_DIR="$(pwd)/build"

# Default installation directory
INSTALL_PREFIX="$(pwd)/output"

# script name for logging
LOG_NAME="$(basename $0)"

source $SCRIPTPATH/utils.sh

print_args() {
	info "Build arguments"
	info "  SRC_DIR: $SRC_DIR"
	info "  BUILD_DIR: $BUILD_DIR"
	info "  INSTALL_PREFIX: $INSTALL_PREFIX"
	info ""
}

print_help() {
	echo ""
	echo "Usage: build_virtio.sh [<args>]"
	echo ""
	echo "Arguments:"
	echo "    --src_dir          VaccelRT source directory (default: \`\$(pwd)/virtio-accel\`)"
	echo "    --build_dir        Directory to use for out-of-source build (default: 'build')"
	echo "    --install_prefix   Directory to install library (default: 'output')"
	echo ""
}

prepare_env() {
	sudo apt update && sudo apt install wget
	mkdir -p $BUILD_DIR/virtio-accel
	mkdir -p $INSTALL_PREFIX/{share,include}
}

fetch_linux() {
	if [ ! -d "linux" ]; then
		git clone --depth=1 -b v5.10 https://github.com/torvalds/linux.git
	fi

	cd linux
	url=$(git remote get-url origin)
	echo "$url"
	if [ "$url" != "https://github.com/torvalds/linux.git" ]; then
		die "Bad linux repo in $(pwd). Remote is $url. Not overwritting"
	fi

	git checkout v5.10
}

build() {
	cd $BUILD_DIR/virtio-accel

	# First build the linux kernel
	fetch_linux
	#cd linux
	KERNEL_CONFIG=https://raw.githubusercontent.com/firecracker-microvm/firecracker/main/resources/guest_configs/microvm-kernel-x86_64-5.10.config
	wget $KERNEL_CONFIG -O arch/x86/configs/microvm.config
	touch .config
	make microvm.config CONFIG_MODULES=y
	make -j$(nproc) 
	ok_or_die "Could not build linux kernel"

	# Now build the module
	cd ..
	make -C $SRC_DIR KDIR=$BUILD_DIR/virtio-accel/linux ZC=0
	ok_or_die "Could not build the module"

	cp $SRC_DIR/accel.h $INSTALL_PREFIX/include
	cp $SRC_DIR/virtio_accel.ko $BUILD_DIR/virtio-accel/linux/vmlinux $INSTALL_PREFIX/share
}

main() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)        { print_help; exit 1;       };;
			--src_dir)        { SRC_DIR=$2; shift;        };;
			--build_dir)      { BUILD_DIR=$2; shift;      };;
			--install_prefix) { INSTALL_PREFIX=$2; shift; };;
			*)
				die "Unknown argument: \"$1\". Please use \`$0 --help\`."
				;;
		esac
		shift
	done

	print_args

	# Prepare build environment
	prepare_env

	# and build
	build
}

main "$@"
