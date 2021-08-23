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
BUILD_TYPE=debug

# plugin source directory
SRC_DIR="$(pwd)/agent"

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
	echo "Usage: build_agent.sh [<args>]"
	echo ""
	echo "Arguments:"
	echo "    --release|--debug  Type of build (default: debug)"
	echo "    --src_dir          vAccel source directory (default: \`\$(pwd)/agent\`)"
	echo "    --build_dir        Directory to use for out-of-source build (default: 'build')"
	echo "    --install_prefix   Directory to install library (default: 'output')"
	echo "    -h|--help          Print this message and exit"
	echo ""
}


prepare_env() {
	mkdir -p $BUILD_DIR/vaccel-agent
	info "Build directory: $BUILD_DIR/vaccel-agent"
}

build() {
	cd $SRC_DIR

	# Build the crate
	if [[ $BUILD_TYPE == "debug" ]]; then
		info "Building debug version"
		cargo build --target-dir $BUILD_DIR/vaccel-agent
	else
		info "Building release version"
		cargo build --release --target-dir $BUILD_DIR/vaccel-agent
	fi

	ok_or_die "Could not build vAccel agent"

	# Install the binary
	mkdir -p $INSTALL_PREFIX/bin
	cp $BUILD_DIR/vaccel-agent/$BUILD_TYPE/vaccelrt-agent $INSTALL_PREFIX/bin/

	cd -
}

main() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)        { print_help; exit 1;       };;
			--release)        { BUILD_TYPE=release;       };;
			--debug)          { BUILD_TYPE=debug;         };;
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
