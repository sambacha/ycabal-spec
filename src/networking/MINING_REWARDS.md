# Mining Rewards

## Ommers

Mining rewards and ommer rewards might need to be added. This is how those are applied:

block_reward is the block mining reward for the miner (0xaa), of a block at height N.
For each ommer (mined by 0xbb), with blocknumber N-delta
(where delta is the difference between the current block and the ommer)
The account 0xbb (ommer miner) is awarded (8-delta)/ 8 \* block_reward
The account 0xaa (block miner) is awarded block_reward / 32
To make state_t8n apply these, the following inputs are required:

### state.reward

For ethash, it is 5000000000000000000 wei,
If this is not defined, mining rewards are not applied,
A value of 0 is valid, and causes accounts to be 'touched'.
For each ommer, the tool needs to be given an address and a delta. This is done via the env.
Note: the tool does not verify that e.g. the normal uncle rules apply, and allows e.g two uncles at the same height, or the uncle-distance. This means that the tool allows for negative uncle reward (distance > 8)

Example: ./testdata/5/env.json:

```json
{
  "currentCoinbase": "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "currentDifficulty": "0x20000",
  "currentGasLimit": "0x750a163df65e8a",
  "currentNumber": "1",
  "currentTimestamp": "1000",
  "ommers": [
    { "delta": 1, "address": "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    { "delta": 2, "address": "0xcccccccccccccccccccccccccccccccccccccccc" }
  ]
}
```

When applying this, using a reward of 0x08 Output:

```json
{
  "alloc": {
    "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": {
      "balance": "0x88"
    },
    "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb": {
      "balance": "0x70"
    },
    "0xcccccccccccccccccccccccccccccccccccccccc": {
      "balance": "0x60"
    }
  }
}
```
