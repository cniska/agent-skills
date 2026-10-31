---
name: refactor
description: Run a refactor in green steps or a rewrite from the requirements, whichever the problem needs, so the new structure copies nothing from the old. Use when a module's design is wrong, after a design review proposes a redesign, or before a feature the current structure makes hard.
---

# Refactor

Change a design so the old one does not leak into the new. Agents write code that looks like the code around them, so every later change copies the shape a refactor leaves behind.

## Choose the mode

- **Refactor** when the design is sound where it matters and the change can move in steps that each keep the tests green. When the code would stay broken for longer than one step, choose again.
- **Rewrite** when the design is wrong across modules whose patterns interlock, so fixing one module leaves the old shapes in its neighbors for the next agent to copy. A rewrite needs requirements that say what done is, such as a spec or its acceptance criteria. When there are none, write them first with the owner, or refactor. Then follow [rewrite](references/rewrite.md).

Decide from the fix history, the backlog and the requirements, since the code a rewrite would replace argues for its own shape. For a refactor, `design-review`'s module review finds the causes to remove. Scope a concern that spans folders, such as navigation, by what it does.

The repo's own rules hold throughout, such as its commit gate, its docs-with-behavior rule and its glossary. Where docs contradict the code or each other, list each contradiction for the owner, who decides which is right.

## Refactor

1. **Pin the behavior.** Where no test pins what the code does now, write tests at the outermost surface the refactor keeps, such as the app, the CLI or the HTTP API, that assert what it does today, bugs included, before moving anything. These tests stay untouched. A test of an internal the refactor removes goes with that internal, once the outer tests cover what it checked. Where the code judges or transforms input, also run the old and the new code over a table of near-miss cases, each just inside or just outside a rule, and over real files, and diff their outputs.
2. **Make the change easy, then make the easy change.** Before a feature the structure fights, reshape the structure in commits of its own, then add the feature.
3. **Keep structure and behavior in separate commits.** A commit either changes structure, with the pinning tests untouched and green, or changes behavior. Where splitting them would take a shim, one commit changes both and its subject says it changes behavior.
4. **Fix each pattern once, in one place first.** Pick the module agents will copy from, give it the right shape in full, and let the rest follow it. Take the shape from `design-review`'s rules, since the code beside it carries the old design.
5. **Delete what the new design supersedes in the same change**: leftover behavior, a second path, and any shim or flag that keeps the old way alive. A refactor that removes more than it adds is the good kind. Question one that adds more.
6. **Make a rule-based change with a deterministic tool.** Run a rename, a signature change or a moved import across many files through the language server or an AST transform, which changes every site the same way.
7. **Review each finished part.** When a module or a pattern is complete, run `design-review` on it as a whole and fix every finding before moving on.
