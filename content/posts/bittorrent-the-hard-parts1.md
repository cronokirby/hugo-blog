---
title: "Bittorrent, the Hard Parts - 1"
date: 2019-05-03T16:54:09+02:00
description: "An algorithm for piece serialization"
draft: false
---

## About these posts

I've been working on a [bittorrent client](https://github.com/cronokirby/haze) in haskell
recently. It's now at the point where it can download torrents in the wild.

The [protocol itself](https://wiki.theory.org/index.php/BitTorrentSpecification)
is well specified, although it takes a few read-throughs to get the hang of it.
The first time I read through the protocol I didn't understand much. But as I started
implementing different parts of the protocol, those parts of the document started making
more and more sense.

That being said, there are still many parts of the protocol where the specification might
be clear, but *how* to implement that specification is left as an exercise to the reader.
One of the sections that's most guilty of this is the section related to how peer's operate.
There are many subtle rules about what peers should do in certain situations; the details
of what variables to keep track of and how to make sure all these conditions are satisfied
is a big leap from this description though.

In these series of posts, I want to try and explain the details that go into some of the algorithms
necessary to implement **Bittorrent**.

This post covers how to save the pieces that make up the data in a torrent to disk, and how to recompose
those pieces back together.

### Side Note: What is Bittorrent?
If you're already familiar with **torrents** or **Bittorrent**, then this section can be safely ignored.

Let me briefly explain these concepts.

Fundamentally, **Bittorrent** is a protocol that defines a way for multiple computers, which
we refer to as "peers", to download a file from eachother. Instead of each peer downloading
the file from a central server, they instead download different parts from eachother, and upload
the parts they have to the other peers that want those parts.

A **torrent** refers to this group of peers sharing a file.

## Torrents and Pieces

A torrent can contain either a single file, or multiple files. When a torrent contains multiple files,
it can optionally contain a root directory for those files. For example, `blockbuster.torrent` might
contain a single `blockbuster.mp4` file, or perhaps `blockbuster.mp4, blockbuster.subtitles` in a `blockbuster` folder.

I mentioned previously that peers trade "parts" of a file. Instead of considering each peer as either having
the entire file, or not having it, and then downloading from those that have the **whole** file, we divide the file
into parts. We call these parts **pieces**. At any given point in time, we know which peers have which pieces (or at least, claim to), and what
pieces we have, and can make decisions about which piece to download next from whom.

The piece is also the unit of integrity of the torrent. Each piece has a SHA1 hash associated with it,
and when we receive a piece, we can hash the data inside, and see if it matches. This allows us to make sure that we're not
downloading junk data.

## Pieces and Division

A torrent contains information about what files are in it, as mentioned previously. It also contains information about
how big the pieces are: this is a single number specifying how big each piece is.

**Complication: All pieces are the same size, except for the last one.**
Let me illustrate this problem with an example. Let's say our piece size is 2 bytes, and our torrent contains 5 bytes
in total (let's skim over how this data is divided into files for now). Our data is divided like this:
```txt
xx xx x
```
The first 2 pieces have the announced size, 2 bytes, but the last piece has to be whatever size necessary to "plug in"
the end of the data.

This is just an edge case to worry about, and not as tricky as the next complication:

**Complication: Pieces don't belong to one file**
Let's continue using the same example as the previous complication, but further specify that the torrent actually
contains 2 files: A.png B.png. A is 3 bytes, and B 2 bytes. Our data would now look like this:
```txt
AA AB B
```
The second piece now contains data from 2 different files!

This is because, as far as pieces are concerned, the torrent is just a binary blob. When peers are trading
pieces it's as if the torrent just contained a single file. In fact, in the case of a single file, we don't have this
problem at all, since all the pieces belong to this file.

When there are multiple files, they have a defined order. Conceptually, the binary data in these files
is concatenated together, in this predefined order, and then piece division happens as if it were a single file.
This means that a piece may actually contain data belonging to an arbitrary of files. It's actually quite
common for a piece to overlap many files. Because movies, which are large, often come with subtitles, which are relatively
much smaller, the piece size we use for those torrents are usually larger than the size of all the subtitles combined.
It's not uncommon for a single piece to actually contain all of the subtitles as well as a chunk of the movie itself:

```txt
ABCDEFGHIJXXXXXXXX XXXXX...
```

## What our algorithm needs to do
Now we get to the crux of this post: the algorithm for saving and retrieving pieces.

We can break down what we do with pieces into 3 seperate tasks:

- Recomposing the pieces into the torrent's files
- Saving pieces to disk
- Reading pieces from disk

### Recomposing the pieces into the torrent's files
After we've downloaded all the pieces, we need to actually assemble the files
that compose the torrent from the binary data in those pieces. We need to handle this somehow.
One option would be to wait until we have all pieces and then glue them together, another would be
to save to files as soon as we have all the pieces in that file.

### Saving the pieces to disk
Although we could keep all pieces in memory until we have them all, and then flush them out to disk,
this doesn't work very well for actual torrents, which can easily be multiple gigabytes in size.
We need a way to save pieces to disk as they arrive, in such a way that we can easily recompose the pieces
into the files that make up the torrent once we have them all.

### Reading pieces from disk
A key aspect of bittorrent is that peers aren't just downloading from other peers, but also
uploading the pieces of the files that they already have. Since we don't keep pieces in memory,
but instead save them to disk, we need a way to retrieve these pieces from disk. We also need
to be able to do this no matter what stage we're at. We need a way to read pieces back, whether
we've glued the pieces back into the torrent files yet or not.

I've stuck to details of the protocol itself so far. Now I'm going to describe the approach I came
up with for this algorithm. This is not at all a unique approach, nor is it the only, or best way
to tackle this problem.

## Piece files, start files, and end files
Before we can even start on an algorithm to save pieces to to the right place, we need to decide
on what the "right place" is in the first place.

One choice would be to always work within
the files in the torrent: when we save a piece, we save different bits of the piece to different sections
of different files. We modify the final files directly. This has the advantage of not needing a final
recomposition step, since we're always working with the files themselves. The disadvantage is that the operation
of figuring out which sections of which files to write to is quite complicated.

Another approach, which is the one I chose, is instead to use as many files as convenient, and then
recompose them together as a final step. For example, instead of trying to figure out where "piece #38"
needs to go, we just save it in `piece-38.bin` and worry about recomposing it later.

We identify the following cases for how we save pieces:

- The piece belongs completely into a single file:

```txt
..xx xxxx xx..
```

In this case we save `piece #N` to `piece-N.bin`.

- The piece belongs to multiple files:

In this case, we will save the piece into N files, where N is the number of
files the piece belongs to. What these files are named depends on the following:


- If a file fits completely into a piece:

```txt
xxAAAyy
```

- If the piece contains the first bytes of a file

```txt
..xx xxAA AA..
``` 

Then we save the data for that file in `file.start`.

Note that we could seperate
this into 2 cases, but as we'll see later, not distinguishing these cases changes nothing in the end,
and makes the algorithm simpler.

- If the piece contains the last bytes of a file:

```txt
..AA AAxx xx..
```
Then we save the data for that file in `file.end`.

## Data Structures and Algorithms
For each of these algorithms, our life is made much easier if we calculate a nicer representation
of the file structure before hand. That is to say, we'll have a special representation of our
file structures used for writing the pieces, another for recomposing them, as well as a another,
used for reading back the pieces.

### Recomposing: Data Structure

The data structure for recomposing pieces together is pretty simple, for each final file in
the torrent, we keep a list of all its dependencies. That is to say, all the pieces that fit completly
into it, as well as all `file.end` and `file.start` if those exist.

```haskell
data Recompose = Recompose [(File, [File])]
```

To make our algorithm easier, we want to make sure that the dependencies are in the same order as
they are in the file, so we can reconstruct the file by writing all dependencies in order.

### Recomposing: Algorithm
The algorithm for recomposition is so simple, that we might as well already get it out of the way.
This also illustrates the benefit of this approach of using the most suitable data structure for
implementing our algorithms.

```haskell
recompose (Recompose mappings) =
    forM_ mappings $ \(file, deps) -> do
        when (allFilesExist deps) $ do
            writeAllTo deps file
            removeAll deps
```

For each file, we check if all its dependencies have already been written to,
in which case we can reconstruct the file by concatenating all the dependencies.

### Saving: Data Structure
In order to save each piece, we need to know which files the piece maps to,
and how many bytes are in each piece. Our data structure thus looks like this:

```haskell
data SavePieces = SavePieces (Piece -> [(Int, File)])
```

This contains a list of `(count, file)` tuples, listing the
files the piece needs to be saved into, in the order they appear, as well
as how many bytes of the piece should be saved in that file.

### Saving: Algorithm

This algorithm is better expressed using an imperative formulation,
but a functional fold would be able to accomplish the same thing:

```py
def save(piece, mappings):
    bits = mappings(piece)
    offset = 0
    for (count, file) in bits:
        write(file, piece[offset:offset+count])
        offset += count
```

We just go linearly through each of the files, and save the right amount of the piece.
For this to work correctly, we need to make sure that the order of the files and counts
is correct, otherwise we'll be saving the wrong part of the piece.
