#  Operational Risks from Miner and Network layer perspectives 


Estimating cost of a transaction (challenge)

By cost of transactions for the end user we normally understand the gas cost of
those transactions multiplied by the current cost of gas. Users may often
overpay for gas because they cannot reliably predict which gas price level will
ensure the inclusion of their transactions with required urgency.
Assessing safety of transactions (challenge)

Often users need to weight risk of exploit against the benefit they hope to get
from the transaction. Initial design of Ethereum did not put a lot of empphasys
on making that risk assessment easier.
Node operators (agent)

Cost of operating a full node is rising. Below are the main cost categories.

Long time to sync a new node (challenge)
Cost of storage devices (challenge)

All main-net capable implementations require at least SSD to maintable
acceptable operating speed, and NVMe is desirable for a initial sync
(downloading all the blocks and reconstituting the current state of the
blockchain).
High internet traffic (challenge)

After initial sync, traffic usage should not be very high. However, if many new
nodes joining the network, the outgoing traffic of the incument nodes may
increase, to serve blocks and initial state to the new-joiners.
Complex operations to run nodes (challenge)

Ethereum nodes transmit, process, and store large amounts of data. They also
often have very little tolerance to downtime. These two characteristics mean
that management of Ethereum nodes can be non-trivial.

Limited transaction throughput (challenge)

Some use cases of smart contracts and currency require certain level of
scalability, which usually translates to how quickly a transaction gets
“confirmed” related to how high gas price is paid. If scalability of the system
is not enough, some more complex constructions (e.g. Level 2 solutions like
state channels and Plasma) might need to be employed, at the cost of increased
complexity.
Assessing safety of transactions (challenge)

This challenges is shared with the end users.
Whenever users’ interaction with the Ethereum system are less trivial than
currency transfer, some security analysis is usually performed, to demonstrate
to the potential users of smart contracts that most likely their transactions
will not have unintended consequences. So far the tradition is that the
additional cost of performing security audits of the code, or formal
verification, or other security measures is paid by the dapp developers.
