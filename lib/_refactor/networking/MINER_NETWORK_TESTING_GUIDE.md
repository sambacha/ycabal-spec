---
title: Virualized Mempool Benchmarking
description: Simulation and Performance testing Specification
status: draft, active
contact: sam@freighttrust.com
---

# Miner Integration Document

## Overview

Benchmarking overlay and peering / clustering

### Linux Base System Configuration

#### TCP / Network

To find out what congestion control is available
\$ sysctl net.ipv4.tcp_available_congestion_control

> Netcat

<!-- TODO SECTION -->

```bash
mkfifo proxypipe
cat proxypipe | nc -l -p 8565 | tee -a inflow | nc localhost 8564 | tee -a outflow 1>proxypipe
```

### Benchmarks

The amount of time taken by any processor or task can be termed as
performance, which does not mean clock frequency alone or the number of
instructions executed per clock cycle, but is the combination of clock frequency
and instructions per clock cycle:

`P = I * F`
where, `P = performance`, `I = instructions executed per clock cycle` and
`F= frequency`

## USE, Utilization, Saturation, and Errors.

link:http://www.brendangregg.com/usemethod.html[source, brendan gregg, Netflix]

The USE Method can be summarized as:

For every resource, check utilization, saturation, and errors.
It's intended to be used early in a performance investigation, to identify
systemic bottlenecks.

### Terminology

- resource: all physical server functional components (CPUs, disks, busses, ...)
  [1]
- utilization: the average time that the resource was busy servicing work [2]
- saturation: the degree to which the resource has extra work which it can't
  service, often queued
- errors: the count of error events

The metrics are usually expressed in the following terms:

- utilization: as a percent over a time interval. eg, "one disk is running at
  90% utilization".
- saturation: as a queue length. eg, "the CPUs have an average run queue length
  of four".
- errors: scalar counts. eg, "this network interface has had fifty late
  collisions".

### Resource List

- CPUs: sockets, cores, hardware threads (virtual CPUs) - utilization, saturation
- Memory: capacity - utilization, saturation
- Network interfaces - utilization
- Storage devices: I/O, capacity - utilization, saturation, errors
- Controllers: storage, network cards
- Interconnects: CPUs, memory, I/O
- JVM

### Network Latency Performance

To get maximal throughput it is critical to use optimal TCP send and receive
socket buffer sizes for the link you are using. If the buffers are too small,
the TCP congestion window will never fully open up. If the receiver buffers are
too large, TCP flow control breaks and the sender can overrun the receiver,
which will cause the TCP window to shut down. This is likely to happen if the
sending host is faster than the receiving host.

- The optimal buffer size is twice the bandwidth\*delay product of the link:

`buffer size = 2 * bandwidth * delay`

For example, if your ping time is 50 ms, and the end-to-end network consists of
all 1G or 10G Ethernet, the TCP buffers should be:

`.05 sec * (1 Gbit / 8 bits) = 6.25 MBytes.`

[NOTE]
AWS Has an MTU max size of 1500 [AWS MTU
buffer](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/network_mtu.html)

[AWS Latency Map](https://docs.aviatrix.com/HowTos/inter_region_latency.html)

https://docs.aviatrix.com/HowTos/inter_region_latency.html

#### I/O

4,096 bytes = 4.096 kb

As you fill the SSD-based instance store volumes for your instance, the number
of write IOPS that you can achieve decreases. This is due to the extra work the
SSD controller must do to find available space, rewrite existing data, and erase
unused space so that it can be rewritten. This process of garbage collection
results in internal write amplification to the SSD, expressed as the ratio of
SSD write operations to user write operations. This decrease in performance is
even larger if the write operations are not in multiples of 4,096 bytes or not
aligned to a 4,096-byte boundary. If you write a smaller amount of bytes or
bytes that are not aligned, the SSD controller must read the surrounding data
and store the result in a new location. This pattern results in significantly
increased write amplification, increased latency, and dramatically reduced I/O
performance.

link:https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/general-purpose-instances.html#general-purpose-network-performance[source,
aws.]

## Network Upgrade and Testing for v2

This is in part based off of Whiteblock's Benchmarking utilities and
documentation

### Network Tests:

#### Series 1: Control

| Vars | Topology              | Case A | Case B | Case C |
| ---- | --------------------- | ------ | ------ | ------ |
|      | Network Latency (ms)  | 0      | 0      | 0      |
|      | Packet Loss (%)       | 0      | 0      | 0      |
|      | Bandwidth (MB)        | 1000   | 1000   | 1000   |
|      | Validators Per Client | 8      | 8      | 8      |
|      | Nodes per Client      | 1      | 1      | 1      |

#### Series 2: Network Latency

| Vars | Topology              | Case A | Case B | Case C |
| ---- | --------------------- | ------ | ------ | ------ |
| X    | Network Latency (ms)  | 50     | 100    | 150    |
|      | Packet Loss (%)       | 0      | 0      | 0      |
|      | Bandwidth (MB)        | 1000   | 1000   | 1000   |
|      | Validators Per Client | 8      | 8      | 8      |
|      | Nodes per Client      | 1      | 1      | 1      |

