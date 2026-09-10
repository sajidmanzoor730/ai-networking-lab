# AI Networking Lab - NVIDIA Spectrum & SONiC Concepts
Homelab simulating AI fabric for GPU clusters - work done for NVIDIA Network Infra roles

## Lab Setup
- SONiC NOS virtual switch
- VLAN 100, LACP bond0 mode 802.3ad, MLAG concepts
- Jumbo frames MTU 9000
- RoCE v2 lossless: PFC + ECN enabled

## Validation Commands
ethtool -S eth0 | grep crc
iperf3 -c 10.0.0.1 -t 30 -P 4
ping -M do -s 8972 10.0.0.1
tcpdump -i eth0 port 4791
ibstat
ib_write_bw

## Scripts
- vlan_config.sh
- network_audit.py

## Tools
Spectrum, ConnectX, SONiC, Cumulus, RDMA, RoCE v2, GPUDirect, Wireshark
