---
title: MEV Networking Topolog Risks
description: Networking Threats offchain to network cohesion
status: draft, active
version: 0.5.0
---

# Virtual Mempool Networking Risk Assesments

> Known Risks and Attack Vectors (not exhaustive)

## Networking/Topology Vulnerabilities

### Uncapped incoming connections

Uncapped incoming connections: This vulnerability-
ity was in the Geth client prior to its version 1.8 Each
node can have a total number of maxpeers (with a default
value 25) connections at any point in time, and can initiate
up to ⌊(1+maxpeers)∕2⌋ outgoing TCP connections with the
other nodes. However, there was no upper limit on the number
of incoming TCP connections initiated by the other nodes.
This gives the attacker an opportunity to eclipse a victim
by establishing an maxpeers many of incoming connections
to a victim node, which has no outgoing connections. This
vulnerability has been eliminated in Geth v1.8 by enforcing
an upper limit on the number of incoming TCP connections
to a node, with a default value ⌊maxpeers∕3⌋ = 8.

### Public peer selection

Public peer selection (36): This vulnerability was detected in
Geth client prior to its version 1.8 . Recall that
the Ethereum P2P network uses a modiﬁed Kademlia DHT
for node discovery and that each node maintains a routing
table of 256 buckets for storing information about the other
nodes. The buckets are arranged based on the XOR distance
between a node’s ID and its neighboring node’s ID [98]. When
a node, say 퐴, needs to locate a target node, 퐴 queries the
16 nodes in its bucket that are relatively close to the target
node and asks each of these 16 nodes, say 퐵, to return the 16
IDs of 퐵’s neighbors that are closer to the target node. The
process iterates until the target node is identiﬁed. However,
the mapping from node IDs to buckets in the routing table is
public, meaning that the attacker can freely craft node IDs that
can land in a victim node’s buckets and insert malicious node
IDs into the victim node’s routing table .

## Remediation

- Conﬁguring the listening port rather than using the default one.
- Adding access control to ﬁlter remote RPC calls.
