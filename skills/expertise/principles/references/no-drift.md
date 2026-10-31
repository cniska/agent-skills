# No drift

Update, in the same commit, everything that describes, repeats, names or depends on what a change redefines.

A place left alone goes stale, and the next reader acts on it.

- Search for the old wording, names and shapes, and for each place that acts on what changed, whatever its wording:
  - a description, summary or message restating guidance that moved or changed
  - references, error messages, docs and test names after a rename
  - docs, help text, READMEs and examples describing the old behavior
  - callers, config, fixtures and schemas built for an interface's old shape
  - a spec, decision record or rules-file line the change contradicts
- Fix each hit, or point it at the one place that owns it.
- Name in the report anything found that belongs to another change.

Example: renaming the flag `--dry` to `--check` also changes the help text, the README's example and the test named for `--dry`.
