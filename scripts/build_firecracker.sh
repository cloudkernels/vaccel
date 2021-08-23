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

# Default installation directory
INSTALL_PREFIX=output

# script name for logging
LOG_NAME="$(basename $0)"

source $SCRIPTPATH/utils.sh

print_help() {
	echo ""
	echo "Usage: build_firecracker.sh [<args>]"
	echo ""
	echo "Arguments:"
	echo "    --release|--debug  Type of build (default: debug)"
	echo "    --install_prefix   Installation directory of firecracker binary"
	echo ""
}

build_fc() {
	info "Building firecracker (build_type: $BUILD_TYPE install_prefix: $INSTALL_PREFIX)"

	./firecracker/tools/devtool build -l gnu --$BUILD_TYPE
	ok_or_die "Error building firecracker"

	mkdir -p ${INSTALL_PREFIX}/bin
	cp firecracker/build/cargo_target/x86_64-unknown-linux-gnu/$BUILD_TYPE/firecracker $INSTALL_PREFIX/bin
	cp conf/config_virtio_accel.json $INSTALL_PREFIX/share/
	cp conf/config_vsock.json $INSTALL_PREFIX/share/
	ok_or_die "Could not copy firecracker binary to destination"

	info "Copied firecracker binary to $INSTALL_PREFIX/bin"
}

main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)        { print_help; exit 1;        };;
			--release)        { BUILD_TYPE=release;        };;
			--debug)          { BUILD_TYPE=debug;          };;
			--install_prefix) { INSTALL_PREFIX=$2; shift;  };;
			*)
				die "Unknown argument: \"$1\". Please use \`$0 --help\`."
				;;
		esac
		shift
	done

	# Build firecracker and copy binary to installation directory
	build_fc
}

main "$@"
