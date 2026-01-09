#!/bin/bash
# Script called by QEMU (with CAP_NET_ADMIN) to clean up a tap interface
# $1 is the tap interface name

# Just bring it down, QEMU will delete it
ip link set $1 down
