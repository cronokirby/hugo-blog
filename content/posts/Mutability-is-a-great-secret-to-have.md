---
title: "Mutability Is a Great Secret To Have"
date: 2019-03-06T11:39:03+01:00
draft: false
description: Mutability is ok, as long as no one knows about it
---

## Resisting the urge for purity
There's a very common idea spread around in FP circles that
goes something like: "Avoid mutable state". This is a good idea,
and many articles are out there talking about why this is the case.
I agree with these for the most part, but sometimes people lose the forest
for the trees when thinking about this goal.

## Why do we want to avoid mutability?
One of the biggest advantages of reducing mutable state in our code, is reducing
the working parts we need to keep track of when reasoning about local pieces of code.
When each function is dependent on the global state of the application at that time, we
not only need to think about the parameters of that function, and what it returns,
but also the global state the application might be in when the function is called,
and what effect we have on that state. By reducing mutable state, we reduce
the mental space we need to keep a handle on when reasoning about our code.

One apparent advantage is that by disentangling our code from global state,
we can treat it as a black box. If the only things a function depends upon
are its parameters, and its only effect on the world is returning some output,
we can treat it like a black box: we don't care *how* it works, we just care about
*what* it does, and what properties it has.

We can combine this black box property with a good set of tests, and really get
all the advantages of this approach. The black box is extremely composable, since
all we need to understand are the holes we can connect things with, and never
the inside of the box itself.

## FP for clarity
Another commonly espoused advantage of FP is that of making individual pieces of code clearer.
In many cases, an algorithm is much better understood when explained in a declarative fashion,
rather than the more traditional imperative way. This can often be much more concise, although
we should avoid confusing concise with easy to understand.

We should avoid making too direct an equivalence between declarativeness and readability,
because the two are not the same: it's possible to make imperative code that is readable, and likewise,
declarative code that is completely unreadable. (plenty of people will claim that FP code is much more
obscure, and they can be right at times).

## The main difference between these two properties

The main difference between the *black box* property and the *clarity* property,
is that the black box property applies to the way we compose code, and to the contracts
that our code respects, but the clarity property applies to the small pieces of code inside the functions we
define. Where the black box property is about the box, the clarity property is about the contents
of that box.

Often people focus too much on the clarity aspect of FP, because this is the more apparent property.
When writing code in FP, especially when getting used to the approach, and working on smaller snippets,
the clarity property is what comes to the foreground.

The problem is that people focus too much on clarity and declarativeness in the small, and forget about
the black box property. Sometimes a declarative implementation of a piece of code isn't the clearest.
In those cases however, we don't have to sacrifice the black box properties of that function if we
choose to implement it in an imperative way. We can have a function that depends on no global state, and
doesn't have any visible side effects, but still using mutability as an implementation.

## A small example

To illustrate a situation where a declarative decomposition of a problem ends up yielding a more obtuse implementation.
Let's try implementing a prime sieve in python. The goal of this function is to return a list of the prime numbers up to a max value.

```py
from itertools import reduce

def primes(mx):
    return reduce(lambda l, x: l if any(map(lambda d: x % d == 0, l)) else l + [x], range(2, mx))
```

Now this is a somewhat contrived way of doing it, since `reduce` begs for an imperative implementation,
but this is a pretty easy way of doing this in a purely declarative way. As expected,
this function has no visible side effects, and depends only on the parameters passed to it.

The only downside is that for people not familiar with `reduce` or with FP in python more generally,
this isn't the easiest function to understand. And even for a person quite familiar with declarative code,
it isn't clear to follow the execution of this code.

One reason for this, is that reduce introduces a bit of imperative control flow, but in a declarative way.
This is a necessary thing to do in a purely functional language such as Haskell, and a useful tool
in languages that aren't as purely functional, such as python in our case. But reduce is often
less clear than an imperative version of the same code.

## Back to imperative

Let's try the code again in an imperative form:
```py
def primes(mx):
    acc = []
    for x in range(2, mx):
        found = False
        for d in acc:
            if x % d == 0:
                found = True
        if not found:
            acc.append(x)
    return acc
```

We no longer have a single line, but we have an easier to follow function. This is more or less just an unrolling of
the previous function, making all the underlying functions explicit, instead of composed together.
The important thing is that all the external properties satisfied by the previous function are satisfied by the current one.
The function doesn't have any visible side effects, and doesn't depend on any global state, just the arguments passed to it.

## Summary

The more general takeaway from these examples is that declarativeness for its own sake isn't necessary,
and that the external properties of a function are much more important to a codebase. Stateless functions
have the same benefits regardless of their implementation, and in fact, free us up to implement them in whatever
way fits our requirements, be they performance, or readability.

Let's try and keep the spirit of the law in mind, over the letter.
