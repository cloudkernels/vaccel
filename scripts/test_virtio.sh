#!/usr/bin/env bash

# retrieve path
SCRIPTPATH=$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )

# Default path to vAccel installation
VACCEL_PATH=/opt/vaccel

# Timeout waiting for Firecracker response
SSH_TIMEOUT=300

# Firecracker IP
FC_IP="172.42.0.2"

# script name for logging
LOG_NAME="$(basename $0)"

source $SCRIPTPATH/utils.sh

print_help() {
	echo ""
	echo "Usage: ./test-virtio.sh [<args>]"
	echo ""
	echo "Arguments:"
	echo "    -v|--vaccel     Directory of vAccel installation (default: '/opt/vaccel')"
	echo "    -t|--timeout    Timeout in seconds to wait response from Firecracker (default: 300)"
	echo "    -a|--ip-address Address of Firecracker VM"
	echo ""
}

_run_ssh_test() {
	ssh -o StrictHostKeyChecking=no root@$FC_IP $1
}

test_image_classification() {
	in_fc_cmd="LD_LIBRARY_PATH=$VACCEL_PATH/lib"
	in_fc_cmd="$in_fc_cmd VACCEL_BACKENDS=$VACCEL_PATH/lib/libvaccel-virtio.so"
	in_fc_cmd="$in_fc_cmd VACCEL_DEBUG_LEVEL=4"
	in_fc_cmd="$in_fc_cmd $VACCEL_PATH/bin/classify $VACCEL_PATH/share/images/dog_1.jpg 1"

	_run_ssh_test "$in_fc_cmd"
}

run_tests() {
	test_image_classification
}

main() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)        { print_help; exit 1;    };;
			-v|--vaccel)      { VACCEL_PATH=$2; shift; };;
			-t|--timeout)     { SSH_TIMEOUT=$2; shift; };;
			-a|--ip-address)  { FC_IP=$2; shift;       };;
			*)
				die "Unknown argument: \"$1\". Please use \`$0 --help\`."
				;;
		esac
		shift
	done

	run_tests
}

main "$@"
