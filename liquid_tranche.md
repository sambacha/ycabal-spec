## Maidenlane SLT: Super Liquidity Tranches

Super-liquidity tranche (SLT) system is a mathematical construct, defined below to describe an efficient digital market model. Assets that are traded on such market $^{1}$ may benefit from the trade option against at least one super-liquid exchange medium.

Consider an abstract liquid tranche (ALT) system as a weighted directed graph $G:=(V, E, w),$ where set of vertices $V,|V| \leq| N |$ contains digital representation of all tradeable assets in $G,$ set of edges $E=\{e \in V \times V:$ $w(e)>0\}$ represents all possible atomic $^{3}$ asymmetric $^{80}$ trades, which are weighted by the function $w: E \rightarrow R ^{+}$ corresponding to the price of some trade $e \in E$

### Definition 1 - Half Liquid asset.

Vertex $v \in V$ represents half-liquid asset $^{2$ iff either $\operatorname{deg}^{-}(v)=0$ (source) or $\operatorname{deg}^{+}(v)=0($ sink $),$ where $\operatorname{deg}^{(-1+)}: V \rightarrow N$ is respectively a number of tail ends (indegree) and a number of head ends (outdegree) from vertices adjacent to $v$

#### Corollary 1.1 - liquid vertex

Any liquid vertex $v \in V$ has both $\operatorname{deg}^{-}(v) \geq 1$ and $\operatorname{deg}^{+}(v) \geq 1$.

#### Corollary 1.2 - liquid graph

If there exists a strongly connected subgraph $G^{\prime} \subseteq G$ s.t. all of its vertices are liquid, then $G^{\prime}$ is called liquid graph.

#### Corollary 1.3 - k-liquid graph

If $G^{\prime} \subseteq G$ is a k-connected liquid graph, then $G^{\prime}$ is called $k$ -liquid.

Trade paths can have different liquidity preferences. For example, if a path $(s, v): s, v \in V$ on graph $G$ has preferable liquidity when compared to any other path $\left(s^{\prime}, v\right): s^{\prime}, v \in V,$ then $(s, v)$ is a shorter or equally weighted

### Definition 2 - Preferable liquidity path.

Let $S \subset V \times V$ contain all shortest paths from vertex $s$ to vertex $t: \forall s, t \in
V$. Also let vertex $v \in V$ have the maximal $^{1}$ betweenness centrality measure

$C_{B}(v):=\sum_{s \neq t \neq v \in V} \frac{\sigma_{s t}(v)}{\sigma_{s t}}: \forall(s, t) \in S,$
where $\sigma_{s t}:=\sum_{(s, t) \in S} \sum_{e \in(s, t)} w(e)$ and $\sigma_{s t}(v)$

is a sum of only those shortest paths in $S$ which contain $v$. We say that
$(s, t) \in S$ is a path with preferable liquidity if it ends with $v,$ i.e. $t=v$

In order to capture a desired super-liquidity property of an always preferable asset in an ALT-system $G,$ we need to identify such asset not only as a preferable "exit" (sink) vertex, but also as the one that can be consequently traded for any other liquid asset in $G$ at the most
attractive price.

### Definition 3 - Super Liquidity

A liquid vertex $v \in V\left(G^{\prime}\right)$ of a complete liquid subgraph $G^{\prime} \subseteq
G$ is called a super-liquid vertex iff any preferable liquidity path $p=(s, v)$ can be almost surely
continued with an efficient trade for any other liquid $u \in V\left(G^{\prime}\right), u \neq v$ in
such a way that $\sum_{e \in(s, u)} w(e) \leq \sum_{e \in(s, v)} w(e)+\sum_{e \in(v, u)} w(e)$ and
$(s, u)$ is a shortest path.

#### Corollary 3.1 - Super Liquid graph

A complete liquid subgraph $G^{\prime} \subseteq G$ is called a super-liquid graph iff $G^{\prime}$
contains a super-liquid vertex.

## Super Liquidity Tranche

In general, unless $C_{B}(v)$ has a maximum value on $G,$ there could be a group of vertices with the maximal betweenness centrality score $M=\left\{v \in V: C_{B}(v)=\max \left(C_{B}(V)\right)\right\} .$ In that case definitions are adopted to consider $\forall v \in M$.

Last definition of a super-liquid graph provides us with a starting point
for the future framework of the super-liquidity tranche (SLT) system that
can in theory allow efficient price trading. However there is no practical duality
between super-liquid and illiquid assets. Instead, we can choose to link
super-liquid vertex with a controlled liquidity asset, that has a programmable
dynamic pricing model. Such subgraph is called a 'Hyper'
(HLT) liquidity tranche with at least two liquid tokens (vertices).

[1] Maidenlane is in essence a concensus bound, matching, clearing and settlement engine.

[2] _note_

[3] _note_

##### Manifold Finance
