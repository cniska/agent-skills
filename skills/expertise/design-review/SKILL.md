---
name: design-review
description: Review code against the owner's design rules and say directly what is wrong and what it should be instead; for a whole module, trace its bugs to the design that causes them and propose the smallest redesign, cuts first. Use on files, a diff or a module before accepting it, and instead of fixing a module's bugs one by one.
---

# Design review

Hold code to the owner's design rules, and state what is wrong and what it should be instead. Files or a diff get the review below. A whole module, meaning its purpose, its history and a redesign, gets [the module review](references/module.md), which runs this review as one of its steps.

## The rules

- [The patterns](references/patterns.md): Architecture and Code, for all code.
- The shared principles in `principles`, which a finding cites by name: fix the cause, no transitional architecture, no drift, Chesterton's Fence, no comments, mistake-proofing and no text heuristics.
- Rules for particular kinds of code, loaded only when the scope has that kind:
  - [UI](references/ui.md), when the scope renders an interface;
  - [API](references/api.md), when it defines an interface others call, such as a public module, a CLI command, a tool, an endpoint or a schema;
  - [Agent](references/agent.md), when it drives a model.

A diff review checks the Code rules, plus every Architecture rule the diff touches. A module review and a design document check both. Rules about stores, records, transactions and contexts apply only where the scope persists data or crosses a service boundary, so a library or a UI package is not judged by them.

## What matters

- **Pragmatism first.** The rules serve maintainable software. Build what the problem in front of you asks for, and let an abstraction arrive with its second or third real case. Raise a finding only where the rule solves a problem here, since a rule applied for its own sake adds structure. What is built is built properly, with no debt.
- **Judge by what a rule achieves.** Where no rule decides a case, choose what a sensible engineer would choose for this job, and build only what the job needs. Structure that exists only to look thorough, such as an extra layer, abstraction, check or document, is a finding even when every rule is followed. Leave out a preference no rule states. When a call stays unclear, ask the owner.
- **Respect settled decisions.** Read the repo's recorded decisions for the area, wherever it keeps them. A finding that contradicts one names the record and why the friction warrants reopening it. Without that reason, leave the finding out. A finding that clashes with a decision the owner settled in the brief goes to the owner as a conflict. The coordinator settles how the work runs, and the owner settles its design.

## Read

Read every line in scope, and the callers of what it exports, tests included, because an export only a test imports is itself a finding. Cite a caller outside the scope as another place with the same violation, which the review report in `principles` says when to fix.

For each new helper in scope, search the whole repo, tests and fixtures included, for its name and for the call it wraps, such as the call that makes a temporary directory. For each new type, search for its fields or shape. A helper or type that duplicates an existing one is a finding.

## Judge

- **Give each violation as a finding** in the review report shape `principles` holds. Its **Why** says why the code is wrong here, in one sentence about this code rather than a restatement of the rule. Its **Instead** is the shape the code should take, concrete enough to build from, and says delete when deleting the code is the answer.
- **Make the fix a structure where it can be one**, in this order: a type that cannot hold the bad state, a check that fails the build, one shared helper, a runtime assertion. Agents copy what the surrounding code does, so a weaker guard becomes the next template.
- **Name the cause a fix removes**, as fix the cause in `principles` says. A symptom fix's finding names the state it leaves in place.
- **State findings plainly.** Write each as a finding, short and direct, without "consider", "might" or praise. When a case is truly unclear, say what would settle it.
- **Order the findings by reach**: first a design every new case of the same kind, such as a new technique, page or command, would have to copy; then one that misleads the next writer; then local mess. Every finding is fixed, whatever its place.

## Report

Report in the review report shape from `principles`.
