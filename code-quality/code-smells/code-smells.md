---
description: Review code against Martin Fowler's 24 code smells, or look up a smell by name
argument-hint: [optional file, directory, or smell name]
allowed-tools:
  - Read
  - Grep
  - Glob
---

# /code-smells

Use the catalogue in `.claude/skills/code-smells/SKILL.md`.

## Steps

1. Read `.claude/skills/code-smells/SKILL.md` to load the catalogue of 24 smells.

2. Decide the mode from `$ARGUMENTS`:

   - **Lookup** — the argument names a smell (or is close to one, e.g. "long method",
     "feature envy", "switch statements"). Report that smell's symptom and its usual
     treatment. If the name is from the other taxonomy (refactoring.guru), map it to
     Fowler's equivalent and say so.
   - **Review** — the argument is a path, a glob, or empty. Review that code (default: the
     currently changed files from `git status`/`git diff`, or ask if there are none)
     against the full catalogue.

3. In review mode:

   - Read the target code.
   - For each smell you find, report: the smell name, the concrete place (`file:line` and
     the actual construct — the function, the field, the chain), why it costs something in
     *this* codebase, and the refactoring that would treat it.
   - Order findings by how much they actually impede change here, not by catalogue order.
   - Skip smells that don't apply, and say so briefly rather than listing all 24.
   - Do not report a smell without a concrete location and construct behind it. "This class
     feels large" is not a finding.
   - If nothing meaningful turns up, say that plainly.

4. Do not apply refactorings unless the user asks. This command reports.
