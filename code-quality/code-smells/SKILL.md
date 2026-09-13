---
name: code-smells
title: Martin Fowler's Code Smells
description: Reference catalogue of the 24 code smells from Martin Fowler's Refactoring (2nd edition), each with its symptoms and the refactorings that treat it. Use when reviewing code quality, naming a concern in a review, or deciding which refactoring to reach for.
version: 1.0.0
tags: [refactoring, code-smells, code-quality, code-review, fowler]
harness: claude-code
tools:
  discoverable: true
  list:
    - Read
    - Grep
    - Glob
---

# Martin Fowler's Code Smells

A code smell is a surface indication that usually corresponds to a deeper problem in
the code. Smells aren't bugs — nothing is broken, the tests may all pass — but each one
points at a design decision that will make the code harder to change later. The point of
noticing a smell is to decide whether a refactoring is warranted *now*, not to treat the
list as a checklist that must be driven to zero.

This skill is a catalogue. Use it to name a smell precisely, explain its symptom, and
pick the refactoring that treats it.

## How to use this skill

- **Reviewing code**: work through the catalogue below, but report only smells you can
  point at concretely (`file:line` plus the specific construct). Say which smell it is,
  why it costs something, and which refactoring addresses it. Rank by how much the smell
  actually impedes change in *this* codebase, not by position in the list.
- **Naming a concern**: if you can feel that something is wrong but can't articulate it,
  scan the symptom column. Getting the right name is most of the work.
- **Choosing a refactoring**: the "Usual treatment" column names the refactorings from
  the same book that most directly address the smell. Refactorings are defined in
  `refactoring.com/catalog`; this skill covers the smells, not the mechanics of each move.
- **Don't over-report**: a smell is a judgement call, and a small, stable, rarely-touched
  function with a long parameter list is usually fine. Context decides.

## The catalogue

Fowler's second edition lists 24 smells. The order below is the book's order, which runs
roughly from local, low-level concerns to structural and inter-class ones.

### 1. Mysterious Name

**Symptom**: A function, variable, type, or module whose name doesn't reveal what it does
or holds, so you have to read the body to find out. If you can't come up with a good name
for something, that's often a sign the design is muddled.

**Usual treatment**: Change Function Declaration (Rename Function), Rename Variable,
Rename Field.

### 2. Duplicated Code

**Symptom**: The same logic shape appears in more than one place — two functions with the
same body, the same expression in two sibling classes, or two near-identical branches. Any
change now has to be made in several places, and one will be missed.

**Usual treatment**: Extract Function, Slide Statements, Pull Up Method (for duplicated
bodies in sibling subclasses).

### 3. Long Function

**Symptom**: A function has grown past the point where you can hold it in your head — you
scroll, lose the thread, and can't see the shape of the algorithm. Long functions tend to
accumulate comments explaining sections, and to hide duplicated fragments.

**Usual treatment**: Extract Function, Replace Temp with Query, Introduce Parameter Object,
Decompose Conditional, Replace Loop with Pipeline.

### 4. Long Parameter List

**Symptom**: More parameters than you can remember or pass correctly, especially when the
same group of arguments travels together through several calls. Callers end up threading
values they don't care about.

**Usual treatment**: Introduce Parameter Object, Preserve Whole Object, Replace Parameter
with Query (let the callee look it up), Remove Flag Argument.

### 5. Global Data

**Symptom**: Data that any part of the program can read and any part can mutate. Nothing
tells you who changed it or when, so bugs appear far from their cause.

**Usual treatment**: Encapsulate Variable first, so access goes through functions; then
move the data into a class or pass it as a parameter.

### 6. Mutable Data

**Symptom**: Data that changes after it's created. Every extra thing that can change state
multiplies the cases you have to reason about, and produces action-at-a-distance bugs.

**Usual treatment**: Encapsulate Variable, Split Variable, Slide Statements, Extract
Function, Replace Derived Variable with Query, Combine Functions into Class. Where
practical, prefer copying and returning a modified value over mutating in place.

### 7. Divergent Change

**Symptom**: One class or module has to change in several different ways for several
different reasons — a database change and a pricing-rule change both land in the same
file. It means two unrelated responsibilities live together.

**Usual treatment**: Split Phase (separate the distinct phases of processing), Extract
Class, Move Function.

### 8. Shotgun Surgery

**Symptom**: The inverse of divergent change. One logical change forces many small edits
scattered across many classes or files. Easy to miss one, and hard to verify you got them
all.

**Usual treatment**: Move Function, Move Field, and Combine Functions into Class to gather
the scattered behaviour into one place (then re-split if that place gets too big).

### 9. Feature Envy

**Symptom**: A function spends more time reaching into another object's data than using
its own. The logic wants to live with the data it's working on.

**Usual treatment**: Move Function. If only part of the function is envious, Extract
Function and move that piece. If several callers are envious of the same object, that's a
sign a new class is waiting to be extracted.

### 10. Data Clumps

**Symptom**: The same three or four items keep appearing together — as fields of a class,
parameters of several functions, or both. The group is a concept that hasn't been named
yet.

**Usual treatment**: Extract Class, Introduce Parameter Object, Preserve Whole Object.

### 11. Primitive Obsession

**Symptom**: Using a primitive — a string, an int, a raw map or list — where a small type
of its own would carry meaning, validation, and behaviour. Phone numbers as strings,
money as a float, a `dict` where a record belongs.

**Usual treatment**: Replace Primitive with Object, Replace Type Code with Subclasses.
Often the extracted type is where the feature-envied behaviour finally belongs.

### 12. Repeated Switches

**Symptom**: The same `switch` statement or `if`/`else` cascade on the same type appears in
several places. Adding a case means finding and updating all of them, which is shotgun
surgery with a shared cause.

