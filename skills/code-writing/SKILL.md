---
name: code-writing
description: Write code whose types tell the truth — parsed boundaries, one empty value, exhaustive closed sets, coded errors — in the owner's stack for each language. Use when writing, changing or reviewing TypeScript, Rust, Python, Dart or shell, starting a project, or choosing a library.
---

# Code writing

Write code whose types are true at runtime and whose failures are loud. The rules here hold in every language; each language's reference holds its toolchain, its stack and the pitfalls a model gets wrong in it.

The repo's own `CLAUDE.md` or `AGENTS.md` overrides anything here.

## Always do first

1. Read the repo's `CLAUDE.md` / `AGENTS.md`. They override this skill.
2. Read the reference for the language you are writing, before the first edit:

   | Language | Reference |
   |---|---|
   | TypeScript | [references/typescript.md](references/typescript.md) |
   | Rust | [references/rust.md](references/rust.md) |
   | Python | [references/python.md](references/python.md) |
   | Dart | [references/dart.md](references/dart.md) |
   | Shell | [references/shell.md](references/shell.md) |

3. Read the repo's manifest, toolchain pins and lint config, and match them.
4. Run the repo's declared format, lint, type and test tasks before declaring done.

## Stack and dependencies

- **Match the repo's stack.** Inside an existing project, use what it already uses rather than adding a parallel library; a reference's stack defaults are for starting a project or adding a piece it lacks.
- **Match the repo's config and pins, not its weak spots.** Code nearby that breaks a rule here is flagged, never copied into new code and never rewritten as a side effect.
- **Minimum dependencies.** Every dependency is supply-chain surface. Check whether the standard library or a dependency already in the tree covers the job before adding one, and say why next to a heavier one when it earns its place. A test-only dependency is a dev dependency.
- **Size the structure to the program.** A small tool stays in a few files and takes no dependency for what a few lines of its own cover; split a file or add a library when a concern actually grows, not in anticipation. Build what was asked: no unrequested flags, output modes or storage layouts.
- **Check the installed version, not memory.** A model's memory of a toolchain lags it. Read the installed version's types, changelog or bundled docs before writing an API you recall; each reference lists the drift that already bit.

## Types

- **The empty value is explicit.** A field, return or wire value that can be deliberately empty says so in its type with the language's one empty value (`null`, `None`, `Option`, `T?`). Compare against the empty value the type declares; a compiler does not always catch a comparison against the wrong one.
- **Parse what crosses a boundary.** JSON, env, config, files, another program's output, model responses, rows and request bodies go through a schema at the edge into a typed value, and the type comes from the schema. With no schema library in the tree, a small hand-written parser into the language's own types and the package's coded error does the same job; adding a library for one shape is a dependency decision. A cast on parsed data is an unchecked claim that lets a stale hand-written type pass every test.
- **Strict where a typo would change behavior, loose where the format evolves without you.** A shape released together with its reader, and a config file a person writes by hand, rejects unknown fields, so a renamed or misspelled field fails on the first read instead of reading as empty. Another system's export or response is loose even when a user hands over the file: pin only the fields read, type each one strictly, and keep its values as that system spells them.
- **Several empties in a foreign format map to the one empty value at the parser.** A format that sends `null`, `""` or an absent key for the same thing is normalized once, at the edge; whether an absent key means empty or is a refusal comes from what the format documents, pinned by a test. Normalizing a documented equivalence is not an invented default.
- **Variants are a tagged union**, never a bag of optional fields: a `loading` flag beside an optional result and an optional error admits states that cannot happen.
- **Closed sets are exhaustive.** A match over a closed set covers every member, so a new member fails the build at every match.
- **Make the illegal value unconstructable where the loose type forces a lie.** When a list leads to an unchecked first element or a "cannot happen" error, take a non-empty type; when two fields hold an invariant, store one that cannot break it. Keep the loose type wherever every operation on it is total.
- **No invented defaults.** An empty string, a zero or an empty list substituted because the empty case was unclear hides a missing value. Make the source non-empty, or fail where the caller sees it.

## Configuration

- Config is read in one module, with defaults in one place, and validated at startup: a bad value refuses to start rather than failing at request time, and every problem is reported at once.
- Environment variable names carry the tool's prefix (`TOOL_LOG`, not `LOG`).
- The committed example config is parsed by a test, so the example cannot drift from the schema.

## Modules and errors

