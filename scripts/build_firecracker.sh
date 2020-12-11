#!/usr/bin/env bash

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
