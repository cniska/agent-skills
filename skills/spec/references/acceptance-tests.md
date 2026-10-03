# Acceptance tests

The acceptance suite proves the spec's criteria against the built deliverable. A check in the project's own test suite ties the suite and the spec together, so a criterion with no test, a test proving nothing, or a dangling ID fails the build.

## The suite

- **Drive only the public surface.** A test uses the deliverable as its user does — its binary, its HTTP API, its UI — and imports none of its internals.
- **Each test builds its own world.** Its own temporary home, state directory, repositories and ports, so tests run in parallel and share nothing. A test that fails only under concurrency shares state somewhere; find it rather than serialize the suite.
- **Fake only the outer edge.** Replace an external dependency the deliverable calls — a third-party API, a model, a payment provider — with a scripted stand-in that implements its semantics. Never fake one of the project's own modules. Real runs against the real dependency happen before a change lands, outside the suite.
- **Parse every output strictly.** Read each result through a schema that rejects unknown fields, so an added, renamed or retyped field fails a test. Assert wire values — field names, codes, status values — as literals, never through the production constant.
- **One test per criterion,** or one per case when a criterion covers several. A criterion with no test yet is a todo the runner reports, not a silent gap.
- **Its own command and CI job,** apart from the unit suite and the commit gate. A slow suite has a cause; measure and fix it rather than run it less.

## Citations

- An acceptance test's name starts with the IDs of the criteria it proves: `AC-15 cancelling mid-build removes the workspace`. Unit tests describe behavior and cite no ID.
- Each criterion in the spec ends with the requirements it exercises, in parentheses: `(FR-27, FR-86)`.

## The check

A test in the project's suite reads the spec and the acceptance test files, and fails when:

- an acceptance test's name cites no criterion, or cites one the spec does not hold;
- a criterion has neither a test nor a todo;
- an ID is not a family and a whole number, or a family is not numbered from 1 without gaps;
- a criterion cites no requirement, or one the spec does not hold;
- an FR, NF or domain-family requirement is cited by no criterion.

Before relying on it, break the spec once for each condition above and watch the check fail.

With the check in place, a new requirement may sit beside a related one and a removed one is deleted rather than retired; the IDs after either are renumbered in the same change as every citation.
