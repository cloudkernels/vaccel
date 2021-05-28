#!/usr/bin/env bash

# retrieve script path
SCRIPTPATH=$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )

# tensorfow bindings source directory
SRC_DIR="$(pwd)/bindings/tensorflow-bindings"

# build directory
BUILD_DIR="$(pwd)/build"

# default installation directory
INSTALL_PREFIX="$(pwd)/output"

# script name for logging
LOG_NAME="$(basename $0)"

# tensorflow installation dir
TF_DIR="/usr"

source $SCRIPTPATH/utils.sh

print_args() {
	info "Build arguments"
	info "  SRC_DIR: $SRC_DIR"
	info "  BUILD_DIR: $BUILD_DIR"
	info "  INSTALL_PREFIX: $INSTALL_PREFIX"
	info "  TF_DIR: $TF_DIR"
	info ""
}

print_help() {
	echo ""
	echo "Usage: build_tf_bindings.sh [<args>]"
	echo ""
	echo "Arguments:"
	echo "    --src_dir          Tensorflow bindings source directory (default: \`\$(pwd)/bindings/tensorflow-bindings\`)"
	echo "    --build_dir        Directory to use for out-of-source build (default: 'build')"
	echo "    --install_prefix   Directory to install library (default: 'output')"
	echo "    --tf_dir           Tensorflow installation directory (default: '/usr')"
	echo ""
}

prepare_env() {
	mkdir -p $BUILD_DIR/bindings/tensorflow-bindings
	mkdir -p $INSTALL_PREFIX/lib
}

build() {
	cd $BUILD_DIR/bindings/tensorflow-bindings
	# Configure Cmake
	cmake $SRC_DIR \
		-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
		-DVACCEL_PATH=$INSTALL_PREFIX \
		-DTF_PATH=$TF_DIR

	# Build and install
	cmake --build . --config ${BUILD_TYPE}
	make install

	cd -
}

main() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)        { print_help; exit 1;       };;
			--src_dir)        { SRC_DIR=$2; shift;        };;
			--build_dir)      { BUILD_DIR=$2; shift;      };;
			--install_prefix) { INSTALL_PREFIX=$2; shift; };;
			--tf_dir)         { TF_DIR=$2; shift;         };;
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
