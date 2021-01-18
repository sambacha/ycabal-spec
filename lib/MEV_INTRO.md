---
title: MEV Statistics Summary 
description: Reference file and snippets from whitepapers
---

# MEV Statistics and Landscape Summary



    source material and summary
    Quantifying Blockchain Extractable Value: How dark is the forest?
    https://arxiv.org/abs/2101.05511

> Profit, Exposure and the extent of penetration into the market

For fixed spread liquidations pro-tocols, such as Aave, Compound, and dYdX (66%
of the DeFi lendingmarket), we find that the past 16,031 liquidations yield an
accu-mulative profit of 20.18M USD over the entire existence of thoseprotocols
(19months). 28.80M USD over 2 years.

We find that 12.71% of these liquidationsback-run the price oracle
update transaction, while 87.29% attempt to front-run competing liquidators.

For arbitrage, we identify 789 smart contracts performing 51,415 trades, realizing a
total profitof 7.11M USD.

Expected Execution Price \(( E [P]):\) When a liquidity taker issues a trade on \(X / Y,\) the taker wishes to execute the trade with the expected execution price \(E [P]\) (based on the AMM algorithm and \(X / Y\) state) given the expected slippage.
Execution Price \((P):\) During the time difference between a liquidity taker issuing a transaction, and the transaction being executed (e.g. mined in a block), the state of the AMM market \(X / Y\) may change.
This state change may induce unexpected slippage resulting in an execution price \(P \neq E [P]\).
Unexpected Price Slippage \((P- E [P]):\) is the difference between \(P\) and \(E [P]\). Unexpected Slippage Rate \(\left(\frac{P- E [P]}{ E [P]}\right):\) is \(\quad\) the unexpected slippage over the expected price.
\begin{equation*} \delta\_{x} \end{equation*}

## DEX/AMM Parameters

### addLiquidity

AddLiquidity: A liquidity provider deposits
\begin{equation*} \delta\_{x} \end{equation*}
asset into the corresponding liquiditypools (cf. Equation 1).

\begin{equation*}
(x, y) \frac{\text { AddLiquidity }\left(\delta*{x}, \delta*{y}\right)}{\delta*{x} \in R ^{+}, \delta*{y} \in R ^{+}}\left(x+\delta*{x}, y+\delta*{y}\right)
\end{equation*}

### RemoveLiqujidity

RemoveLiquidity: A liquidity provider withdrawsδxofassetX, andδyof assetYfrom the correspondingliquidity pools (cf. Equation 2).

\begin{equation*}
(x, y) \frac{\text { RemoveLiquidity }\left(\delta*{x}, \delta*{y}\right)}{\delta*{x} \in R ^{+} \leq x, \delta*{y} \in R ^{+} \leq y}\left(x-\delta*{x}, y-\delta*{y}\right)
\end{equation*}

### TransferLiqudity

Definition 1.The state (or depth) of an AMM marketX/Yis defined as(x,y),x the amount of assetX,y the amount of assetY in the liquidity pool.
The state at a given blockchain blockN is denoted(xN,yN).AMM

DEXs support the following actions.

AddLiquidity: A liquidity provider deposits [δxof assetX], and δy of assetY into the corresponding liquidity pools.

(1)RemoveLiquidity:A liquidity provider withdrawsδxofassetX, andδyof assetYfrom the correspondingliquidity pools

TransactXforY: A liquidity taker can tradeδxof assetX, increasing the available liquidity of assetX, inexchange forδy=f(δx−cx(·))−cy(·) of assetY, decreasing the available liquidity of assetY(cf.Equation
3).cx(·),cy(·) represent the trade fees inassetXandYrespectively.f(·) calculates the amountof assetYpurchased by the liquidity taker. EachAMM exchange may chose a custom pricing functionf(·) for governing the asset exchange [1].
Note thatthe exchange asset pricing cannot be determined bya simple constant, as the market dynamics of pur-chasing and selling power must be modeled withinthe exchange (i.e. the more assets on would want topurchase, the higher the fees)

### TransactXforY

TransactXforY: A liquidity taker can tradeδxof assetX, increasing the available liquidity of assetX, in exchange  
\begin{equation*}
(x, y) \frac{\text { Transact } X \text { for } Y\left(\delta*{x}\right)}{\delta*{x} \in R ^{+}}\left(x+\delta*{x}, y-f\left(\delta*{x}-c*{x}(\cdot)\right)+c*{y}(\cdot)\right)
\end{equation*}

