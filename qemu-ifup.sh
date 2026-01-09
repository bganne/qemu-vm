#!/bin/bash
# Script called by QEMU (with CAP_NET_ADMIN) to configure a tap interface
# $1 is the tap interface name (e.g., tap0, tap1)

BRIDGE=${BRIDGE:-vmtest0}
BRIDGE_IP=${BRIDGE_IP:-192.168.100.1/24}

# Create bridge if it doesn't exist
if ! ip link show $BRIDGE > /dev/null 2>&1; then
    ip link add name $BRIDGE type bridge
    ip addr add $BRIDGE_IP dev $BRIDGE
    ip link set $BRIDGE up
fi

# Attach tap to bridge and bring it up
ip link set $1 master $BRIDGE
ip link set $1 up
