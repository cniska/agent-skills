---
name: code-writing
description: Write code whose types tell the truth — parsed boundaries, one empty value, exhaustive closed sets, coded errors — in the owner's stack for each language. Use when writing, changing or reviewing TypeScript, Rust, Python or Dart, starting a project, or choosing a library.
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

3. Read the repo's manifest, toolchain pins and lint config, and match them.
4. Run the repo's declared format, lint, type and test tasks before declaring done.

## Stack and dependencies

- **Match the repo's stack.** Inside an existing project, use what it already uses rather than adding a parallel library; a reference's stack defaults are for starting a project or adding a piece it lacks.
- **Match the repo's config and pins, not its weak spots.** Code nearby that breaks a rule here is flagged, never copied into new code and never rewritten as a side effect.
- **Minimum dependencies.** Every dependency is supply-chain surface. Check whether the standard library or a dependency already in the tree covers the job before adding one, and say why next to a heavier one when it earns its place. A test-only dependency is a dev dependency.
- **Check the installed version, not memory.** A model's memory of a toolchain lags it. Read the installed version's types, changelog or bundled docs before writing an API you recall; each reference lists the drift that already bit.

## Types

- **The empty value is explicit.** A field, return or wire value that can be deliberately empty says so in its type with the language's one empty value (`null`, `None`, `Option`, `T?`). Compare against the empty value the type declares; a compiler does not always catch a comparison against the wrong one.
- **Parse what crosses a boundary.** JSON, env, config, files, another program's output, model responses, rows and request bodies go through a schema at the edge into a typed value, and the type comes from the schema. A cast on parsed data is an unchecked claim that lets a stale hand-written type pass every test.
- **Strict for shapes you own, loose for shapes you don't.** A shape released together with its reader rejects unknown fields, so a renamed field fails on the first read instead of reading as empty. A format owned elsewhere that changes on its own schedule pins only the fields read.
- **Variants are a tagged union**, never a bag of optional fields: a `loading` flag beside an optional result and an optional error admits states that cannot happen.
- **Closed sets are exhaustive.** A match over a closed set covers every member, so a new member fails the build at every match.
- **Make the illegal value unconstructable where the loose type forces a lie.** When a list leads to an unchecked first element or a "cannot happen" error, take a non-empty type; when two fields hold an invariant, store one that cannot break it. Keep the loose type wherever every operation on it is total.
- **No invented defaults.** An empty string, a zero or an empty list substituted because the empty case was unclear hides a missing value. Make the source non-empty, or fail where the caller sees it.

## Modules and errors

- One concern per file, named for that concern.
- Import an item from the module that defines it. A re-export gives it a second path, and its callers split between the two.
- Pass named arguments or an object when arguments could be swapped unnoticed, except on hot paths.
- An error carries a structured code or variant and its facts as fields. Callers branch on that, never on message text.
- The message names the cause and the action that resolves it; an agent may be the one reading it.
- Never catch and continue because the right behavior was unclear. Catch at a boundary that converts the error into the program's output, or for a degradation chosen on purpose: the narrowest type, one line saying why, and a record of what was dropped.

## Testing

- **Wire values as literals.** Pin header names, record fields, codes and printed output as literals; asserting against the imported production constant lets a wrong constant pass.
- **A test that cannot fail is worse than none.** Remove the check it claims to prove and watch it go red.
- **A helper that loops or retries fails at its limit**, with the last state it saw. One that returns quietly turns a stuck run into a pass.
- **A test that accepts several outcomes proves the main one happens.** "Shipped or reported" passes vacuously if nothing ever ships.
- **Unit tests stay offline.** Stub the network and third-party APIs at the boundary; a real end-to-end run against a live service is a separate, opt-in step. Assert the outcome, not that a stub was called.
- **Fixtures copy a format, never real values.**

## Comments

A comment carries only the why: a constraint, a contract the types do not show. A lint or type suppression carries its reason.

## Verification loop

Run the repo's declared tasks, or the reference's commands where it declares none. A failing check is a stop signal, not a warning to silence. Wire format-on-write so the format check is a formality.

## See also

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
- A test helper that returns quietly when it runs out of steps
- A new dependency that duplicates something already in the tree
- An API written from memory that the installed version changed
