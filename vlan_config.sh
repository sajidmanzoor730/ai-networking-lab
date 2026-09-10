#!/bin/bash
# SONiC / Spectrum-like VLAN + LACP + MTU config
VLAN_ID=100
INTERFACE="Ethernet0"
MTU=9000
echo "[*] Configuring VLAN $VLAN_ID on $INTERFACE"
sudo config vlan add $VLAN_ID
sudo config vlan member add $VLAN_ID $INTERFACE
sudo ip link set $INTERFACE mtu $MTU
sudo ip link add bond0 type bond mode 802.3ad
sudo ip link set eth1 master bond0
sudo ip link set eth2 master bond0
echo "[*] Validation"
ethtool -S $INTERFACE | grep -E "crc|error|drop"
iperf3 -s &
echo "Done"
