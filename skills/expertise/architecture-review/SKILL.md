---
name: architecture-review
description: Review whether code keeps the architecture its project documents, finding import cycles, dependency direction the docs forbid, seams built unlike their siblings and contracts that drift across a boundary. Use when a change crosses module boundaries, adds an extension point or touches a shared contract.
---

# Architecture Review

Review whether the code keeps the architecture the project itself states: its documented boundaries, dependency direction, seams and contracts. A design rule that holds whatever the repo chose, such as indirection, YAGNI, cohesion or duplication, belongs to another review area.

## Scope

### 1. Dependency structure

- runtime import cycles across split modules
- dependency direction against the direction the project's docs state
- dependency-injection bags wider than the seams the project declares
- a library module importing a singleton where it should accept an injected parameter; an application reading its own central store is idiomatic

### 2. Extension points

- hard-coded behavior where the project docs or an existing sibling seam establish a policy or config point
- private coupling that blocks the additive providers or plugins the project declares
- an extension seam built differently from its siblings

### 3. Boundary and contract integrity

- a renamed contract term that no longer matches across the boundary, a partial rename included
- an implementation that contradicts a contract or schema the project names as its source of truth
- a function that reads another module's state more than its own; judge one function body at a time by how much of it traverses that module, whether the reference was injected or passed in
- modules reaching into each other's internals instead of through a stated contract

## Evidence threshold

Report a breach only with concrete evidence in the code, a contract or the dependency flow. A read through an injected collaborator, a documented facade or a central store is idiomatic in the architectures built on them, so report one only where it also crosses a boundary the project states.

## Workflow

1. Build the expected architecture map from the project docs.
2. Compare the implementation against that map. When the work is too wide to take in at once and agents are available, give a fast-tier reader each module or boundary to collect raw evidence, and confirm each finding yourself.
3. Run a cycle and dependency-direction pass on the core entry points.
4. Check whether the change adds coupling or makes a contract drift.
5. Report each breach with its evidence.

## Output

Report each boundary breach in the review report shape `principles` holds: **Where** lists the impacted files, **Rule** the stated pattern it breaks, **Why** its evidence and **Instead** the fix direction.

- Bad: "UserService is doing a lot; could be more decoupled." (taste, no contract, no evidence)
- Good: **Why:** `src/api/client.ts` imports `src/auth/session.ts`, which imports it back (runtime cycle), against the api→auth dependency direction in `docs/architecture.md`.

No finding is a valid, complete result.
