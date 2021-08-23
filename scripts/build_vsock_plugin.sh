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

# retrieve path
SCRIPTPATH=$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )

# Default build type
BUILD_TYPE=Debug

# plugin source directory
SRC_DIR="$(pwd)/plugins/vaccelrt-plugin-vsock"

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
	echo "Usage: build_vsock_plugin.sh [<args>]"
	echo ""
	echo "Arguments:"
	echo "    --release|--debug  Type of build (default: debug)"
	echo "    --src_dir          TensorFlow plugin source directory (default: \`\$(pwd)/plugins/vaccelrt-plugin-vsock\`)"
	echo "    --build_dir        Directory to use for out-of-source build (default: 'build')"
	echo "    --install_prefix   Directory to install library (default: 'output')"
	echo ""
}


prepare_env() {
	mkdir -p $BUILD_DIR/vsock-plugin
	info "Build directory: $BUILD_DIR/vsock-plugin"
}

build() {
	cd $BUILD_DIR/vsock-plugin
	# Configure Cmake
	cmake $SRC_DIR \
		-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
		-DCMAKE_BUILD_TYPE=$BUILD_TYPE
	ok_or_die "Could not configure cmake"

	# Build and install
	cmake --build . --config ${BUILD_TYPE}
	ok_or_die "Could not build"

	make install
	ok_or_die "Could not install"

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
