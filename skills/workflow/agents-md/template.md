# Project Rules

<One sentence: what the project is and its primary runtime/surface.> If a `SPEC.md` or canonical doc is the source of requirements, name it here and say to read it first.

## Architecture

<Module boundaries, entry points, extension points — where to add a new X.> Keep this to a reference line pointing to `docs/architecture.md` when one exists; a long architecture section belongs in a doc humans and agents read on demand, not here.

## Invariants

These must always hold; break them and the system breaks — often silently.

1. <The rule that, if broken, corrupts data or breaks the system in a non-obvious way.>
2. Run `<verify command>` before every commit.

## Workflow

1. <Autonomy stance: default to autonomous; pause only when a decision is ambiguous, risky, or irreversible.>
2. When behavior and tests diverge, fix the implementation — update expectations only if explicitly asked.
3. Commit only when explicitly requested.
4. Keep the spec/canonical doc current — it never lags the code; requirement changes land in the same change.
5. <Landing route: how a reviewed task branch lands — a pull request, or straight onto `main` by fast-forward or merge.>

## Commits

Format: `type(scope): description` — types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`. Single-line subject, no body, ASCII only. Aim under 50 characters, never over 72 (counting the ` (#N)` a squash-merge appends). No issue references or spec IDs in the subject — describe the change; the spec is the reference for why.

## Pull requests

- Gate: run `<review command>` and fix all findings before opening.
- Title: conventional-commit form, under 50 characters, no trailing period; it becomes the squash-merge subject.
- Body follows `.github/pull_request_template.md`: brief motivation (omit when obvious), then a flat summary; cut anything a reviewer would infer from the diff.
- End with `Fixes #N` when an issue matches. Never push or open a PR without approval.

## Code

- No transitional architecture: land the canonical owner, contract, and single source of truth.
- No comments in new or changed code, other than one a tool reads, such as a shebang or a build constraint, and never a suppression, doc comment or tool setting; a *why* goes into a name, type, test or the tool's config.

## Style

- <Formatter and linter of record, with the command to run them.>
- <Naming conventions that deviate from the language default.>

## Docs

- One H1 per doc (page title); H1 title case, H2+ sentence case.
- <Where docs live and when to update them.>

## Testing

- <Command to run the suite.>
- Unit tests are pure — mock boundary effects (filesystem, network, subprocess); integration tests exercise the real wiring.
- Any invariant above that needs a dedicated test gets one (it is not covered by happy-path tests alone).
