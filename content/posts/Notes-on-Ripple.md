---
title: "Notes on Ripple"
date: 2019-04-09T13:04:46+02:00
draft: true
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
and decentralising it is how to shape the network.
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
We have one big central server, responsible for most of the work.
When a client wants to send a message to the network, it sends
a message to the server, and the server in turn propogates that message
to everyone else. This organisation has a few advantages:

- It's very simple to understand.
- It doesn't require very many connections

Because only the big server matters, it's very easy
to join and leave the network without affecting anyone else.
The centralised server is also the biggest flaw in the service:
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
Sending messages isn't very complicated in this scheme, since all
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
When the first peer sends a message, it will eventually receive
the same message from the fourth peer, at which point it knows
to not transmit it forward, since it was the originator of that message.

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