#### Series 3: Packet Loss

| Vars | Topology              | Case A | Case B | Case C |
| ---- | --------------------- | ------ | ------ | ------ |
|      | Network Latency (ms)  | 0      | 0      | 0      |
| X    | Packet Loss (%)       | 0.01   | 0.1    | 1      |
|      | Bandwidth (MB)        | 1000   | 1000   | 1000   |
|      | Validators Per Client | 8      | 8      | 8      |
|      | Nodes per Client      | 1      | 1      | 1      |

#### Series 4: Bandwidth

| Vars | Topology              | Case A | Case B | Case C |
| ---- | --------------------- | ------ | ------ | ------ |
|      | Network Latency (ms)  | 0      | 0      | 0      |
|      | Packet Loss (%)       | 0      | 0      | 0      |
| X    | Bandwidth (MB)        | 10     | 50     | 100    |
|      | Validators Per Client | 8      | 8      | 8      |
|      | Nodes per Client      | 1      | 1      | 1      |

#### Series 5: Increase Network Latency

| Vars | Topology              | Case A | Case B | Case C |
| ---- | --------------------- | ------ | ------ | ------ |
| X    | Network Latency (ms)  | 200    | 300    | 400    |
|      | Packet Loss (%)       | 0      | 0      | 0      |
|      | Bandwidth (MB)        | 1000   | 1000   | 1000   |
|      | Validators Per Client | 8      | 8      | 8      |
|      | Nodes per Client      | 1      | 1      | 1      |

#### Series 6: Stress Test

| Vars | Topology              | Case A | Case B | Case C |
| ---- | --------------------- | ------ | ------ | ------ |
| X    | Network Latency (ms)  | 150    | 300    | 500    |
| X    | Packet Loss (%)       | 0.01   | 0.1    | 1      |
| X    | Bandwidth (MB)        | 10     | 10     | 10     |
| X    | Validators Per Client | 8      | 16     | 32     |
|      | Nodes per Client      | 1      | 1      | 1      |

### Configuration Tests

#### Series 7: Validator Count

| Vars | Topology              | Case A | Case B | Case C |
| ---- | --------------------- | ------ | ------ | ------ |
|      | Network Latency (ms)  | 0      | 0      | 0      |
|      | Packet Loss (%)       | 0      | 0      | 0      |
|      | Bandwidth (MB)        | 1000   | 1000   | 1000   |
| X    | Validators Per Client | 16     | 32     | 64     |
|      | Nodes per Client      | 1      | 1      | 1      |

#### Series 8: Node Count

| Vars | Topology              | Case A | Case B | Case C |
| ---- | --------------------- | ------ | ------ | ------ |
|      | Network Latency (ms)  | 0      | 0      | 0      |
|      | Packet Loss (%)       | 0      | 0      | 0      |
|      | Bandwidth (MB)        | 1000   | 1000   | 1000   |
|      | Validators Per Client | 8      | 8      | 8      |
| X    | Nodes per Client      | 1      | 4      | 8      |

### **These test series will be run again with different peering topologies**

The peering will be done in the following manners:

1. All [1]
2. Serialized [2]
3. Paired [3]
4. Tree [4]

All peering will be done statically with a predetermined peer set. Each custom
static peers file will be copied over to each client.

The script will need to setup the client sufficiently and start the network. The
following arguments will need to be passed into the bash script

1. Identity - hex representation of the private key for libp2p
2. Peer - a multiaddr of a peer, repeats
3. validatorKeys - path to /launch/keys.yaml, in all likelihood
4. genesisState - path to /launch/state.ssz, in all likelihood
5. port

The start script will then continue on to perform the following steps:

1. Start Stratum Network Overlay
2. Start tracing utils and logging in backgound
3. Start simulation of load

# Appendix:

General Peering
Peering will have all nodes in the network peered with one
another. This will mean that there are:

(n^2-1)/n

number of links in the network

Serialized Peering
Serialized: This peering will have one node peered with another node. This
will be repeated and every peer will have one peer in its static peers file.
This will simulate the overlapping peer in each cluster and will essentially be
the number of hops a message has to make in order to reach its destination.
A -> B -> C -> D -> E -> F -> A

Paired Peering
Paired: This peering will have two nodes peered with another two nodes. This
will be repeated and every peer will have 2 peers in its static peers file.
[A,B] -> [C,D] -> [E,F] -> [A,B]

Tree Peering
Tree: This peering will have the first node have no nodes, then the second
node will be connected to the first node. The subsequent nodes will connect to a
previously built node. The peering structure will most resemble a tree-like
structure.

ex.1

```
      A
    /   \
   B     C
 /   \
D     E
```

ex.2

```
      A
    /   \
   B     E
 /   \
C     D
```

ex.3

```
      A
    / | \
   B  C  D
 /
E
```

- etc.