- One concern per file, named for that concern.
- Import an item from the module that defines it. A re-export gives it a second path, and its callers split between the two.
- Pass named arguments or an object when arguments could be swapped unnoticed, except on hot paths.
- An error carries a structured code or variant and its facts as fields. Callers branch on that, never on message text. A program's entry point maps the code to its exit status or response in one place.
- **What crosses a trust boundary is a stable, public-safe code.** A server's response, or anything answering a party other than the operator, carries the code and a fixed message, never a path, an upstream response, a stack trace or an interpolated value; the detail goes to the log, and a test pins that the response omits it. A local tool answering its own user is not across a boundary: naming the user's own file is what makes its error useful.
- The message names the cause and the action that resolves it; an agent may be the one reading it.
- Never catch and continue because the right behavior was unclear. Catch at a boundary that converts the error into the program's output, or for a degradation chosen on purpose: the narrowest type, one line saying why, and a record of what was dropped.

## Command-line programs

- The result goes to stdout; diagnostics and errors go to stderr.
- Exit 0 is success, 1 a failure, 2 a usage error. Help asked for goes to stdout and exits 0.
- A machine-readable switch (`--json`) prints one fixed shape, and its errors still go to stderr.
- An unexpected error prints its message, not a stack trace.

## Testing

- **Crucial logic is test-first.** Parsers, auth, signing and fail-closed paths get their failing test before the code.
- **Wire values as literals.** Pin header names, record fields, codes and printed output as literals; asserting against the imported production constant lets a wrong constant pass.
- **A test that cannot fail is worse than none.** Remove the check it claims to prove and watch it go red.
- **A helper that loops or retries fails at its limit**, with the last state it saw. One that returns quietly turns a stuck run into a pass.
- **A test that accepts several outcomes proves the main one happens.** "Shipped or reported" passes vacuously if nothing ever ships.
- **Unit tests stay offline.** Stub the network and third-party APIs at the boundary; a real end-to-end run against a live service is a separate, opt-in step. Assert the outcome, not that a stub was called.
- **A refusal test proves the side effect did not happen.** Assert the upstream saw no request, the file was not written, the row was not inserted, and pair it with a positive control showing the admitted case does happen.
- **A test seam is switched on at build time, never by a runtime variable.** Code that exists only for a test is compiled in by a build flag, cargo feature or bundler define, absent from what ships. An environment variable the shipped code reads to enable a test path is a back door; a harness pointing `HOME` or a tool's config path elsewhere is ordinary isolation.
- **Fixtures copy a format, never real values.**

## Rules as checks

A rule the code must keep is a check, not a sentence. A sentence is read differently by each agent and contributor, and only a reviewer catches a breach; a check fails the same way for everyone, on every commit.

- Take the strongest form that can hold the rule: a type that cannot represent the wrong state, then a rule the configured linter already has, then a test in the suite that scans the source, then a hook or CI step. A rule that covers only new and changed code scans the lines a diff adds, not the whole tree.
- Break the rule once and watch the check go red before wiring it in.
- When a review catches a breach of a mechanical rule, the fix adds the check that would have caught it.
- Prose in `AGENTS.md` or a skill keeps what needs judgment: naming, scope, design.

## Comments

Code carries no comments. A why goes into a name, a test, or the doc that owns the subject. A ban is a rule a check can hold, where "only the why" is one more sentence to judge.

- A tool directive is not a comment: a lint or type suppression, or Rust's `// SAFETY:`. It carries its reason on the directive's own line.
- Doc comments stay only on the public API of a package published to a registry, where the doc tool renders them as the package's documentation. Elsewhere a doc comment explains what a better name, type or test should say; fix that instead.
- The ban covers source code. A config file (TOML, YAML, a CI workflow) may carry a reason comment, since it has no name or test to hold one.
- A comment on a line the change touches goes with it, its why moved first. Comments elsewhere are left for a change of their own.

## Verification loop

Run the repo's declared tasks, or the reference's commands where it declares none. A failing check is a stop signal, not a warning to silence. A check that cannot run, because a tool or registry is unavailable, is reported as unrun, never worked around by dropping it or installing from an unvetted source; tests written but never run count as unwritten. Wire format-on-write so the format check is a formality.

## See also

- `tdd` for crucial logic driven test-first
- `test-writing` for tests that are proven able to fail
- `database-design` for schemas the types are parsed from

## Red flags

- Writing in a language without having read its reference
- A cast on parsed JSON, env, rows or another program's output
- A hand-written guard where the repo's schema library could parse the shape
- A state type built from a flag and optional fields
- A deliberately empty value spelled as an absent field, or compared against the wrong empty value
- A default substituted for a value whose emptiness is a bug
- Branching on an error's message text
- A comment in the change that is neither a tool directive nor a published package's public doc comment
- A mechanical rule written into `AGENTS.md` or a skill where a type, lint or test could hold it
- A test helper that returns quietly when it runs out of steps
- A refusal test that asserts the error but not that nothing happened
- A test-only path switched on by an environment variable
- An error response carrying a path, a stack trace or an upstream message
- A gate reported as passing that never ran
- A new dependency that duplicates something already in the tree
- An API written from memory that the installed version changed
