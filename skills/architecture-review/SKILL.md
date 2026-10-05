---
name: architecture-review
description: Review whether code keeps the architecture the project states — boundaries, dependency direction, seams and contracts. Use when reviewing module boundaries, extension seams, or contract drift.
---

# Architecture Review

Review whether the code keeps the architecture the project itself states: its documented boundaries, dependency direction, seams and contracts. Design rules that hold regardless of a repo's own choices — indirection, YAGNI, cohesion, duplication — are `design-review`'s.

## Scope

### 1. Dependency structure

- runtime import cycles across split modules
- dependency direction that breaks the direction the project's docs state
- DI bags exceeding the seams the project declares
- singleton imports in library modules that should accept injected params — an application reading its own central store is idiomatic and not this finding

### 2. Extension points

- hard-coded behavior where project docs or an existing sibling seam establish a policy/config point
- private coupling preventing the additive providers or plugins the project declares
- an extension seam built differently from its siblings

### 3. Boundary and contract integrity

- renamed contract terms stay aligned across the boundary; partial renames count as drift
- a contract or schema the project names as source of truth, contradicted by an implementation
- logic that reads another module's state more than its own; judge one function body at a time — how much of it traverses that module — not by whether the reference was injected or passed in
- modules reaching into each other's internals instead of through a stated contract

## Evidence threshold

Only report issues with concrete evidence in code, contracts, or dependency flow. Prefer demonstrated issues over speculative concerns.

An evidenced pattern is not automatically a defect. Reads through an injected collaborator, a documented facade, or a central store are idiomatic in the architectures built on them — flag one only where it also crosses a boundary the project itself states.

## Workflow

1. Build expected architecture map from project docs.
2. Compare implementation against that map. For large diffs or audits spanning many modules, fan out **fast-tier** readers — one per module or boundary — to collect raw evidence. Verify findings in this session before reporting.
3. Run a cycle and dependency-direction pass on core entrypoints.
4. Check whether the change increases coupling or creates contract drift.
5. Report findings ordered by severity.

## Output

For each finding: **label** (Critical / Fix / Consider / Nit — see `review`), **impacted files**, **violated pattern**, **evidence**, **fix direction**.

- Bad: "Consider: UserService is doing a lot; could be more decoupled." (taste, no contract, no evidence)
- Good: **Fix** — `src/api/client.ts` imports `src/auth/session.ts` which imports it back (runtime cycle), violating the api→auth dependency direction in `docs/architecture.md`. Move `TokenStore` into `auth`.

Group as **Confirmed issues** | **Open questions** | **Optional refactors** (max 3, one line each; omit if empty). "No architectural findings" is a valid, complete result.

## See also

- `design-review` for indirection, YAGNI, cohesion and duplication, judged against the owner's rules rather than the repo's
- `simplify` for performing the moves this review identifies

## Red flags

- A finding no project doc, contract or sibling seam supports
- Broad rewrites instead of minimal structural fixes
- Treating taste-level preferences as defects
- Restating a `design-review` finding under Architecture
