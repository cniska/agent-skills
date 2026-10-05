# Module review

When a module keeps drawing fixes, the design under it is wrong. Patching each report grows the module while the cause stays. This review takes one module, asks what it is for, and keeps only what does that job; often that is mostly cuts.

## Scope

One module per run: the files that share its prefix or folder, and their tests. A module too large to read in full, source and tests both, is split by the concerns its file names already separate.

Name the module's public API (see "Each module has a public API"), and list every import other modules make from its internal files; each one is a boundary finding. The module owns what its files define and write. Something dispatched from another module, or a table written through another module, is a dependency, judged where it is owned. A cause that crosses a boundary belongs to the module that will own the shared code, and only that module's report proposes the change.

Source and tests do not change during the review. A finding outside the module goes to the repo's backlog, committed on its own.

## Purpose

State in one sentence what the module is for, taken from the doc that owns the subject, not from the code. List the owner's decisions that bind it, from the repo's rules, spec, decision records or design docs and backlog. A piece those decisions keep stays.

## What reaches it

For each export, command, flag, table, column and config key the module owns, find what reaches it: callers, entry points, hooks, scheduled jobs and the repo's skills. Search with `rg -n '\b<name>\b'`, counting imports and calls only. A piece nothing reaches is a cut candidate. For a table, find the columns that are never set and the values no row carries; each is a cut candidate. A path taken only when something goes wrong, such as a conflict or a crash recovery, is judged by whether it has ever run, from logs or history, not by how often it ran recently.

## Damage

Before a piece is proposed as a cut, state in one clause what breaks without it. A piece whose absence loses unsaved work, lets untrusted code change what runs, or lets through a change a gate would refuse is a guard: it stays, and so does its test. A piece whose absence changes nothing is a cut. A cut with no damage clause is not proposed.

A damage clause rests on one fact, such as "nothing reads this table". State it, and say how far it is proven: pointed at a line, walked through step by step, or run. Where it is cheap, run it: a script or test that calls the real code with the piece gone and fails loudly if the fact is wrong. Before calling a piece unreached, look where a text search stops: SQL strings, JSON a service returns, database columns, wire formats, another language reading the same data, feature flags, and code several calls away.

## Causes

Gather the module's fix history, following renames:

```sh
for f in <module files>; do
  git log --follow --format='C %h %s' --numstat -- "$f" |
    awk -v f="$f" '/^C /{fix=($3 ~ /^fix/); next} NF==3 && fix {n++; add+=$1} END{print n+0, "+"add+0, f}'
done | sort -rn
```

The output gives each file's `fix:` commit count and the lines those commits added. Read the largest fixes with `git show --stat`. Add every backlog entry that names one of the module's files.

Group the symptoms by the design decision behind them, and name each cause in one sentence with `file:line`. A fix that added hundreds of lines marks a place where the design was wrong. For each axis the module varies on, list the files that change when one value is added; an axis that touches more than one place is a cause, whether or not it has drawn a fix yet. Run the design review over the module's code, and treat each violation as a cause.

Read the module's docs against its code. The doc states the intent, so where the two disagree, the code moves to the doc. Rewriting a doc line to match the code is a cut of behavior: list it under Cuts, with its damage clause, for the owner to decide.

## Redesign

1. **Cuts.** Every file, function, flag, table, column, test and doc line that goes, each with its damage clause, and the doc and spec text each cut touches.
2. **Cause changes.** Each names the state, copy or path it deletes, since that deletion is what removes the symptom. A change that puts a new condition in front of state it leaves in place is a symptom fix: list it as one, with the cause it leaves, and do not propose it. A move counts as no new code, and a change that moves code without removing a concept the reader must hold, such as a branch, a mode, a type or a layer, relocates the cause instead of removing it and is not proposed. A slice that adds more than about a hundred lines of new logic, or more code than it removes, means the redesign is wrong at that point.
3. **Schema.** Every schema change goes into one slice.
4. **Backlog.** Every entry that names one of the module's files is cut with the code, closed by a cause change, kept with its reason, or left for the owner.

Have a different model challenge the redesign, framed to disprove it, and check each of its claims against the code.

Write the report with the sections above, and what the challenge changed. Nothing changes until the owner approves it; the approved redesign is carried out with `refactor`.
