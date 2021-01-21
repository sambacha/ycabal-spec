<!-- EXPERIMENTAL DESIGN DOCUMENT -->
### Message routing

●  Kafka

● logged messages in named context (LoggerName)
● configuration maps LoggerName to definition:
    ○ select backend
    ○ select scribe (katip backend)
    ○ local severity filter
    ○ subtrace behaviour

● backends:
    ○ LogBuffer (map LoggerName -> LogObject)
    ○ EKG view
    ○ Aggregation
    ○ Configuration editor
    ○ Log (katip / GreyLog2)



### Micro-benchmarking

● record operating system counters (before, after)
● relate to “bracketed” function (by LoggerName)
● observe monadic and STM actions; bracket returns action’s result

```bash
bracketObserveIO :: Configuration -> Trace IO a -> Severity -> LoggerName -> IO t -> IO t
bracketObserveIO :: Configuration -> Trace IO a -> Severity -> LoggerName -> STM t -> IO t
```

● local name: lookup set of counters to observe in configuration
● traced counters can be routed; for example to aggregation
● no code change needed in function - just “bracket” it
● performance considerations: turn on/off the capturing and tracing of
counters for this LoggerName in the configuration


### Aggregation

● stateful backend
● aggregates multiple measurements by
updating map of LoggerName -> statistics
    ○ compute simple statistics (count,min,max,mean,stdev) over
■ traced values
■ rate of change
■ time between messages
    ○ ewma (exponentially weighted moving average)
● aggregated values enter Switchboard
prefixed name: #aggregation
type: AggregatedMessage

## Contravariant Logging 

- Tiny core API
newtype Tracer \(m a=\) Tracer \((a \rightarrow m())\)
traceWith :: Tracer \(m a \rightarrow a \rightarrow m ()\)
traceWith (Trace t) \(x=\operatorname{tx}\)
instance Contravariant (Tracer \(m\) ) where contramap \(f(\) Tracer \(t)=\) Tracer \((\) t \(\circ f)\)

Example primitive tracers
nullTracer :: Applicative \(m \Rightarrow\) Tracer \(m\) a nullTracer \(=\) Tracer \(\left(\backslash_{-} \rightarrow\right.\) pure \(\left.()\right)\)
stdoutTracer :: Tracer IO String stdoutTracer \(=\) Tracer putStrLn

Define a type with the (local) events and values to trace
data TraceLocalRootPeers \(=\)

TraceLocalRootWaiting DomainAddress DiffTime
| TraceLocalRootFailure DomainAddress DNSorlOError
\(1 \ldots\)
Pass in a tracer using that type 

localRootPeersProvider :: Tracer IO TraceLocalRootPeers \(\rightarrow \ldots \rightarrow ()10\) 
localRootPeersProvider tracer \(\ldots=\)

Trace the relevant values in the body at the appropriate points when \(( tt \mid>0) \$\) do
traceWith tracer (TraceLocalRootWaiting domain ttl) threadDelay tt|


With many subsystems, we have many typed tracers

Aggregate using records
- - | All tracers of a node bundled together data Tracers remotePeer localPeer blk \(m =\) Tracers \(\{\) chainSyncClientTracer
:: Tracer \(m\) (TraceChainSyncClientEvent blk chainSyncServerHeaderTracer :: Tracer \(m\) (TraceChainSyncServerEvent bli chainsyncServerBlockTracer \(\quad::\) Tracer \(m\) (TraceChainSyncServerEvent bll


mempoolTracer
:: Tracer m (TraceEventMempool blk) forgeTracer
:: Tracer \(m\) (TraceForgeEvent blk) \}
This style makes it relatively easy (and efficient) to turn tracers on/off


### Another example

sequence [addNewFetchRequest (contramap (TraceLabelPeer peer) clientStateTracer) blockFetchSize request gsvs stateVars (Right request, gsvs, stateVars, peer) \(\leftarrow\) decisions]
The per-peer action does not need to know which peer id.
For tracing we want to know which peer it concerns, so we use contramap (TraceLabelPeer peer) clientStateTracer
starting from outer tracer of type Tracer \(m\) (TraceLabelPeer peer (TraceFetchClientState header))
giving us the inner tracer of type Tracer \(m\) (TraceFetchClientState header)

