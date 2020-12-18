#!/bin/bash

if [[ $# -ne 2 ]] ; then
	echo "usage $0 tapName address/prefix"
	exit 1
fi

tap_name=$1
addr=$2

ip tuntap add ${tap_name} mode tap
ip addr add dev ${tap_name} ${addr}
ip link set dev ${tap_name} up