**Usual treatment**: Replace Conditional with Polymorphism, usually via Replace Type Code
with Subclasses. Where the cases are few and static, Replace Parameter with Explicit
Methods or a plain Extract Function is often enough.

### 13. Loops

**Symptom**: An old-style loop that walks a collection with an index or accumulator,
burying the intent of the transformation in bookkeeping. Modern language constructs say
what is being computed far more directly.

**Usual treatment**: Replace Loop with Pipeline (filter / map / reduce). The exception is a
hot inner loop where the pipeline form measurably costs performance — leave it, and say so
in a comment.

### 14. Lazy Element

**Symptom**: A function, class, or structure that no longer does enough to earn its place —
a class that is a thin wrapper, a subclass that adds nothing. The indirection costs reading
time and buys nothing.

**Usual treatment**: Inline Function, Inline Class, Collapse Hierarchy.

### 15. Speculative Generality

**Symptom**: Flexibility built for requirements that never arrived. Abstract classes with
one subclass, parameters nobody passes, hooks nobody calls, or a general mechanism where a
specific one would do. It exists mostly to make the design feel future-proof.

**Usual treatment**: Collapse Hierarchy, Inline Function, Inline Class, Remove Dead Code,
Change Function Declaration (drop the unused parameters).

### 16. Temporary Field

**Symptom**: A field that is only set or used in certain circumstances, so the object
spends most of its life with a field you must not touch. Usually the field and the code
that uses it are a class trying to be born.

**Usual treatment**: Extract Class to give the field's collaborators somewhere to live, or
Introduce Special Case / null object so there's no "unset" state to guard against.

### 17. Message Chains

**Symptom**: Long navigation chains like `a.b().c().d()`. The caller is coupled to the
whole intermediate structure, so any change to the relationships in the middle breaks it.

**Usual treatment**: Hide Delegate, then Extract Function and Move Function to put the
behaviour where the data actually lives so the chain isn't needed at all.

### 18. Middle Man

**Symptom**: A class or function that mostly just delegates. Some delegation is
encapsulation; when most of a class's methods forward calls, the class is pure overhead.

**Usual treatment**: Remove Middle Man, Inline Function or Inline Class, Replace Superclass
with Delegate, Replace Subclass with Delegate. The tricky version is delegation added for
good reason (adaptation, hiding a dependency) — keep that, remove the rest.

### 19. Insider Trading

**Symptom**: Two classes or modules that pass data back and forth privately and know too
much about each other's internals. The coupling is invisible from the outside, so changes
in one keep surprising the other.

**Usual treatment**: Move Function, Move Field, Extract Class, Hide Delegate, or Replace
Subclass with Delegate to route the communication through a defined interface.

### 20. Large Class

**Symptom**: A class doing too much, usually with too many fields, or fields that only some
methods use. A common early symptom is duplicated code inside it.

**Usual treatment**: Extract Class (often several times), Extract Superclass, Replace Type
Code with Subclasses. Decide which responsibilities belong together and split on that.

### 21. Alternative Classes with Different Interfaces

**Symptom**: Two classes that do the same job but through differently named methods or
slightly different signatures, so callers can't use them interchangeably and have to know
which is which.

**Usual treatment**: Change Function Declaration to align the names and signatures, Move
Function to bring the operations together, Extract Superclass once the shape is shared.

### 22. Data Class

**Symptom**: A class with fields plus getters and setters and almost no behaviour — the
logic that should act on the data lives somewhere else, typically in feature-envy form.
Dumb data holders are sometimes legitimate, but usually they're the other half of a
misplaced-behaviour problem.

**Usual treatment**: Move Function into it to take over the behaviour that's envying it,
Encapsulate Record or Encapsulate Collection to stop raw access, Remove Setting Method
where mutation isn't needed.

### 23. Refused Bequest

**Symptom**: A subclass inherits fields and methods it neither wants nor uses, or overrides
almost everything it inherits. The inheritance was inherited for convenience, not for the
is-a relationship.

**Usual treatment**: Push Down Method and Push Down Field to move the unwanted members to
the sibling that does want them; where the relationship is really has-a,
Replace Subclass with Delegate or Replace Superclass with Delegate.

### 24. Comments

**Symptom**: Comments used as deodorant — a block of prose explaining what a dense,
obscure function does, or a note recording why a value is what it is because the code can't
say it. This is the one smell that needs a caveat: comments are not inherently bad. A
comment that explains *why* something is done, or records a decision or a piece of
history, is valuable. The smell is a comment that exists because the code couldn't be made
clear.

**Usual treatment**: Extract Function and Change Function Declaration to encode the
explanation in the code, then delete the comment; if the comment records a decision, keep
it or move it to a commit message; Introduce Assertion where the comment is really stating
an invariant.

## Other taxonomies

The Bloaters / Object-Orientation Abusers / Change Preventers / Dispensables / Couplers
groupings you'll meet elsewhere are from [refactoring.guru](https://refactoring.guru/refactoring/smells),
not from Fowler. That scheme is built from the first edition and adds a few smells the
second edition drops or renames — Dead Code, Lazy Class (Fowler's "Lazy Element"),
Parallel Inheritance Hierarchies, Inappropriate Intimacy (roughly Fowler's "Insider
Trading"), Incomplete Library Class, and Switch Statements (Fowler's "Repeated Switches"),
alongside the first edition's Long Method, Duplicate Code, and so on. It's a perfectly
usable grouping; just don't attribute it to the book.

## Provenance

Smell names and their order come from Martin Fowler with Kent Beck, *Refactoring:
Improving the Design of Existing Code*, 2nd edition (2018), Chapter 3, "Bad Smells in
Code", pp. 71–84. The symptom and treatment text here is a paraphrase for quick reference —
read the chapter for the full reasoning and the worked examples.
