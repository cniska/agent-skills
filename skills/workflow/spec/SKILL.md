---
name: spec
description: Create and maintain a specification that states what to build, not how, in labelled requirements traced to acceptance criteria and tests. Use when writing a spec, editing requirements, or defining acceptance criteria.
---

# Spec

A spec states what must be true and leaves how to the code and the architecture docs, where algorithms, API calls, data structures and byte offsets live. Make it complete enough to reimplement from and precise enough to verify against, so every requirement is a claim someone can later prove or disprove. Write it as `writing` says for documents that last.

Draft a spec from a rough idea or a design conversation, supplying the structure so the owner describes intent rather than format. Or refine one that exists: add requirements, move out the how that crept in, and cross-check it against the code. A spec may start with a handful of requirements and grow one change at a time, since the ID rules below keep later growth safe.

## Labelled requirements

Every requirement gets an ID: a short family prefix and a number, such as `FR-12`, `NF-3` or `AC-9`. Acceptance criteria cite the requirements they verify, acceptance tests cite the criteria they prove, and cross-references point by ID rather than by prose. Every spec has an acceptance suite and a check that ties it to the spec, set up as [acceptance tests](references/acceptance-tests.md) says.

The core families are below. Add a domain family where the project needs one, such as `ST` for styling, `AU` for auth or `SEC` for security.

- **FR**, functional: what the tool does.
- **NF**, non-functional: performance, reliability, error behavior and testing.
- **AC**, acceptance criteria: the conditions that together mean done.
- **D**, deliverables: the artifacts that must ship.
- **C**, constraints: fixed decisions the builder may not revisit, such as language, runtime, distribution and hard exclusions. Step 4 draws the line against conventions.

The rules:

- **Renumber with every citation.** A new item may sit beside a related one, and a removed one is deleted. The IDs after either are renumbered in the same change as every citation, in the spec, its tests and any other file that cites one, so the check finds no gap and no dangling ID.
- **Give each ID a whole number.** An ID is a family prefix and a whole number. A change that meets a sub-numbered ID, such as `FR-21a` or `FR-21.1`, renumbers it away.
- **One claim per ID.** A requirement with two claims that can be verified apart is two requirements.
- **Earn each family and each ID.** Give a dimension its own family only when it carries distinct claims that can be verified apart, rather than functional surface that fits under FR. Aim for a spec you could reimplement from, not an inventory. When two readers would land far apart on the requirement count, the spec is listing mechanism rather than contract.

## Workflow

1. **Gather intent.** For a new spec, read the reference the owner points to and the conversation so far. For an edit, read the current spec in full. Resolve what is still ambiguous by asking one question at a time, each with your recommended answer. When the source is an existing codebase rather than a design conversation, draft as [from code](references/from-code.md) says.
2. **Cross-check against the code**, where it exists. Every shipped behavior needs a requirement, and every requirement needs a way to verify it. List the real surface from the source, such as CLI flags, config format and error paths, rather than from memory. A requirement the code contradicts is stale, so reconcile it.
3. **Draft from the [template](references/template.md)**, assigning IDs as you go. The draft is done when every section is filled or marked not applicable.
4. **Sort what from how.** A sentence naming an algorithm, a request shape or an offset is how. Move it to the architecture doc, and leave the requirement stating only the observable outcome. A fixed decision stays under Constraints only when reversing it would force a rewrite or change what the deliverable is, such as language, runtime, distribution form or a hard exclusion like no telemetry. A decision a tool could re-apply mechanically with every AC still passing, such as the formatter, lint rules or indent width, is a convention, and it goes in the repo's rules file. A default the user observes, such as a default port or a timeout, is a requirement. The internal tuning value behind the same behavior is an open decision.
5. **Make edge cases requirements.** The constructs a naive build gets wrong each get their own ID, so each earns its own test.
6. **Separate constraints from open decisions.** Close with two explicit lists: what is fixed, and what is left to the builder. Scope disputes grow in whatever neither list covers.
7. **Close the traces.** Each AC cites the requirements it exercises and exercises every case, clause and surface each of them names. Every FR, NF and domain-family requirement is cited by at least one AC; deliverables and constraints are not cited. Before the first review and again after each fix, list each added or modified requirement's cases against the criteria that test them. A case no criterion tests, or an AC that verifies nothing, is a gap to fix before the spec is done.

## Editing an existing spec

Before touching the spec, write the change as a delta of IDs: what is added, modified and removed, and which traces it moves, meaning which ACs gain or lose a requirement.

```
REMOVED FR-9; FR-10..FR-37 → FR-9..FR-36; ADDED FR-37; MODIFIED FR-11 (narrowed); AC-4 now also cites FR-37
```

The delta names a removed ID by its old number, then the renumbering that a removal or an inserted item causes, and every other ID by its new number. It needs no document of its own, and the spec stays a statement of the current contract. Put load-bearing rationale in the PR description or an ADR, and keep the spec to the contract itself. A policy's `serves FR-x` pointer is the one exception, since it is a trace to the requirement the policy serves.
