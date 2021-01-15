# Leaf sync

This is a description of the fast leaf sync protocol Péter Szilágyi (@karalabe) proposed, written down by Martin Holst Swende (@holiman).

As such, blame @holiman for errors and omissions!

The term `server` is used for the peer(s) that provide sync data, and `client` for the peer requesting data.

## Background

Existing sync protocols are very suboptimal.

### ETH-63 Fast-sync

The existing fast-sync protocol fetches state entries on a one-by-one basis (but batches the requests). For a given trie, it will fetch not only the actual leaf values, but all intermediate trie nodes.

#### Drawbacks

- Number of requests, and thus network roundtrips, are O(N) with the number of state entries.
  - These are batched: geth requests a maximum of `384` data items per request
- Although batching nodes them makes it more efficient from RTT perspective, since each item needs to be addressed individually, it means that there is `32 byte` (client) output for every node received.
  - See [these notes by Brian Coultier](https://notes.ethereum.org/XFiTkWMoRHOQ7DBxWno8yw#), where `284M` nodes at `32 bytes` each means `8.5GB` uploads (the complete fast-sync doing `31GB` of uploads).
- Number of entries is somewhere on the order of `O(N log N)`, with `N` being the number of actual leaf values, since a more dense trie will have more intermediate nodes.

#### Good things

The fast-sync protocol also has some good properties:

- It can 'heal' an invalid / incomplete trie,
- It can cryptographically verify each response, and discriminate between 'good' data and junk.

### Parity warp sync

Parity warp-sync is roughly this idea:

- At certain discrete points in time,
  - Bundle all leafs (values) into a large piece of data.
- Send the bundle to anyone who requests it

#### Drawbacks

- The `server` needs to be able to build the warp-sync data structure before the next period begins.
  - This is non-trivial, since it requires halting the block processing while performing iteration over the entire trie,
- The `client` needs to download the entire chunk of N gigabytes before it can actually verify that the downloaded data is correct.

#### Good things

- The data transmission is very optimal, transmitting only the actual leafs and proofs, but not intermediate nodes.

## Hybrid leaf sync

Péter's hybrid leaf sync attempts to combine the best things about fast-sync and warp-sync.

### Description

1. `server` maintains all trie leafs in a sorted structure,
2. `client` can request an arbitrary `chunk` from that sorted structure, e.g `trie nodes starting at 0xaaa...`

- A `chunk` contains a number of accounts, _with_ storage tries included, much like the parity warp-sync data structure

4. when `client` receives a `chunk`, it puts it into the trie.
5. At some point in time, the `client` will have received most parts of the `trie`. The trie will be maybe `90%` correct
6. Self-heal the trie using `eth63` fast-sync protocol

TLDR;

> In a few words; it send chunks of the state á la warp sync, and then uses fast-sync to fill in the blanks/invalids that are caused by the state as a whole not being accurate as of the last block once the whole state has been downloaded.
>
> So imagine it’s like warp-syncing 90% of the state and filling in the last 10% with fast-sync

At a first glance, it seems like this has the same `server`-overhead as warp-sync -- however, that is not the case.

1. The `server` can maintain a paralell account database, where accounts are stored in an _eventually consistent_ non-cryptographically secure database.

- This data structure does not have to take reorgs into account, so does not have to halt block processing during update!

Example:

1. An transaction `T` sends `1 wei` from account`A (nonce 9, balance 11)` to `B (balance 5)` .

- `db[a].balance = 10`, `db[a].nonce = 10`, `db[b].balance = 6`

2. A reorg happens, and `T` is removed.

- db does not change, and keeps the (now corrupt) balances/nonce for `A` and `B`.
- (All new txs from the new block are applied to database)

3. At some point in the future, `A` may send another transaction `T2`, which will trigger an update of `db[a]` with the new and correct values.

- A reorg may make the data in `db` corrupt, but it will eventually be healed again.
- The `db` is not a consensus struct, and we do not read from it (possible exception: see secondary benefit below)

### Important points

- `server` responses are cache-able. Since iterating the trie is extremely expensive, we want to reuse responses between `client`s. This means that clients must adhere to a schema for batch requests which allow this.
  - The `db` -- 'almost correct' data structure used for accounts and does not suffer from this, but storage tries are still iterated.
- At any point in time, the `server` can deliver (an arbitrary subset) from the database, without pausing for processing.
- A `client` can request chunks from multiple peers, and does not rely on a particular `server` for the entire state
- A malicious `server` can provide junk data; however if `N` servers are used , it puts a limit on the amount of junk that a given malicious server can provide.
- After completing the sync, the client can prune junk data from the trie.

This allows for on-the-fly chunk generation, as opposed to generating the whole snapshot in a consistent way as warp-sync requires (which is also the main bottleneck for it)

There is also a secondary benefit: the `db` layer exhibits the properties of a bloom filter: if an account exists there, it _might_ be part of the trie. If it does not, it does not exist in the trie. That could provide an additional boost to the `evm` by shortcutting certain operations (checking possible existence before diving into the trie)

### Problems

- Some account tries are extremely large. It's unclear how to best handle those, since they do not necessarily fit within a `chunk`.
  - A naive way to handle it is to only include the account trie hash there, and fill the data using fast-sync. However, that means that quite a lot of data will be left to the inefficient fast-sync protocol.

### Status

A proof-of-concept implementation has been done on Geth, availalbe here: https://github.com/karalabe/go-ethereum/tree/state-leaf-sync

Comments from @karalabe about the proof-of-concept:

> For storage tries I use iteration, and if the total size is < `10KB` (random magical number) I save it into disk, then if someone else needs the same data, I just regurgitate
>
> And this is why I haven't published my code yet, because this fails for crypto kitties where the state is insane
