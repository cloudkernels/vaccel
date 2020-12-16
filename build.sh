#!/usr/bin/env bash

# Some defaults
# source directory
SOURCEDIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# top-level build directory
BUILD_DIR=$(pwd)/build

# install directory
INSTALL_PREFIX=$(pwd)/output

# Build type
BUILD_TYPE=debug

# name for logging
LOG_NAME="vaccel build"

source $SOURCEDIR/scripts/utils.sh

print_build_options() {
	info ""
	info "Build options:"
	info "    BUILD_DIR: $BUILD_DIR"
	info "    INSTALL_PREFIX: $INSTALL_PREFIX"
	info "    BUILD_TYPE: $BUILD_TYPE"
	info ""
}

prepare_build_env() {
	mkdir -p $INSTALL_PREFIX/$BUILD_TYPE/{lib,include,share,bin}
	mkdir -p $BUILD_DIR/$BUILD_TYPE
}

#Build VaccelRT
runctr_vaccel_deps() {
	docker run --rm -ti \
		-v ${SOURCEDIR}/scripts:/scripts \
		-v ${SOURCEDIR}/vaccelrt:/vaccelrt \
		-v ${BUILD_DIR}/${BUILD_TYPE}:/build \
		-v ${INSTALL_PREFIX}/${BUILD_TYPE}:/output \
		nubificus/vaccel-deps:latest "$@"
}

build_vaccelrt() {
	info "Calling VaccelRT script inside container"
	runctr_vaccel_deps /scripts/build_vaccelrt.sh \
		--$BUILD_TYPE \
		--src_dir /vaccelrt \
		--build_dir /build \
		--install_prefix /output
	ok_or_die "Could not build vaccelrt inside container"

	# Fix permissions
	runctr_vaccel_deps chown -R "$(id -u):$(id -g)" /build /output
	ok_or_die "Could not fix permissions for vaccelrt"
}

#Build Firecracker
build_firecracker() {
	info "Calling firecracker script"
	./scripts/build_firecracker.sh --$BUILD_TYPE --install_prefix $INSTALL_PREFIX/$BUILD_TYPE
}

build_virtio() {
	info "Calling the virtio-accel build script"
	./scripts/build_virtio.sh \
		--build_dir $BUILD_DIR/$BUILD_TYPE \
		--install_prefix $INSTALL_PREFIX/$BUILD_TYPE
}

build_fc_rootfs() {
	die "Building the rootfs is not supported yet"
}

build_all() {
	build_vaccelrt
	build_firecracker
	build_virtio
	build_fc_rootfs
}

build_help() {
	echo ""
	echo "Vaccel build script"
	echo "Usage: $(basename $0) [<args>] <component>"
	echo ""
	echo "Arguments"
	echo "    --release|--debug     Build release or debug versions. (default:--debug)"
	echo "    --build_dir           The top-level build directory"
	echo "    --install_dir         The directory to install output binaries"
	echo ""
	echo "Available components to build:"
	echo ""
	echo "    all:         build all Vaccel components"
	echo "    vaccelrt:    build the VaccelRT runtime"
	echo "    firecracker: build Firecracker"
	echo "    virtio:      build the vaccel-virtio module & corresponding kernel"
	echo "    fc_rootfs:   build a rootfs image for firecracker"
	echo ""
}

main() {
	if [ $# == 0 ]; then
		die "Insufficient script arguments. Use \`$0 --help\` for help."
	fi

	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)      { build_help; exit 1;       };;
			--release)      { BUILD_TYPE=release;       };;
			--debug)        { BUILD_TYPE=debug;         };;
			--build_dir)    { BUILD_DIR=$2; shift;      };;
			--install_dir)  { INSTALL_PREFIX=$2; shift; };;
			-*)
				die "Unkown argument: $1. Please use \`$0 help\`."
				;;
			*)
				break;
				;;
		esac
		shift
	done

	print_build_options

	# Make sure that $1 is a valid command
	declare -f "build_$1" > /dev/null
	ok_or_die "Unkown command: $1. Please use \`$0 help\`."

	cmd=build_$1
	shift

	# Create all the necessary directories
	prepare_build_env

	# Call the command and pass it the remaining arguments.
	# At the moment no arguments are passed in the commands, but keep
	# it like this for the future
	$cmd "$@"
}

main "$@"
