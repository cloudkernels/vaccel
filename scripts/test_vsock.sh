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

# Default path to vAccel installation
VACCEL_PATH=/opt/vaccel

# Timeout waiting for Firecracker response
SSH_TIMEOUT=300

# Firecracker IP
FC_IP="172.42.0.2"

# vsock socket to use inside the VM
VACCEL_VSOCK="vsock://2:2048"

# unix socket to use on the host
VACCEL_UNIX="unix:///tmp/vaccel.sock_2048"

# plugin to use for agent
PLUGIN="libvaccel-jetson.so"

# Agent binary prefix
AGENT_PREFIX="/opt/cargo/bin"

# Agent PID
AGENT_PID=

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
	echo "    -p|--plugin     Plugin to use for agent"
	echo "    --agent-prefix  Location of the agent binary"
	echo "    --vsock         Vsock socket to use inside the VM"
	echo "    --unix          Unix socket to use on host"
	echo ""
}

launch_agent() {
	info "Running agent with plugin: $PLUGIN"
	VACCEL_DEBUG_LEVEL=4 VACCEL_BACKENDS=$PLUGIN $AGENT_PREFIX/vaccelrt-agent -a $VACCEL_UNIX &
	AGENT_PID=$!

	# Wait a couple of seconds to let the agent start
	sleep 2
}

kill_agent() {
	kill -9 $AGENT_PID
}

_run_ssh_test() {
	ssh -o StrictHostKeyChecking=no root@$FC_IP $1
}

test_image_classification() {
	info "Testing image classification"
	in_fc_cmd="LD_LIBRARY_PATH=$VACCEL_PATH/lib"
	in_fc_cmd="$in_fc_cmd VACCEL_BACKENDS=$VACCEL_PATH/lib/libvaccel-vsock.so"
	in_fc_cmd="$in_fc_cmd VACCEL_VSOCK=$VACCEL_VSOCK"
	in_fc_cmd="$in_fc_cmd VACCEL_DEBUG_LEVEL=4"
	in_fc_cmd="$in_fc_cmd $VACCEL_PATH/bin/classify $VACCEL_PATH/share/images/dog_1.jpg 1"

	_run_ssh_test "$in_fc_cmd"
}

test_tf_inference() {
	info "Testing TensorFlow inference"
	in_fc_cmd="LD_LIBRARY_PATH=$VACCEL_PATH/lib"
	in_fc_cmd="$in_fc_cmd VACCEL_BACKENDS=$VACCEL_PATH/lib/libvaccel-vsock.so"
	in_fc_cmd="$in_fc_cmd VACCEL_VSOCK=$VACCEL_VSOCK"
	in_fc_cmd="$in_fc_cmd VACCEL_DEBUG_LEVEL=4"
	in_fc_cmd="$in_fc_cmd $VACCEL_PATH/bin/tf_inference $VACCEL_PATH/share/models/tf/lstm2"

	_run_ssh_test "$in_fc_cmd"
}

test_tf_saved_model() {
	info "Testing TensorFlow SavedModel resource API"
	in_fc_cmd="LD_LIBRARY_PATH=$VACCEL_PATH/lib"
	in_fc_cmd="$in_fc_cmd VACCEL_BACKENDS=$VACCEL_PATH/lib/libvaccel-vsock.so"
	in_fc_cmd="$in_fc_cmd VACCEL_VSOCK=$VACCEL_VSOCK"
	in_fc_cmd="$in_fc_cmd VACCEL_DEBUG_LEVEL=4"
	in_fc_cmd="$in_fc_cmd $VACCEL_PATH/bin/tf_saved_model $VACCEL_PATH/share/models/tf/lstm2"

	_run_ssh_test "$in_fc_cmd"
}

run_tests() {
	launch_agent
	ok_or_die "Could not launch agent"

	test_image_classification
	retval=$?
	if [[ $retval -ne 0 ]]
	then
		err "image classification failed: $retval"
		kill_agent
		exit $retval
	fi

	test_tf_inference
	retval=$?
	if [[ $? -ne 0 ]]
	then
		err "TensorFlow inference failed: $retval"
		kill_agent
		exit $retval
	fi

	test_tf_saved_model
	retval=$?
	if [[ $? -ne 0 ]]
	then
		err "TensorFlow SavedModel resource API failed: $retval"
		kill_agent
		exit $retval
	fi
}

main() {
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)        { print_help; exit 1;     };;
			-v|--vaccel)      { VACCEL_PATH=$2; shift;  };;
			-t|--timeout)     { SSH_TIMEOUT=$2; shift;  };;
			-a|--ip-address)  { FC_IP=$2; shift;        };;
			-p|--plugin)      { PLUGIN=$2; shift;       };;
			--agent-prefix)   { AGENT_PREFIX=$2; shift; };;
			--vsock)          { VACCEL_VSOCK=$2; shift; };;
			--unix)           { VACCEL_UNIX=$2; shift;  };;
			*)
				die "Unknown argument: \"$1\". Please use \`$0 --help\`."
				;;
		esac
		shift
	done

	run_tests
}

main "$@"
