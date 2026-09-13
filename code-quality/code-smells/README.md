# code-smells

A Claude Code skill that catalogues Martin Fowler's 24 code smells and what to do about
each one.

## What it does

- Lists every smell from *Refactoring* (2nd ed.), Ch. 3, in the book's order.
- For each: the symptom you can point at, and the refactorings that treat it.
- Reviews code against the catalogue when asked, reporting only smells with a concrete
  location behind them.

## What it is not

- Not a linter and not a bug detector. Smells are judgement calls — nothing is broken, the
  tests may pass. A small, stable, rarely-touched function with a long parameter list is
  usually fine.
- Not a refactoring reference. The moves are named so you can look them up, but the
  mechanics live in the book and at <https://refactoring.com/catalog>.

## Layout

```
code-quality/code-smells/
├── SKILL.md       # The catalogue and how to apply it
├── code-smells.md # /code-smells slash command
└── README.md      # This file
```

## Usage

The skill activates on its own when you ask about code smells, code quality, or which
refactoring to reach for. Or invoke the command directly:

```
/code-smells                 # review the current changes
/code-smells src/            # review a path
/code-smells feature envy    # look up one smell
```

## Provenance

Smell names and order: Martin Fowler with Kent Beck, *Refactoring: Improving the Design of
Existing Code*, 2nd edition (2018), Chapter 3, "Bad Smells in Code", pp. 71–84. The symptom
text in `SKILL.md` is a paraphrase for quick reference, not the book's wording.

The Bloaters / Couplers / Dispensables groupings used on many websites come from
[refactoring.guru](https://refactoring.guru/refactoring/smells), which derives from the
first edition — not from the second.
