---
title: Calculating Network Security
version: active
---

# Calculating Network Security

Yonatan Sompolinsky and Aviv Zohar suggested in [1] an elegant model to relate network delay to network security, and this model is also used in the work of Rafael Pass, Lior Seeman and Abhi Shelat [2]. We briefly explain this model below, because we shall study it theoretically and validate it by empirical measurements to reach the suggested lower gas cost for Calldata.

The model uses the following natural parameters:

lambda denotes the block creation rate [1/s]: We treat the process of finding a PoW solution as a poisson process with rate lambda.
beta - chain growth rate [1/s]: the rate at which new blocks are added to the heaviest chain.
D - block delay [s]: The time that elapses between the mining of a new block and its acceptance by all the miners (all miners switched to mining on top of that block).

### Beta Lower Bound

Notice that lambda => beta, because not all blocks that are found will enter the main chain (as is the case with uncles). In [1] it was shown that for a blockchain using the longest chain rule, one may bound beta from below by lambda/ (1+ D \* lambda). This lower bound holds in the extremal case where the topology of the network is a clique in which the delay between each pair of nodes is D, the maximal possible delay. Recording both the lower and upper bounds on beta we get

```latex
_lambda_ >= _beta_ >= _lambda_ / (1 + D * _lambda_)               (*)
```

Notice, as a sanity check, that when there is no delay (D=0) then beta equals lambda, as expected.

### Security of the network

An attacker attempting to reorganize the main chain needs to generate blocks at a rate that is greater than beta. Fixing the difficulty level of the PoW puzzle, the total hash rate in the system is correlated to lambda. Thus, beta / lambda is defined as the the efficiency of the system, as it measures the fraction of total hash power that is used to generate the main chain of the network.

Rearranging (\*) gives the following lower bound on efficiency in terms of delay:

```latex
_beta_ / _lambda_ >= 1 / (1 + D * _lambda_)                 (**)
```

{footnotes}

Yonatan Sompolinsky, Aviv Zohar: Secure High-Rate Transaction Processing in Bitcoin. Financial Cryptography 2015: 507-527
https://eprint.iacr.org/2013/881.pdf

Rafael Pass, Lior Seeman, Abhi Shelat: Analysis of the Blockchain Protocol in Asynchronous Networks, ePrint report 2016/454
https://eprint.iacr.org/2016/454.pdf
