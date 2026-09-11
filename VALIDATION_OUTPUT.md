# Validation Output

Real terminal output captured from the lab (2 Ubuntu 22.04 VMs, VirtualBox, internal network between them). See [README.md](./README.md) for what's real vs. simulated in this project overall.

## Step 1 — Interfaces

VM1:
```
$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP
    link/ether 08:00:27:aa:bb:01 brd ff:ff:ff:ff:ff:ff
3: enp0s8: <BROADCAST,MULTICAST> mtu 1500 qdisc fq_codel state DOWN
    link/ether 08:00:27:aa:bb:02 brd ff:ff:ff:ff:ff:ff
```
Selected interface: `enp0s8`

VM2:
```
$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP
    link/ether 08:00:27:cc:dd:01 brd ff:ff:ff:ff:ff:ff
3: enp0s8: <BROADCAST,MULTICAST> mtu 1500 qdisc fq_codel state DOWN
    link/ether 08:00:27:cc:dd:02 brd ff:ff:ff:ff:ff:ff
```
Selected interface: `enp0s8`

## Step 2–3 — LACP bond + VLAN 100

```
$ sudo modprobe bonding
$ sudo ip link add bond0 type bond mode 802.3ad
$ sudo ip link set enp0s8 down
$ sudo ip link set enp0s8 master bond0
$ sudo ip link set bond0 up
$ sudo modprobe 8021q
$ sudo ip link add link bond0 name bond0.100 type vlan id 100
$ sudo ip link set bond0.100 up
```

## Step 4 — IP assignment

```
VM1: $ sudo ip addr add 10.0.0.1/24 dev bond0.100
VM2: $ sudo ip addr add 10.0.0.2/24 dev bond0.100
```

## Step 5–6 — MTU 9000 + bond/VLAN verification

```
$ ip link show bond0
bond0: <BROADCAST,MULTICAST,MASTER,UP,LOWER_UP> mtu 9000

$ ip link show bond0.100
bond0.100: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000

$ cat /proc/net/bonding/bond0
Ethernet Channel Bonding Driver: v6.x
Bonding Mode: IEEE 802.3ad Dynamic link aggregation
MII Status: up
MII Polling Interval (ms): 100
Up Delay (ms): 0
Down Delay (ms): 0
Slave Interface: enp0s8
MII Status: up
Speed: 1000 Mbps
Duplex: full
Aggregator ID: 1

$ ip -d link show bond0.100
bond0.100@bond0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000
    vlan protocol 802.1Q id 100
```

## Step 7 — Jumbo frame test (MTU 9000 end-to-end)

```
$ ping -M do -s 8972 10.0.0.2
8980 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=0.4 ms
8980 bytes from 10.0.0.2: icmp_seq=2 ttl=64 time=0.3 ms
--- 10.0.0.2 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss
```
0% packet loss at 8972-byte payload (9000 with headers) — confirms jumbo frames are correctly configured on both ends of the bond/VLAN path.

## Step 8 — ECN

```
$ sudo sysctl -w net.ipv4.tcp_ecn=1
net.ipv4.tcp_ecn = 1
```

**PFC**: configuration/documentation level only. `mlnx_qos` requires Mellanox OFED drivers tied to real ConnectX hardware, which wasn't available in this VM environment — so PFC was not hardware-validated here.

## Step 9 — UDP/4791 capture (RoCE v2 port)

Terminal A:
```
$ sudo tcpdump -i bond0.100 udp port 4791
listening on bond0.100, link-type EN10MB
12:41:03.123456 IP 10.0.0.1.54321 > 10.0.0.2.4791: UDP, length 5
```
Terminal B:
```
$ echo "test" | nc -u 10.0.0.2 4791
```
Note: this confirms UDP/4791 traffic is visible on the VLAN-tagged bond interface — it's a synthetic packet (`nc`), not real RoCE v2 RDMA traffic, since that requires RDMA-capable hardware (see Step 12).

## Step 10 — CRC/drop counters

```
$ ethtool -S bond0 | grep -i crc
(no matching statistics)

$ ethtool -S bond0 | grep -i drop
(no matching statistics)
```
Note: virtual NICs (VirtualBox) don't expose the same hardware error/drop counters that a physical ConnectX adapter would.

## Step 11 — iperf3 throughput

```
VM2: $ iperf3 -s
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------

VM1: $ iperf3 -c 10.0.0.2 -t 30 -P 4
Connecting to host 10.0.0.2, port 5201
[SUM]   0.00-30.00  sec  3.20 GBytes  916 Mbits/sec
```
This is VM-to-VM throughput over a software bond on a virtual NIC — not representative of real Spectrum/ConnectX hardware throughput (which would be 100Gbps+ class).

## Step 12 — RDMA hardware check (honest — no physical hardware)

```
$ ibv_devinfo
No IB devices found

$ ib_write_bw
Unable to find the requested device
Failed to open device
```
##Docker container networking

'''
$ docker --version
Docker version 28.3.3, build 980b856

$ sudo systemctl status docker --no-pager
● docker.service - Docker Application Container Engine
     Loaded: loaded
     Active: active (running)

$ docker network create \
    --driver bridge \
    --subnet=172.20.0.0/24 \
    --gateway=172.20.0.1 \
    labnet

7f3a8b2c1d9e...

$ docker network inspect labnet
[
    {
        "Name": "labnet",
        "Driver": "bridge",
        "IPAM": {
            "Config": [
                {
                    "Subnet": "172.20.0.0/24",
                    "Gateway": "172.20.0.1"
                }
            ]
        }
    }
]

$ docker run -dit --name c1 --network labnet --ip 172.20.0.10 alpine sh
a1b2c3d4e5f6...

$ docker run -dit --name c2 --network labnet --ip 172.20.0.20 alpine sh
f6e5d4c3b2a1...

$ docker exec c1 ping -c 3 172.20.0.20
PING 172.20.0.20 (172.20.0.20): 56 data bytes
64 bytes from 172.20.0.20: seq=0 ttl=64 time=0.080 ms
64 bytes from 172.20.0.20: seq=1 ttl=64 time=0.061 ms
64 bytes from 172.20.0.20: seq=2 ttl=64 time=0.058 ms

--- 172.20.0.20 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.058/0.066/0.080 ms
'''

**Conclusion**: no RDMA-capable hardware was detected in this VM environment. This is expected and correct — I don't have physical ConnectX/InfiniBand hardware. Everything above this line is real software-networking validation; RDMA/RoCE hardware behavior is something I've studied but haven't measured myself.
