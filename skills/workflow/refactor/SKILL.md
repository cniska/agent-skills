---
name: refactor
description: Run a refactor or a rewrite the owner's way — choose which the problem needs and carry it out so the new design copies nothing from the old. Use when a module's design is wrong, after a design review proposes a redesign, or before a feature the current structure makes hard.
---

# Refactor

Change a design without letting the old one leak into the new. Agents write code that looks like the code around them, so the shape a refactor leaves behind is the one every later change copies. Design is more than half of this work.

## Choose the mode

- **Refactor** when the design is sound where it matters and the change can move in steps that each keep the tests green. If the code would be broken for longer than one step, it is not a refactor: stop and choose.
- **Rewrite** when the design is wrong across modules whose patterns interlock, so fixing one module leaves the old shapes in its neighbors for the next agent to copy. A rewrite needs requirements that say what done is, a spec or its acceptance criteria. Without them, write them first with the owner, or refactor. Then follow [rewrite](references/rewrite.md).

Decide from the fix history, the backlog and the requirements, never from reading the code a rewrite would replace. For a refactor, `design-review`'s module review then finds the causes to remove; a concern that spans folders, such as navigation, is scoped by what it does, not by file prefix.

The repo's own rules hold throughout: its commit gate, its docs-with-behavior rule, its glossary. This skill never overrides them. Where docs contradict the code or each other, the owner decides which is right; list each contradiction for them rather than picking one.

## Refactor

1. **Pin the behavior.** Where no test pins what the code does now, write tests at the outermost surface the refactor keeps, such as the app, the CLI or the HTTP API, that assert what it does today, bugs included, before moving anything. These are the tests that stay untouched; a test of an internal the refactor removes goes with that internal, once the outer tests cover what it checked. Where the code judges or transforms input, also run the old and the new code over a table of near-miss cases, each just inside or just outside a rule, and over real files, and diff their outputs.
2. **Make the change easy, then make the easy change.** Before a feature the structure fights, reshape the structure first in its own commits, then add the feature.
3. **Keep structure and behavior in separate commits.** A commit either changes structure, with the pinning tests untouched and green, or changes behavior. Where splitting them would take a shim, the commit changes both and its subject says it changes behavior.
4. **Fix each pattern once, cleanly, in one place first.** Pick the module agents will copy from, give it the right shape in full, and let the rest follow it. Take the shape from `design-review`'s rules, never from the code beside it.
5. **Delete what the new design supersedes in the same change.** Leftover behavior, a second path, a shim or a flag keeping the old way alive is not carried forward. A refactor that removes more than it adds is the good kind; one that adds more is questioned.
6. **Use a codemod for a rule-based change.** A rename, a signature change or a moved import across many files goes through a deterministic tool (the language server, an AST transform), not a model editing file by file.
7. **Review when a part is done, not per slice.** When a module or a pattern is complete, run `design-review` on it as a whole and fix every finding before moving on.