of assetY, decreasing the available liquidity of assetY(cf.Equation 3).cx(·),cy(·) represent the trade fees inassetXandYrespectively.f(·) calculates the amountof assetYpurchased by the liquidity taker. EachAMM exchange may chose a custom pricing functionf(·) for governing the asset exchange [1]. Note thatthe exchange asset pricing cannot be determined bya simple constant, as the market dynamics of pur-chasing and selling power must be modeled withinthe exchange (i.e. the more assets on would want topurchase, the higher the fees).

### Transaction Payload Size

> Equation
> \begin{equation*}
> \text { Propagation Duration }=\frac{\text { Transaction Size }}{\text { Bandwidth }}+\text { Latency }
> \end{equation*}
> Through crawling raw transactions sent to the Uniswap DAI marke tover 100,000 consecutive blocks,
> starting from block 9M. Emperical measurements suggest a mean transaction size of

    426.27±68.94  Bytes

| **Pct %** | **Latency** | **Latency** | \*\*\*\* | **Provisioned** | **Bandwidth** |
| --------- | ----------- | ----------- | -------- | --------------- | ------------- |
|           | [1]         | [2]         | Model    | [2]             |               |
| 10        | 99          | 92          | 95.5     | 3.4             | 3.4           |
| 20        | 116         | -           | 116      | -               | 6.8           |
| 33        | 151         | 125         | 138      | 11.2            | 11.2          |
| 50        | 208         | 152         | 180      | 29.4            | 29.4          |
| 67        | 231         | 200         | 216      | 68.3            | 68.3          |
| 80        | 247         | -           | 247      | -               | 111.3         |
| 90        | 285         | 276         | 281      | 144.4           | 144.4         |
| mean      | 209         | 171         | 181      | 55              | 52.8          |
| std.      | 157         | 76          | 62       | 58.8            | 50.4          |



https://etherscan.io/tx/0x07729d7826e2335a88ac1ae23aa9463a3183c6dc6e7a7ba485c244f473a9be87
7, the trader executes the arbitrage in the following order:
WETH→BOXT→UNI→USDT→USDN→UNI→WETH. This arbitrage strategy consistsof two
triangular arbitrages:(i)WETH→BOXT→UNI→WETH;(ii)UNI→USDT→USDN→UNI

https://etherscan.io/tx/0x2c79cdd1a16767e90d55a1598c833f77c609e972ea0fa7622b70a67646a681a5
the trader first swaps400ETH for1040COMP on Uniswap v2, thenswaps1040COMP
for476ETH on Sushiswap, realizing a revenue of76ETH

### Arbitrage: Mainly Backrunning

If a transaction is a blockstate arbitrage, then the execution should remain
profitable. We findthat60.08%arbitrage transactions are no longer profitable,
whichindicates that these transactions likely perform back-running.

### Percentage of transactions that are privately broadcast

From block 11503300 (Dec-22-2020 12:39:48 PM +UTC) to 11548969 (Dec-29-2020
12:39:58 PM +UTC),
the chain recorded 8,285,218 transactions. When comparing those with the
transactions we ob-served on the network layer, we find that 136,143 mined
transactionswere not broadcast prior to being mined.
We hence can concludethat1.64% of the transactions are being privately.

#### misc transcations

https://ethtx.info/mainnet/0xcc80ce9d4a8adf860e70d922f498492ee56752237587f9d8c93de26e3f0fcabb

Arbitrage
https://etherscan.io/tx/0x07729d7826e2335a88ac1ae23aa9463a3183c6dc6e7a7ba485c244f473a9be87

1inch:

- sparkpool Spark Pool (23.50%)
  https://etherscan.io/tx/0xa0263443c173d6d21bb1da0e931456cdbbc6ee4c0c090b689982ef33d44db15b

- Babel Pool (4.83%)
  https://etherscan.io/tx/0xaa45cc189f75d44ebb2d8cbf56ad763da49f2adef3d82147772ea91f2e3ec66f

- f2pool 9.59% hashrate
  https://etherscan.io/tx/0x4340470116020410e7e5bfe5e069f512432dddb323744bedcc2f799b8136aeb5

### SparkPools MEV Contract

https://etherscan.io/address/0x000000000025d4386f7fb58984cbe110aee3a4c4

### Additional

https://etherscan.io/tx/0x4e173c71d481a94169839a6a0e6b912c2631589db1a7a42596649a692f3a29cd
https://etherscan.io/tx/0xa67e709687dc64a543387f7219aadc0e7f29f207d838caf2d99fd69b4d684725
