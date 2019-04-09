---
title: "Notes on Ripple"
date: 2019-04-09T13:04:46+02:00
draft: false
description: Thoughts on Ripple, and decentralised network shapes.
---
{{<mermaid/source>}}


## Ripple itself
I recently spent a week working on a tiny irc-like service,
called [ripple](https://github.com/cronokirby/ripple).
The main difference between ripple and a traditional chat
service is the complete lack of a central server.

In this post I explore different ways to organise decentralised services
like ripple, and then explain how ripple itself works.

## Organisation
One of the tougher problems in taking a normal service
and decentralising it is how to shape the network. It's generally
much easier to have one big server that contains all the logic
for our service, and then have the clients connect
independently to that service.

A traditional service looks something like this:
{{<mermaid/diagram>}}
graph BT
    server
    1((1))
    2((2))
    3((3))
    1 --- server
    2 --- server
    3 --- server
{{</mermaid/diagram>}}
We have the big central server, responsible for most of the work.
When a client wants to send a message to the network, it sends
a message to the server, and the server in turn propogates that message
to everyone else. This organisation has a few advantages:

- It's very simple to understand.
- It doesn't require very many connections

Because only the big server matters, it's very easy
to join and leave the network without affecting anyone else.
A new node can simply connect to the server and be completely
integrated into the swarm. The node can leave at any point with
no issues, because the central server is still there, and capable
of handling the messages.

The centralised server, however, is also the biggest flaw in the service:
if the central server goes down, the entire network does.

If we want to replace this architecture with a decentralised version,
we'll need to address this flaw, and also try and avoid too many connections.

## Naive organisation
The most naive way to organise our new decentralised network is to simply
connect each node to all other nodes, like this:
{{<mermaid/diagram>}}
graph LR
    1((1))
    2((2))
    3((3))
    4((4))
    1 --- 2
    1 --- 3
    1 --- 4
    2 --- 3
    2 --- 4
    3 --- 4
{{</mermaid/diagram>}}
Sending messages isn't very complicated in this scheme: all
we need to do is send a message to each of the peers we're connected to.
The clear problem with this architecture is that we need to maintain (N - 1)
connections for each peer, given a network of N peers. This is a lot more
connections in total than the centralised scheme, and also many more connections
per node than that scheme.

The next scheme addresses that.

## Circular organisation
Instead of sending a message to every peer directly, we could instead send
a message to just a single peer, which will in turn be responsible for forwarding
that message further. This leads us to organise our network in a circle:
{{<mermaid/diagram>}}
graph LR
    1((1))
    2((2))
    3((3))
    4((4))
    1 --> 2
    2 --> 3
    3 --> 4
    4 --> 1
{{</mermaid/diagram>}}
When a node wants to send a message to the network, it just sends
it to the node in front of it, and when a node receives a message
from the node behind it, it passes it forward as well.
When a node receives a message that it sent, it doesn't
propagate it forward.

For example, if node 1 wants to send a message "hello",
it first sends `(1, "hello")` to node 2. The message then
propagates all the way back to node 1. Upon seeing `(1, "hello")`,
the first node recognizes itself as the sender, and the loop is closed.

If we compare the number of connections between this scheme and the last,
we see that we only need 2 connections per node, instead of a growing number,
which is very good. We also only need the same number of total connections
as in the centralised model, which is also quite desirable. The main disadvantage
of this architecture is that the latency for messages grows linearly with the size of
the network. When we send a message, the peer preceding us needs to wait for the message to have been
sent to all the other peers before it. There are ways to mitigate this, by having a more freeform
organisation, where we're connected to a small subset of peers, and
transmit the message to all of them, who in turn do the same. The messages in that scheme
propagate in the same way gossip does in the real world. The advantage of this
circular scheme over those schemes is that we have good confidence that every node will receive our
messages.

## Joining the network
After establishing the circular overlay, sending messages is pretty simple,
but the question of how to let a new peer join the network is tricky.
Back in the centralised scheme, it was very simple to let a peer join the network:
all they needed to do was connect to the server, and be done with it.

Connecting is the trickiest part of our new scheme.

We want to go from this:
{{<mermaid/diagram>}}
graph LR
    1((1))
    2((2))
    3((3))
    1 --> 2
    2 --> 3
    3 --> 1
{{</mermaid/diagram>}}

to this:
{{<mermaid/diagram>}}
graph LR
    1((1))
    new((new))
    2((2))
    3((3))
    1 --> new
    new --> 2
    2 --> 3
    3 --> 1
{{</mermaid/diagram>}}
Notice how node 3 is completely oblivious to this network change.
The only nodes involved are "new" which wants to join the network,
as well as 1 and 2, which need to be linked to the new node.

The process of joining the network can be described by the following sequence diagram:
{{<mermaid/diagram>}}
sequenceDiagram
    new->>1: JoinSwarm
    1-->>new: Referral(2)
    1->>2: NewPredecessor(new)
    new->>2: ConfirmPredecessor
    2-->>1: ConfirmReferral
{{</mermaid/diagram>}}

This is evidently more complex than in the centralised case, where
all we needed to do was connect to the central server. Coordination
between multiple nodes is necessary in a decentralised setting though.

## Final Remarks

This was a 1000-foot overview of [ripple](https://github.com/cronokirby/ripple).
Hopefully this was interesting or at least somewhat illuminating. For more information
about ripple, I'd recommend reading the documentation in the git repository :)
