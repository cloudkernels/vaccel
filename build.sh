#!/usr/bin/env bash

# Some defaults
# source directory
SOURCEDIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# top-level build directory
BUILD_DIR=$(pwd)/build

# install directory
INSTALL_PREFIX=$(pwd)/output

# Dockerfiles directory
DOCKERFILES_DIR=$(pwd)/dockerfiles

# Build type
BUILD_TYPE=debug

# Use container to build
CTR_BUILD=no

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

runctr() {
	docker run --rm -ti \
	       -v $SOURCEDIR:$SOURCEDIR \
	       -v $BUILD_DIR:$BUILD_DIR \
	       -v $INSTALL_PREFIX:$INSTALL_PREFIX \
	       "$@"
}

runctr_vaccel_deps() {
	runctr nubificus/vaccel-deps:latest "$@"
}

# Build vAccelRT inside a container
_build_vaccelrt_ctr() {
	info "Calling VaccelRT script inside container"
	runctr_vaccel_deps $SOURCEDIR/scripts/build_vaccelrt.sh \
		--$BUILD_TYPE \
		--src_dir $SOURCEDIR/vaccelrt \
		--build_dir $BUILD_DIR/$BUILD_TYPE \
		--install_prefix $INSTALL_PREFIX/$BUILD_TYPE
	ok_or_die "Could not build vaccelrt inside container"

	# Fix permissions
	runctr_vaccel_deps chown -R "$(id -u):$(id -g)" \
		$BUILD_DIR/$BUILD_TYPE/vaccelrt \
		$INSTALL_PREFIX/$BUILD_TYPE

	ok_or_die "Could not fix permissions for vaccelrt"
}

# Build vAccelRT on host
_build_vaccelrt_host() {
	info "Calling VaccelRT script on host"
	./scripts/build_vaccelrt.sh \
		--build_dir $BUILD_DIR/$BUILD_TYPE \
		--install_prefix $INSTALL_PREFIX/$BUILD_TYPE
}

build_vaccelrt() {
	[ "$CTR_BUILD" == yes ] && _build_vaccelrt_ctr || _build_vaccelrt_host
}

#Build Firecracker
build_firecracker() {
	info "Calling firecracker script"
	./scripts/build_firecracker.sh --$BUILD_TYPE --install_prefix $INSTALL_PREFIX/$BUILD_TYPE
	ok_or_die "Could not build firecracker"
}

_build_virtio_host() {
	info "Calling the virtio-accel build script on host"
	./scripts/build_virtio.sh \
		--build_dir $BUILD_DIR/$BUILD_TYPE \
		--install_prefix $INSTALL_PREFIX/$BUILD_TYPE
	ok_or_die "Could not build virtio module"
}

_build_virtio_ctr() {
	info "Calling the virtio-accel build script inside container"
	runctr kernel-build-container:gcc-7 \
		$SOURCEDIR/scripts/build_virtio.sh \
		--build_dir $BUILD_DIR/$BUILD_TYPE \
		--src_dir $SOURCEDIR/virtio-accel \
		--install_prefix $INSTALL_PREFIX/$BUILD_TYPE
	ok_or_die "Could not build virtio module and Linux kernel"

	runctr kernel-build-container:gcc-7 \
		chown -R "$(id -u):$(id -g)" \
			$BUILD_DIR/$BUILD_TYPE/virtio-accel \
			$INSTALL_PREFIX/$BUILD_TYPE
	ok_or_die "Could not fix permissions for virtio module and Linux kernel"
}

build_virtio() {
	[ "$CTR_BUILD" == yes ] && _build_virtio_ctr || _build_virtio_host
}

build_tf_plugin() {
	info "Calling TensorFlow plugin build script inside container"
	runctr nubificus/tensorflow \
		$SOURCEDIR/scripts/build_tf_plugin.sh \
		--$BUILD_TYPE \
		--src_dir $SOURCEDIR/plugins/vaccelrt-plugin-tensorflow \
		--build_dir $BUILD_DIR/$BUILD_TYPE \
		--install_prefix $INSTALL_PREFIX/$BUILD_TYPE
	ok_or_die "Could not build TensorFlow plugin inside container"

	# Fix permissions
	runctr nubificus/tensorflow \
		chown -R "$(id -u):$(id -g)" \
			$BUILD_DIR/$BUILD_TYPE/tf-plugin \
			$INSTALL_PREFIX/$BUILD_TYPE
	ok_or_die "Could not fix permissions for TensorFlow plugin"
}

build_vsock_plugin() {
	info "Calling vsock plugin build script"
	runctr nubificus/vaccel-deps \
		$SOURCEDIR/scripts/build_vsock_plugin.sh \
			--$BUILD_TYPE \
			--src_dir $SOURCEDIR/plugins/vaccelrt-plugin-vsock \
			--build_dir $BUILD_DIR/$BUILD_TYPE \
			--install_prefix $INSTALL_PREFIX/$BUILD_TYPE
	ok_or_die "Could not build vsock plugin"

	# Fix permissions
	runctr nubificus/tensorflow \
		chown -R "$(id -u):$(id -g)" \
			$BUILD_DIR/$BUILD_TYPE/vsock-plugin \
			$INSTALL_PREFIX/$BUILD_TYPE
	ok_or_die "Could not fix permissions for TensorFlow plugin"
}

build_fc_rootfs() {
	info "Calling the rootfs build script"
	./scripts/build_rootfs.sh \
		--install_prefix $INSTALL_PREFIX/$BUILD_TYPE \
		--build_dir $BUILD_DIR/$BUILD_TYPE \
		--base_image "ubuntu:latest" \
		--dockerfiles_path $DOCKERFILES_DIR \
		"$@"
	ok_or_die "Could not build rootfs"
}

download_models() {
	info "Downloading imagenet models"
	mkdir -p $INSTALL_PREFIX/$BUILD_TYPE/share/networks
	./scripts/download-models.sh NO $INSTALL_PREFIX/$BUILD_TYPE/share/networks
}

build_plugins() {
	build_vsock_plugin
	build_tf_plugin
}

build_all() {
	build_vaccelrt
	build_firecracker
	build_virtio
	build_fc_rootfs
	build_plugins
	download_models
}

build_help() {
	echo ""
	echo "Vaccel build script"
	echo "Usage: $(basename $0) [<args>] <component>"
	echo ""
	echo "Arguments"
	echo "    --release|--debug     Build release or debug versions. (default:--debug)"
	echo "    --build_dir           The top-level build directory. (default: $(pwd)/build)"
	echo "    --install_dir         The directory to install output binaries. (default: $(pwd)/output)"
	echo "    -c|--ctr_build        Use container to build components, atm vAccelRT"
	echo ""
	echo "Available components to build:"
	echo ""
	echo "    all"
	echo "        build all Vaccel components"
	echo ""
	echo "    vaccelrt"
	echo "        build the VaccelRT runtime"
	echo ""
	echo "    firecracker"
	echo "        build Firecracker"
	echo ""
	echo "    virtio"
	echo "        build the vaccel-virtio module & corresponding kernel"
	echo ""
	echo "    tf_plugin"
	echo "        build the TensorFlow plugin"
	echo ""
	echo "    fc_rootfs"
	echo "        build a rootfs image for firecracker"
	echo ""
	echo "    imagenet-models"
	echo "        Download imagenet network models"
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
			-c|--ctr_build) { CTR_BUILD=yes;            };;
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
