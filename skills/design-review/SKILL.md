---
name: design-review
description: Review code against the owner's design rules and say directly what is wrong and what it should be instead; for a whole module, trace its bugs to the design that causes them and propose the smallest redesign, cuts first. Use on files, a diff or a module before accepting it, and instead of fixing a module's bugs one by one.
argument-hint: "<files, diff range, or module>"
---

# Design review

Hold code to the owner's design rules, and state what is wrong and what it should be instead. Findings are stated as findings, never softened into suggestions.

Pragmatism comes first. The rules serve maintainable software; they are not ends in themselves. Build what the problem in front of you asks for, and let an abstraction arrive with its second or third real case, never from principle. A rule applied where it adds structure without solving a problem is misapplied, and a finding that would do that is not raised. Pragmatism is not a shortcut, though: what is built is built properly, with no debt.

Files or a diff get the review below. A whole module, meaning its purpose, its history and a redesign, gets [the module review](references/module.md), which runs this review as one of its steps.

## The rules

- [The patterns](references/patterns.md): Architecture and Code, for all code.
- Rules for particular kinds of code, loaded only when the scope has that kind:
  - [UI](references/ui.md), when the scope renders an interface;
  - [API](references/api.md), when it defines an interface others call, such as a public module, a CLI command, a tool, an endpoint or a schema;
  - [Agent](references/agent.md), when it drives a model.

A diff review checks the Code rules, plus every Architecture rule the diff touches. A module review and a design document check both. Rules about stores, records, transactions and contexts apply only where the scope persists data or crosses a service boundary; a library or a UI package is not judged by them.

Where no rule decides a case, choose what a sensible engineer would choose for this job, and build only what the job needs. A rule is applied for what it achieves. Structure that exists only to look thorough, such as an extra layer, abstraction, check or document, is a finding even when every rule is followed. A preference no rule states is not raised. When a call stays unclear, ask the owner.

## Read

Read every line in scope, and the callers of what it exports: `rg -n '\b<name>\b'` over the source, tests included, because an export only a test imports is itself a finding. A caller outside the scope is cited as another place with the same violation. For each new helper or type in scope, search the repo for the one it duplicates. Read the repo's recorded decisions for the area, wherever it keeps them (decision records, design docs): a finding that contradicts one names the record and why the friction warrants reopening it, or is not raised.

## Judge

For each violation, give:

- **Where:** `file:line`, and every other place with the same violation.
- **Rule:** the rule's heading.
- **Why it is wrong here:** one sentence about this code, not a restatement of the rule.
- **Instead:** the shape the code should take, concrete enough to build from. When the answer is to delete the code, say delete.

When the fix can be a structure, it is one, preferred in this order: a type that cannot hold the bad state, a check that fails the build, one shared helper, a runtime assertion. Agents copy what the surrounding code does, so a weaker guard becomes the next template.

For a fix, name the cause it removes. A change that adds a condition in front of state it leaves in place is a symptom fix, and the finding names that state.

Write short and direct. No "consider", no "might", no praise. When a case is truly unclear, say what would settle it.

Rank the violations in three tiers:

1. A design every new case of the same kind, such as a new technique, page or command, would have to copy.
2. A design that misleads the next writer.
3. Local mess.

A violation that fits two tiers goes in the higher one.

## Report

One heading per tier, with each violation's four fields under it. Then list the rules checked and found clean, with the places each was checked in. A rule is marked clean only after the whole scope was checked, not a sample. No summary paragraph.

## See also

- `review` runs correctness, tests, docs and security on the same change; run it alongside this review
- `test-review` for how the tests are written, and whether they adapt to the change
- `simplify` for the named move that fixes a local smell
- `second-opinion` to challenge a module redesign
- `refactor` to carry out an approved redesign

## Red flags

- A finding softened into "consider" or "might"
- A preference raised that no rule states
- A rule marked clean after reading a sample
- A symptom fix accepted as the fix
- A diff judged without reading the callers of what it exports
- A module redesign that adds more code than it removes, without saying why
