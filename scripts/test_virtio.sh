#!/usr/bin/env bash

# retrieve path
SCRIPTPATH=$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )

# Default path to vAccel installation
VACCEL_PATH=/opt/vaccel

# Timeout waiting for Firecracker response
SSH_TIMEOUT=300

# Firecracker IP
FC_IP="172.42.0.2"

# Path to ssh private key
SSH_KEY=$(pwd)/opt/share/fc_test

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
	echo "    -i|--ssh-key    RSA key to use for SSHing inside the VM"
	echo ""
}

run_test() {
	in_fc_cmd="LD_LIBRARY_PATH=$VACCEL_PATH/lib"
	in_fc_cmd="$in_fc_cmd VACCEL_BACKENDS=$VACCEL_PATH/lib/libvaccel-virtio.so"
	in_fc_cmd="$in_fc_cmd $VACCEL_PATH/bin/classify /root/images/dog_0.jpg 1"

	ssh -o StrictHostKeyChecking=no -i $SSH_KEY root@$FC_IP $in_fc_cmd
}

main() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)        { print_help; exit 1;    };;
			-v|--vaccel)      { VACCEL_PATH=$2; shift; };;
			-t|--timeout)     { SSH_TIMEOUT=$2; shift; };;
			-a|--ip-address)  { FC_IP=$2; shift;       };;
			-i|--ssh-key)     { SSH_KEY=$2; shift;     };;
			*)
				die "Unknown argument: \"$1\". Please use \`$0 --help\`."
				;;
		esac
		shift
	done

	run_test
}

main "$@"
