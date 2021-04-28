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
#SSH_KEY=$(pwd)/opt/share/fc_test

# vsock socket to use inside the VM
VACCEL_VSOCK="vsock://2:2048"

# unix socket to use on the host
VACCEL_UNIX="unix:///tmp/vaccel.sock_2048"

# plugin to use for agent
PLUGIN="libvaccel-jetson.so"

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
	echo "    -i|--ssh-key    RSA key to use for SSHing inside the VM (not currently used)"
	echo "    -p|--plugin     Plugin to use for agent"
	echo "    --vsock         Vsock socket to use inside the VM"
	echo "    --unix          Unix socket to use on host"
	echo ""
}

launch_agent() {
	info "Running agent with plugin: $PLUGIN"
	VACCEL_DEBUG_LEVEL=4 VACCEL_BACKENDS=$PLUGIN vaccelrt-agent -a $VACCEL_UNIX &

	# Wait a couple of seconds to let the agent start
	sleep 2
}

run_test() {
	in_fc_cmd="LD_LIBRARY_PATH=$VACCEL_PATH/lib"
	in_fc_cmd="$in_fc_cmd VACCEL_BACKENDS=$VACCEL_PATH/lib/libvaccel-vsock.so"
	in_fc_cmd="$in_fc_cmd VACCEL_VSOCK=$VACCEL_VSOCK"
	in_fc_cmd="$in_fc_cmd VACCEL_DEBUG_LEVEL=4"
	in_fc_cmd="$in_fc_cmd $VACCEL_PATH/bin/classify /root/images/dog_0.jpg 1"

	launch_agent
	ok_or_die "Could not launch agent"

	ssh -o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null \
		-o UserKnownHostsFile=/dev/null root@$FC_IP $in_fc_cmd
}

main() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)        { print_help; exit 1;     };;
			-v|--vaccel)      { VACCEL_PATH=$2; shift;  };;
			-t|--timeout)     { SSH_TIMEOUT=$2; shift;  };;
			-a|--ip-address)  { FC_IP=$2; shift;        };;
			-i|--ssh-key)     { SSH_KEY=$2; shift;      };;
			-p|--plugin)      { PLUGIN=$2; shift;       };;
			--vsock)          { VACCEL_VSOCK=$2; shift; };;
			--unix)           { VACCEL_UNIX=$2; shift;  };;
			*)
				die "Unknown argument: \"$1\". Please use \`$0 --help\`."
				;;
		esac
		shift
	done

	run_test
}

main "$@"
