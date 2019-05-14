---
title: "The Component Pattern"
date: 2019-05-14T13:57:24+02:00
description: "A common architectural pattern for organising stateful code"
draft: false
---

## The Problem

Software isn't just something you think about and then write all at once,
but rather something you add on to as you go along. The way you organise
your code also changes as files and components grow larger. How we organise
our code is as important as the code itself. Well organised code should be
both easy to understand, and also easy to expand.

When it comes to **Functional Programming**, and **Haskell** more specifically,
the question of how to organise code is often brought up by people new to both.
One disadvantage of the **Functional** paradigm is that it doesn't come baked in with
organisational principles, unlike **Object Oriented** programming; that being said,
there's not any "One True Object Oriented" way of organising code, just a lot more discussion
of that aspect of code in that circle. A lot of the same principles apply when organising
functional code; in fact, the goals are mostly the same: we want code that's easy to understand
in grow regardless of what paradigm we use.


### Differences from Imperative languages

The main difference in a language like **Haskell** as compared to the more common
imperative languages, is the push towards pure functions. Pure functions are
a good organisational tool, since they make sure we don't couple functions to surrounding
things like state. Because of this, organising pure functions doesn't require as much care in terms
of runtime effects. Our code may be hard to understand because of its bad organisation,
but it's unlikely to have far reaching side effects, given the nature of pure code.

### Organising Stateful Components

This post is about a "necessary evil" of Functional Programming: state.
State is more than just mutable variables: socket connections, files, and resources more generally
are all examples of state. This post is about a technique for organising modules around the resources
they need access to, in order to make sure that the use of state is done within well defined and
organised boundaries.


### The Component Pattern

Let's get into the meat of the pattern. The idea is to pair a conceptual component of a system,
say, a **logger**, for example, along with a concrete module, and effect type.

Let's use our logger example more fully. Let's say that our project needs a component
responsible for logging things to a file. We can send messages for it a log across a queue,
and it has a File it logs to.

First we'd create a module to contain this, say `Logger.hs`:

```hs
module Logger () where
-- imports ommitted
```

The next step is to define a type that contains all the information the logger needs to run:
```hs
data LoggerInfo = LoggerInfo
    { loggerQueue :: TBQueue Message
    , loggerFile  :: FilePath
    }
```

Then we create a new effect type, which is just a Reader with access to that information:
```hs
newtype LoggerM a = LoggerM (ReaderT LoggerInfo IO a)
```

Now inside the module itself, we write the functions we need as `LoggerM a`, for example:
```hs
latestMessage :: LoggerM Message

logMessages :: LoggerM ()
```

We also have a main function that contains all the things a component needs to do, sort of like
a "main loop" for that component:
```hs
main :: LoggerM ()
```

At this point we have the tools to express functions for that component inside the module itself,
but not API to interact with the component from outside. We have 2 options for exposing this
component to the outside world.

- Export `LoggerInfo` and `LoggerM`, as well as `main`

We'd have functions to construct `LoggerInfo` as well as run `LoggerM`:

```hs
makeLoggerInfo :: File -> IO LoggerInfo

runLoggerM :: LoggerM a -> LoggerInfo -> IO a
```

- Completely hide the existence of `LoggerInfo` and `LoggerM`

With this choice, we'd only export a function that constructs and runs the main logger computation:

```hs
runLoggerMain :: File -> IO ()
```

Regardless of which choice we make, we're free to start the logger component in a new thread if we want.
This is usually done, because components generally contain independent pieces of state, and spend all their time
doing the same thing over and over, rather than acting as a one time task.

Hiding everything is the preferred choice, as it provides more encapsulation, and a cleaner API.
Users of the component can ignore the implementation details of the component completely, and just run a single
function in a new thread after passing it all the prerequisite information.


## Summary
In summary, the component pattern looks something like this:

```hs
module Component (startComponent) where

data ComponentInfo

newtype ComponentM a = ComponentM (ReaderT ComponentInfo IO a)

main :: ComponentM ()

startComponent :: Dependencies -> IO ()
```

This isn't the end-all-be-all of organising stateful components of a larger project,
but hopefully this is a useful pattern to put in the toolbox :)

## Further Reading
- https://www.fpcomplete.com/blog/2017/06/readert-design-pattern

