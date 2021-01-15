# Firehose Sync v0.1

:::warning
This is an old proposal. See [Firehose Sync v0.2 here](https://notes.ethereum.org/0v_W4E8lROazqYymPAF7Ew)
:::

This syncing proposal builds on the "leaf sync" and "hybrid-warp" concepts. It combines the key benefits of the different approaches.

- Leaf Sync:
    - Fast on-the-fly leaf generation, because it does not require verifiable repsonses
- Hybrid Warp:
    - Incremental validation of leaf data
- Benefits in all:
    - Opportunities to increase the throughput by changing disk layout
    - Reduced bandwidth & request count
    - Pivots faster than Fast Sync

New benefits in Firehose:
- Dynamic adjustment to trie size
- Robust to trie imbalance

Firehose Sync potentially comes at the cost of:
- Slightly more bandwidth than leaf sync, for some of the inclusion proof data.
- Maintaining the top layers of the trie in storage/memory, for a number of recent blocks. (may be difficult in TurboGeth)
- More costly to generate/cache snapshots than leaf sync. [See the "Hasty Sync" for an option to mitigate](#Hasty-Firehose-Sync)

## Background on Inspired Approaches

### Leaf Sync (aka Fast-Warp)
:::info
See [Martin's writeup](https://notes.ethereum.org/kphcc_CKT4a5sUs_zWVelA) for a full picture
:::

Some prototypes:
- geth: https://github.com/karalabe/go-ethereum/tree/state-leaf-sync
- parity: https://github.com/paritytech/parity-ethereum/tree/ng-fast-warp

Fredrik's summary:
> In a few words; it send chunks of the state á la warp sync, and then uses fast-sync to fill in the blanks/invalids that are caused by the state as a whole not being accurate as of the last block once the whole state has been downloaded
> So imagine it’s like warp-syncing 90% of the state and filling in the last 10% with fast-sync
> This allows for on-the-fly chunk generation, as opposed to generating the whole snapshot in a consistent way as warp-sync requires (which is also the main bottleneck for it)

If you're familiar with Leaf Sync, then Firehose Sync is similar, but:
- Does not inline storage, recurses into storage tries
- Chunk size can be determined/modified on the fly, per chunk

*Unknown at this time: How is the account trie chunk size determined? How about storage tries? How are the requests formatted? Can you batch requests/responses with multiple storage values?*

### Hybrid Sync

Alexey posted the Hybrid Sync proposal: https://github.com/ledgerwatch/eth_state/blob/master/sync/Hybrid_Sync.pdf

If you're familiar with Hybrid Sync, then Firehose Sync is similar, but:
- Does not pre-determine how the size of all key/value chunks
- Permits chunks to be subdivided on the fly, if any one gets too big

## How Firehose Sync works

### A casual example

One way to think about Firehose Sync is as a naive client requesting all the keys & values at once, and recursing down into the trie when that response would be too big. Something like:

1) **Request** Give me the addresses and RLPs of every account at state root `0xa1b2`...
2) **Response** Nope, that's too much. Here are some nodes: the root and each of its children.
3) **Req** Looks like those nodes match the root :+1:, how about accounts with address hashes starting with `0x00`, same root?
5) **Resp** Nope, still way too big. Here is the node at prefix `0x00`, and all its children
6) **Req** Ok, I can tell these are the right nodes, based on the hashes in #2. I really want some accounts, though, can I have all the accounts whose hashes start with prefix `0x0000`?
7) **Resp** No problem! Here are all the account RLPs whose hashes start with `0x0000`, and the last 30 bytes of the hash of their addresses
8) **Req** Hooray! I can validate all the accounts by building them into a subtrie and comparing it to a hash received in #4

Firehose Sync *enables* the strategy above, but does not lock you into it. Also, the requester is only requesting one "thing" at a time here, but can batch requests, as seen below.

Note that this whole protocol works exactly the same on storage tries.

### Request Command: `GetTrieData`

The requester asks for data defined by a given root hash and key prefix. The root hash might be a root of the state trie or an account's storage trie.

