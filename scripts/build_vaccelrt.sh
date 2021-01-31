#!/usr/bin/env bash

# retrieve path
SCRIPTPATH=$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )

# Default build type
BUILD_TYPE=Debug

# vaccelrt source directory
SRC_DIR="$(pwd)/vaccelrt"

# Build directory
BUILD_DIR="$(pwd)/build"

# Default installation directory
INSTALL_PREFIX="$(pwd)/output"

# script name for logging
LOG_NAME="$(basename $0)"

source $SCRIPTPATH/utils.sh

print_args() {
	info "Build arguments"
	info "  BUILD_TYPE: $BUILD_TYPE"
	info "  SRC_DIR: $SRC_DIR"
	info "  BUILD_DIR: $BUILD_DIR"
	info "  INSTALL_PREFIX: $INSTALL_PREFIX"
	info ""
}

print_help() {
	echo ""
	echo "Usage: build_vaccelrt.sh [<args>]"
	echo ""
	echo "Arguments:"
	echo "    --release|--debug  Type of build (default: debug)"
	echo "    --src_dir          VaccelRT source directory (default: \`\$(pwd)/vaccelrt\`)"
	echo "    --build_dir        Directory to use for out-of-source build (default: 'build')"
	echo "    --install_prefix   Directory to install library (default: 'output')"
	echo ""
}


prepare_env() {
	mkdir -p $BUILD_DIR/vaccelrt
}

build() {
	cd $BUILD_DIR/vaccelrt
	# Configure Cmake
	cmake $SRC_DIR \
		-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
		-DCMAKE_BUILD_TYPE=$BUILD_TYPE \
		-DBUILD_EXAMPLES=ON \
		-DBUILD_PLUGIN_JETSON=ON \
		-DBUILD_PLUGIN_VIRTIO=ON \
		-DBUILD_PLUGIN_VSOCK=ON

	# Build and install
	cmake --build . --config ${BUILD_TYPE}
	make test && \
		make install -C src && \
		make install -C plugins && \
		make install -C examples
	cd -
}

main() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)        { print_help; exit 1;       };;
			--release)        { BUILD_TYPE=Release;       };;
			--debug)          { BUILD_TYPE=Debug;         };;
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
