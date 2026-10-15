# No drift

A change also updates, in the same commit, everything that describes, repeats, names or depends on what it changed. Left alone, each of these goes stale:

- **Rules:** a description, summary or message restating guidance that moved or changed.
- **Names:** references, error messages, docs and test names after a rename.
- **Behavior:** docs, help text, READMEs and examples describing what the code used to do.
- **Contracts:** callers, config, fixtures and schemas built for an interface's old shape.
- **Decisions:** a spec, decision record or `AGENTS.md` line the change contradicts.

Before committing, search for the old wording, names and shapes, and fix each hit or point it at the one place that owns it. Where the repo's validator refuses a run of words two files share, the second place names the source instead of rewording the copy. Name in the report anything found that belongs to another change.