The requests can be batched so that multiple prefixes and multiple root hashes may be requested.

```
{
    # A request id is supplied, to match against the response
    "id": int,
    
    # Requests are batched in a list under the single key: prefixes
    "prefixes": [
    
        # Each list item is a two-element tuple
        (
            # The first element is the root hash being requested
            root_hash,
        
            # The second element is a list of prefixes being requested
            [key_prefix, ...]
        ),
        ...
    ]
}
```

#### Key Prefixes

A naive encoding of key prefixes would be ambiguous between an even-length prefix starting with the `0x0` nibble and an odd-length prefix that gets left-padded with `0x0` to the next full byte.

So an `0x1` nibble is added to the beginning of each odd-length key prefix to disambiguate. An `0x00` byte is added to the beginning of each even-length key prefix. The prefix can be empty, in which case no nibble is added.

Some valid prefixes encodings:

- `0x` -- The empty (null) prefix means a request for all values in the trie
- `0x10` -- The odd prefix `0x0`
- `0x1F` -- The odd prefix `0xF`
- `0x0000` -- The even prefix `0x00`
- `0x00FF` -- The even prefix `0xFF`
- `0x1000` -- The odd prefix `0x000`
- `0x1FFF` -- The odd prefix `0xFFF`

Some invalid prefix encodings:
- `0x01` -- Must start with `0x00` or `0x1`
- `0xF0` -- Also not marked as odd or even

*This encoding works, but feels naive. Is there anything better out there?*


#### Example
Say you want the accounts that (after hashing) have the prefixes `0xbeef` and `0x0ddba11`, at state root 0xaaa...aaa. Additionally, you want all the values in the storage trie with root 0xbbb...bbb. Your request would look like:
```
{
    "id": 1,
    
    "prefixes": [
        (
            # state root hash
            0xaaa...aaa,
            
            # even-length 0xbeef and odd-length 0x0ddba11, encoded
            [0x00beef, 0x10ddba11]
        ),
        (
            # storage root hash
            0xbbb...bbb,
            
            # ask for all values by requesting the empty prefix
            [0x]
        )
    ]
}
```


### Response Command: `TrieData`


The responder has the option of returning either:
1) Some nodes in the subtrie starting at the requested prefix (with some flexibility on which nodes to return), OR
2) The keys & values that are stored in that key prefix range



```
{
    # The ID to be used by the requestor to match the response
    "id": int,
    
    # The response data, in the same ordering of the request
    "data": [

        # there is one element in this outer list for each state root requested
        [
        
            # There is one 2-tuple for every prefix requested
            (
            
                # The responder may choose to reply with a list of trie nodes
                [node, ...],
                
                # OR, the responder may reply with the keys & values
                [
                    # A single key/value pair
                    (
                        # The prefix is omitted from the key
                        key_suffix,
                        
                        # The RLP-encoded value stored in the trie
                        value
                    ),
                    ...
                ]
            ),
            ...
        ],
        ...
    ]
}
```
The response must reuse the same ordering of root hashes and prefixes as used for the request. For each prefix, the responder chooses to send exactly one of: node data, or key/value data, or neither.

If the suffix is odd-length (in nibbles), then left-pad with 0's to the nearest full byte. That means that a suffix length-4 of `0x0987` and suffix length-3 `0x987` are sent as the same bytes in a response. It's up to the requestor to recall the prefix length, so they can infer the suffix length.

#### Node Data Response Constraints

Some constraints on the node data response:
1) Response **must not** return any child nodes without also returning their parents. For example, if exactly one node is returned to a request for the empty prefix, it must be the root node.
2) Response **must** return parent nodes before any child nodes. Child nodes may be in any order.

#### Example
A response to the example request above might look like:


