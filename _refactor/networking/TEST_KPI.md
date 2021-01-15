---
title: Virtual Network Testing
description:
status:
version:
---

# Virtual Network Testing

> General Spec

### Testing Procedures

#### Network Tests

1.  Build new network according to specified topology
2.  Create addresses
3.  Import existing (mainnet) state
4.  Apply network conditions (if applicable)
5.  Send transactions from specified number of nodes
6.  Log time transaction sent from Tx node
7.  Log transaction and block data
8.  Timeout 10 seconds.
9.  Make sure all data is saved to DB in proper format.
10. Backup data locally
11. Tear down network
12. Parse data after each test

#### Transaction BBroadcast Propagation Time Test

1.  Build new network according to specified topology
2.  Create addresses
3.  Import existing (mainnet) state
4.  Apply network conditions (if applicable)
5.  Send transactions from specified number of nodes
6.  Add an additional node to the network
7.  Measure the time it takes for the newly added node to sync with the built out network

#### Test Metrics

- The baseline test will be run using the latest version of mev-geth / parity with it’s original call data size set to 32KB
- Each test series focuses on a specific variable
- Each test case within a test series contains a range of values for the variable of focus within that series
- Each test case will be run a total of 3 times
- Each test will be run until 500 blocks are collected
- Final data points will also be presented as an average of these three trials
- Metrics to be collected on network performance tests:

  - Tx ID
  - Tx size
  - Sender address
  - Receiving address
  - Send time
  - Rcv time
  - Block number
  - Block hash
  - Block Info
  - Block size
  - Mempool size
  - Block transmission time (Difference of send and receive time)
  - Block header validation time
  - Block processing time
  - Total delay
  - Uncle Rate

#### Series: Network Latency

| Vars | Topology             | Case A | Case B | Case C |
| ---- | -------------------- | ------ | ------ | ------ |
| X    | Network Latency (ms) | 50     | 100    | 150    |
|      | Packet Loss (%)      | 0      | 0      | 0      |
|      | Bandwidth (MB)       | 1000   | 1000   | 1000   |
|      | Total Clients        | 30     | 30     | 30     |
|      | Sender Accounts      | 15     | 15     | 15     |
|      | Tx Call Data (KB)    | 120    | 120    | 120    |
|      | Tx per Client (tx/s) | 200    | 200    | 200    |

### Performance Metrics

- Block Size: Measure the average block size; plot the block size over time.
- Block Time: Measure the average block time; plot the blocktime over time.
- Transaction Throughput: Measure the average throughput of transactions; plot the throughput over time.
- Tx Queue Size: Measure the unprocessed transaction queue size; plot the tx queue size over time.
- Mempool Size: Measure the size of the mempool; plot the mempool size over time.
- Block Transmission Time: Measure the time it takes for a block to be transmitted; plot the block time vs call data size.
- Block Header Validation Time: Measure the time a node takes to validate a block header; plot the validation time vs call data size.
- Block Processing Time: Measure the time it takes for a node to process a block; plot the block process time vs call data size.
- Uncle Rate: Measure the number of uncles are produced by each miner in the network; plot the number of uncles vs call data size.
- Total Delay: Measure the total delay observed; plot the total delay vs call data size.
- Memory Usage: Measure the average RAM usage; plot the RAM usage over time.

<!- Sourced from Whiteblock -->
