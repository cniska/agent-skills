---
name: refactor
description: Run a refactor or a rewrite the owner's way — choose which the problem needs, then carry it out so the new design copies nothing from the old. Use when a module's design is wrong, after a design review proposes a redesign, or before a feature the current structure makes hard.
argument-hint: "<module, files, or the redesign to carry out>"
---

# Refactor

Change a design without letting the old one leak into the new. Agents write code that looks like the code around them, so the shape a refactor leaves behind is the one every later change copies. Design is more than half of this work.

## Choose the mode

- **Refactor** when the design is sound where it matters and the change can move in steps that each keep the tests green. If the code would be broken for longer than one step, it is not a refactor: stop and choose.
- **Rewrite** when the design is wrong across modules whose patterns interlock, so fixing one module leaves the old shapes in its neighbors for the next agent to copy. A rewrite needs requirements that say what done is, a spec or its acceptance criteria. Without them, write them first with the owner, or refactor.

Decide from the fix history, the backlog and the requirements, never from reading the code a rewrite would replace. For a refactor, `design-review`'s module review then finds the causes to remove; a concern that spans folders, such as navigation, is scoped by what it does, not by file prefix.

The repo's own rules hold throughout: its commit gate, its docs-with-behavior rule, its glossary. This skill never overrides them. Where docs contradict the code or each other, the owner decides which is right; list each contradiction for them rather than picking one.

## Refactor

1. **Pin the behavior.** Where no test pins what the code does now, write tests at the outermost surface the refactor keeps, such as the app, the CLI or the HTTP API, that assert what it does today, bugs included, before moving anything. These are the tests that stay untouched; a test of an internal the refactor removes goes with that internal, once the outer tests cover what it checked.
2. **Make the change easy, then make the easy change.** Before a feature the structure fights, reshape the structure first in its own commits, then add the feature.
3. **Keep structure and behavior in separate commits.** A commit either changes structure, with the pinning tests untouched and green, or changes behavior. Where splitting them would take a shim, the commit changes both and its subject says it changes behavior.
4. **Fix each pattern once, cleanly, in one place first.** Pick the module agents will copy from, give it the right shape in full, and let the rest follow it. Take the shape from `design-review`'s rules, never from the code beside it.
5. **Delete what the new design supersedes in the same change.** Leftover behavior, a second path, a shim or a flag keeping the old way alive is not carried forward. A refactor that removes more than it adds is the good kind; one that adds more is questioned.
6. **Use a codemod for a rule-based change.** A rename, a signature change or a moved import across many files goes through a deterministic tool (the language server, an AST transform), not a model editing file by file.
7. **Review when a part is done, not per slice.** When a module or a pattern is complete, run `design-review` on it as a whole and fix every tier-1 finding before moving on.

## Rewrite

1. **Requirements first.** Settle the spec with the owner before any design. The spec says what holds, never how the old code did it.
2. **Acceptance tests from the requirements.** Write each criterion as a test through the public surface only: the CLI, the API, the UI. No internal imports. Confirm they fail.
3. **Delete the old code before designing.** On the rewrite's branch, remove the modules the requirements define anew, the files only they use, their tests, and the docs that describe how they work, a design written for the old code included. A shared file that kept code also uses stays. In each kept file, cut the import and the capability that needed it, never the file, so the branch still passes its gate; the rewrite brings each capability back. Do not read any of it, not even to learn how a hard piece works; find that from the external contract instead, such as the tool's documentation or the protocol. Old code in reach biases the new design toward it. What outlives the code is not deleted: stored data, applied migrations and a contract another deployed app calls. The new design reads them as they are and changes them through `deprecation`, unless the owner has declared that data disposable, in which case the new design owns its shape.
4. **Design from the requirements and the patterns.** Write the design document from the spec and `design-review`'s rules. Have a different model challenge it, framed to disprove it, and have the owner approve it before code is written.
5. **Do not rebuild the old feature set.** The spec decides what exists. An old behavior the spec does not require is not rebuilt; list it for the owner. Resist the second-system effect: a capability deferred in the old system stays deferred unless the spec asks for it.
6. **Build to the tests, part by part,** refactoring as you go by the steps above, with `design-review` on each finished part.
7. **Land in one change.** The replacement passes its acceptance tests, then lands with the old code gone, so no commit on the default branch runs two designs. Nothing runs old and new side by side.

## See also

- `design-review` — the rules every new shape follows, and the module review that diagnoses what to change
- `simplify` — behavior-preserving local moves inside a slice
- `deprecation` — removing an interface other code still depends on
- `spec` — writing the requirements a rewrite starts from

## Red flags

- Reading the old code during a rewrite, for shape or for "how it did the hard part"
- Copying the pattern next to the change instead of the rule it should follow
- A structure change and a behavior change in one commit that could have been split without a shim
- A refactor that leaves the code broken across several commits
- A deletion committed with the build left broken, or with the gate skipped
- Keeping the old path alive beside the new one: a shim, a flag, a dual read, a parallel run
- Rebuilding an old behavior the requirements do not ask for
- A rewrite started without acceptance tests that fail
- Design review skipped until everything is done, or run on every slice instead of each finished part