```
{
    "id": 1,
    
    # This is a list of two elements, matching the `prefixes` request example
    "data": [
    
        # All values in this first list correspond to
        # state root hash: 0xaaa...aaa
        [
            # This 2-tuple is for the 0xbeef prefix
            (
                # Node data is not empty: the prefix was too short
                [0xabc..., 0xdef...],
                
                # The second element must be empty if the first is not
                []
            ),
            
            # This 2-tuple is for the 0x0ddba11 prefix
            (
                # Node data is empty: the prefix was long enough to get values
                [],
                
                # This is the list of the key suffixes and values under 0x0ddba11
                [
                    # This is a single key suffix and value pair
                    (0x09876..., 0x111...),
                    
                    # Here, all keys start with 0x0, because they are odd-length
                    
                    # Each key suffix must be 57 nibbles long, which
                    # rounds out to 29 bytes
                    (0x0a1b..., 0x1a2...),
                ]),
        ],
        
        # All values in this second list correspond to
        # storage root hash: 0xbbb...bbb
        [
            # The first (only) element in this list is for the empty prefix
            
            # The responder returned nothing, perhaps it hit an internal timeout
            # An empty tuple is a valid response, as is ([], [])
            (),
        ]
    ]
}
```




### Request Strategies

Nothing about this protocol requires or prevents the following strategies, which clients might choose to adopt:

#### Fast-Distrustful Strategy
In the strategy, a requester starts requesting from the root, like the "casual example" above. It requests the values at `0x00` and so on. However, the chain changes over time, and at some point the connected nodes may no longer have the trie data available.

At this point, the requestor needs to "pivot" to a new state root. So the requestor requests the empty prefix at the new state root. However, instead of asking for the `0x00` values *again*, the requestor skips to a prefix that was not retrieved in an earlier trie.

The requestor considers this "stage" of sync complete when keys/values from all prefixes are downloaded, even if they come from different state roots. The follow-up stage is to use "traditional" fast sync to fix up the gaps.

#### Anti-Fast Strategy
A requestor client might choose not to implement fast sync, so they look for an alternative strategy. In this case, every time a pivot is required, the client would have to re-request from the empty prefix. For any key prefix that has not changed since the previous pivot, the client can still skip that whole subtree. Depending on how large the buckets are and how fast state is changing, the client may end up receiving many duplicate keys and values, repeatedly. It will probably involve more requests and more bandwidth consumed, than any other strategy.

#### Fast-Optimistic Strategy
A requestor can choose to ask for prefixes without having the proof from the trie. In this strategy, the nodes aren't any use, so the client would aim to choose a prefix that is long enough to get keys/values. This strategy appears very similar to fast-warp, because you can't verify the chunks along the way. It still has the added bonus of adapting to changing trie size and imbalance. If the requestor picks a prefix that is too short, the responder will reply in a way that indicates that the requester should pick a longer prefix.

#### Fast-Earned-Trust Strategy

This is a combination of Distrustful and Optimistic strategies.

A requester might start up new peers, using the Fast-Distrustful Strategy. After a peer has built up some reputation with valid responses, the requestor could decide to switch them to the Fast-Optimistic strategy. If using multiple peers to sync, a neat side-effect is that the responding peer cannot determine whether or not you have the proof yet, so it's harder for a griefer to grief you opportunistically.

#### Just-in-Time (JIT) Strategy

Instead of trying to sync the whole state immediately, starting with arbitrary parts, download state guided by the recent headers. In short: pick a very recent header, download transactions, and start running them. Every time the EVM attempts to read state that is not present, pause execution and request the needed state. After running all the transactions in the block, select the canonical child header, and repeat.

Some benefits of this strategy:
- Very short ramp-up time to running transactions locally
- Encourages cache alignment:
    - Multiple requestors make similar requests, encouraging cache hits
    - Responders can predict inbound requests
    - Not only are specific accounts more likely to be requested; those accounts are requested at particular state roots

It's entirely possible that it will take longer than the block time to execute a single block when you have a lot of read "misses." As you build more and more local data, you should eventually catch up.

What happens if the amount of state read in a single block is so big that you can't sync state before clients prune the data? You can choose a new recent header and try again. Though, it's possible that you would keep resetting this way indefinitely. Perhaps after a few resets, you could fall back to a different strategy.

### Response Strategies

<!-- 

#### Sending breadth-first nodes
It should be easier for the responder and more helpful for the requester to get a breadth of nodes, so that they don't waste time on nodes that are too deep. In other words, better to send this:

```
               *

* * * * * * * * * * * * * * * *
```

Than to send this:

```
         *
        /
       *
      /
     *
    /
   *
  /
 *
```

The protocol theoretically allows you to send the latter, but it doesn't seem to be beneficial to anyone.
 -->

#### Node Response: Request Shaping

The responder has more information than the requestor. The responder can communicate the next suggested request by adding (or withholding!) some nodes when responding to a request.

Let's look at an example trie that is imbalanced (binary trie for simplicity): the right-half of a trie is light, but there are a lot of values prefixed with `0b01`.

A request comes in for the empty prefix. A responder who is responding to an empty prefix request can shape the returned nodes to communicate the imbalance.

The responder responds with this scraggly tree:

```
    * (root)
 0 /
  *   
   \ 1
    *

```

The responder has just implied that the requestor's next requests ought to be:

- `0b1`
- `0b00`
- `0b010`
- `0b011`

This strategy isn't only valuable for imbalanced tries. In a well balanced trie, it's still useful to communicate an ideal depth for prefixes with this method. The ideal prefix depth is especially difficult for a requestor to predict in a storage trie, for example.

#### Value Response

There is only one straightforward strategy: return all the keys and values in the prefix. If you can't return exactly that, then don't return anything. See "Hasty Sync" for an alternative that may be faster, but at the cost of immediate response verifiability.

### Hasty Firehose Sync

This is a potentially surprising strategy that is not *explicitly* forbidden.

When responding with keys/values, the responder might choose to give results that are *nearly* valid, but would fail a cryptographic check. Perhaps the values are from one block later, or the responder is reading from a data store that is "mid-block" or "mid-transaction". This enables some caching strategies that leaf sync was designed for.

Naturally, this response strategy comes at the cost of verifiability. For the requestor to validate, they could fast sync against the subtree hash. This fast-verify process might find that 90% of the provided accounts were correct for the given root hash. Perhaps that is acceptable to the requestor, and they choose to keep the responder as a peer.

For performance, requestors wouldn't fast-verify every response. The requesting client can choose how often to validate and how much accuracy to require.

Of course any requesting clients that *don't* use this strategy would treat "Hasty Sync" peers as invalid and stop syncing from them.

This strategy is almost exactly like leaf sync. We don't have an exact spec for leaf sync at the moment, so the comparison is imprecise. The only obvious difference is that account storage is inlined during leaf sync. Firehose still treats storage as separate tries.

### Some Unexplored Variations

#### Denormalize the Commands

See [Peter's plea](https://ethereum-magicians.org/t/forming-a-ring-eth-v64-wire-protocol-ring/2857/10?u=carver) to denormalize the commands. In theory, deduplication by hash is nice, but in practice it appears to be limiting. Having a single global lookup of preimages limits architectural options. Especially in a pruning context, duplication of the values appears to be a better architecture.

That suggests that Firehose would increase the number of commands from two to six.

### Some Rejected Variations


#### Even-length prefixes

In this variant, odd-length prefixes are not allowed (sometimes saving a byte per requested prefix).

In this scenario, when the responder gives back node data instead of accounts, she would have to always return the node and *all* of its children. Otherwise there would be no way to recurse down into the next layer, because you can't ask for the odd-length prefixed accounts.

The potential value here depends on how meaningful that extra prefix nibble is during requests. Currently, the cost of *requiring* the responder to respond with no nodes or include all children is presumed to be too high.

Additionally, it is convenient for bucket sizes to be able to adjust up and down by 16x instead of 256x.

#### Returning leaf nodes instead of key/rlp pairs

In order to rebuild the structure of the trie, we need the full suffix of the key (everything beyond the requested prefix). The leaf node of the trie only includes the suffix of the key from the immediate parent node. Once you include the full suffix, re-including part of the suffix in the leaf node is a waste of bandwidth.
