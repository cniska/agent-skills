---
name: code-writing
description: Write code whose types hold at runtime and whose failures are loud — parsed boundaries, one empty value, exhaustive closed sets, coded errors — in the owner's stack for each language. Use when writing, changing or reviewing TypeScript, Rust, Python, Dart, Swift, shell or a CI workflow, starting a project, or choosing a language or a library.
---

# Code writing

Write code whose types are true at runtime and whose failures are loud. The rules here hold in every language. Each language's reference holds the pitfalls a model gets wrong in it, and the toolchain and stack to suggest for a project that has not chosen. The repo's own rules file overrides anything here.

## Before the first edit

1. Read the reference for the language you are writing:

   | Language | Reference |
   |---|---|
   | TypeScript | [references/typescript.md](references/typescript.md) |
   | Rust | [references/rust.md](references/rust.md) |
   | Python | [references/python.md](references/python.md) |
   | Dart | [references/dart.md](references/dart.md) |
   | Swift | [references/swift.md](references/swift.md) |
   | Shell | [references/shell.md](references/shell.md) |

2. Before writing a new program, adding a file in a language the repo does not hold yet, pinning a toolchain or adding a dependency, read [stack](references/stack.md).
3. Read the repo's manifest, toolchain pins and lint config, and match them.
4. Write each test as `test-writing` says. Before calling the work done, run the repo's declared format, lint, type and test tasks. Run a test suite, and any command that may hang, under [`scripts/bounded`](scripts/bounded): `bounded <seconds> <command> [args...]` ends the command's whole process group at the deadline and exits 124.

## Stack

- **Match the repo's stack.** Inside an existing project, use the library it already uses for a job. A reference's stack defaults are for starting a project or adding a piece it lacks.
- **Match the repo's config and pins, not its weak spots.** Flag nearby code that breaks a rule here. Write new code to the rule, and leave the old code for a change of its own.
- **Size the structure to the program.** A small tool stays in a few files and writes its own few lines instead of taking a dependency for them. Split a file or add a library when a concern actually grows. Build what was asked, with only the flags, output modes and storage layouts the request names.
- **Read and edit files with the harness's file tools.** Hooks that check or record edits fire on those tools, and the shell keeps no record of what a file looked like, so a concurrent write is silently overwritten. Open a file with the file-read tool before editing it, since an edit to a file read only through the shell is refused. A mechanical edit across many sites may go through a script; then re-read the changed files and run the repo's checks.
- **Check the installed version, not memory.** A model's memory of a toolchain lags it. Before writing an API from memory, read the installed version's types, changelog or bundled docs. Each reference lists the drift that already bit.

## Types

- **The empty value is explicit.** A field, return or wire value that can be deliberately empty says so in its type with the language's one empty value (`null`, `None`, `Option`, `T?`). Compare against the empty value the type declares, since a compiler does not always catch a comparison against the wrong one. A read that may find nothing returns the empty value. The caller that knows the thing must exist turns it into a coded error through a twin such as `loadOrThrow`.
- **Parse what crosses a boundary.** JSON, env, config, files, another program's output, model responses, rows and request bodies go through a schema at the edge into a typed value, and the type comes from the schema. A schema library pays for itself on a format another program defines and may change. A repo whose own formats are small and fixed takes a small hand-written parser into the language's own types and the package's coded error, since adding a library for one shape is a dependency decision. Once a schema library is in the runtime tree, it parses every boundary, the repo's own rows included. Take the type from the parse: a cast on parsed data, including a type parameter on a query that nothing checks, lets a stale hand-written type pass every test, and a hand-written type beside a schema of the same shape is a second source of truth. Past the boundary, types state exactly what holds: an id or a time is its own type, not a bare string, and validation is not repeated below the edge.
- **Strict where a typo would change behavior, loose where the format evolves without you.** A shape released together with its reader, and a config file a person writes by hand, rejects unknown fields, so a renamed or misspelled field fails on the first read instead of reading as empty. Another system's export or response is loose even when a user hands over the file: pin only the fields read, type each one strictly, and keep its values as that system spells them.
- **Map a foreign format's several empties to the one empty value at the parser.** A format that sends `null`, `""` or an absent key for the same thing is normalized once, at the edge. Whether an absent key means empty or is a refusal comes from what the format documents, pinned by a test. Normalizing a documented equivalence is not an invented default.
- **Variants are a tagged union**, one member per state holding only that state's fields. A `loading` flag beside an optional result and an optional error admits states that cannot happen.
- **Closed sets are exhaustive.** A match over a closed set covers every member, so a new member fails the build at every match.
- **Make the illegal value unconstructable where the loose type forces a lie.** When a list leads to an unchecked first element or a "cannot happen" error, take a non-empty type. When two fields hold an invariant, store one that cannot break it. Keep the loose type wherever every operation on it is total.
- **Immutable by default.** A change produces a new value. A concept defined by its value, such as an id, a time, an amount or a range, is a value object: validated when built and compared by value. Mutation stays inside a store and an aggregate's commands.
- **No invented defaults.** Make the source non-empty, or fail where the caller sees it, because an empty string, a zero or an empty list put in when the empty case was unclear hides a missing value. A default exists only where one value is right for everyone, such as a port. A value that chooses for the user, such as a vendor or a model, is required.

## Configuration

- Read config in one module, with defaults in one place, and validate it at startup: a bad value refuses to start rather than failing at request time, and every problem is reported at once.
- Prefix environment variable names with the tool's name (`TOOL_LOG`, not `LOG`).
- Parse the committed example config in a test, so the example cannot drift from the schema.

## Modules and errors

- One concern per file, named for that concern.
- Import an item from the module that defines it. A re-export gives it a second path, and its callers split between the two.
- Pass named arguments or an object when arguments could be swapped unnoticed, except on hot paths.
- A function reads top to bottom: guards return early, and the main path sits at the lowest indentation. Write a choice among more than two values as a match, exhaustive over a closed set, or as an `if` chain where the values form no closed set, rather than nested ternaries. Split a function that fetches, decides, writes and formats at those seams, and extract and name a fragment whose purpose takes effort to see, even with one caller.
- A literal with a meaning is a named module-level constant, grouped with its kin and defined once. Build a set, regex or lookup once, not on every call. Take a limit, timeout or threshold from a measurement or an external contract.
- A write returns the record it wrote. An update that matched nothing is a coded error, and a failed write raises.
- Before adding an error, define the operation so the case cannot arise where that is honest: removing what is already gone succeeds, and a query with no match returns an empty list.
- An error carries a structured code or variant and its facts as fields, built through one constructor per module so every throw has the same shape. Callers branch on the code. A program's entry point maps each code to its exit status or response in one table keyed by every code, so a new code fails the build until it says how it prints.
- **What crosses a trust boundary is a stable, public-safe code.** A server's response, or anything answering a party other than the operator, carries the code and a fixed message. The path, upstream response, stack trace or interpolated value goes to the log, and a test pins that the response omits it. A local tool answering its own user is not across a boundary: naming the user's own file is what makes its error useful.
- The message names the cause and the action that resolves it, since an agent may be the one reading it.
- Catch an error only where you have decided what happens next. Catch at a boundary that converts the error into the program's output, or for a degradation chosen on purpose: the narrowest type, a name that says it degrades, and a record of what was dropped. Below the boundary, a catch only undoes a side effect and rethrows the same error, or lets a store translate the constraint that fired into its module's code. An expected case is a return value. Work off the success path, such as a trace write, and a part loaded beside its siblings, such as a plugin, is an edge of its own: contain its failure to that part, log it, and count it where status shows it.

## Command-line programs

- A program with options or subcommands, a usage text, or exit statuses beyond success and failure, such as a usage error or a code its callers branch on, is a command-line program. Write it in a reference language other than shell, unless it is runner-fixed as [stack](references/stack.md#language) defines it.
- The result goes to stdout; diagnostics and errors go to stderr.
- Exit 0 is success, 1 a failure, 2 a usage error. Help asked for goes to stdout and exits 0.
- A machine-readable switch (`--json`) prints one fixed shape, and its errors still go to stderr.
- An unexpected error prints its message only.

## CI workflows

- Pass a step's inputs and expressions to its script through `env:`, so they reach it as data. An expression written inside `run:` is pasted into the script as code.

## Testing

- **Write crucial logic test-first.** Parsers, auth, signing and fail-closed paths get their failing test before the code.
- **A test that accepts several outcomes proves the main one happens.** "Shipped or reported" passes vacuously if nothing ever ships.
- **A refusal test proves the side effect did not happen.** Assert the upstream saw no request, the file was not written, the row was not inserted, and pair it with a positive control showing the admitted case does happen.
- **Switch a test seam on at build time.** Code that exists only for a test is compiled in by a build flag, cargo feature or bundler define, and is absent from what ships, because an environment variable the shipped code reads to enable a test path is a back door. A harness pointing `HOME` or a tool's config path elsewhere is ordinary isolation.

## Principles

Load `principles` and apply six of them to every change: no comments, mistake-proofing, no text heuristics, proven able to fail, fix the cause, and no drift.

## Verification loop

Run the repo's declared tasks, or the reference's commands where it declares none. Treat a failing check as a stop. Report a check that cannot run, because a tool or registry is unavailable, as unrun, and count tests written but never run as unwritten. Wire format-on-write so the format check is a formality.

- **Fix the code a rule flags.** When a linter, type checker or analyzer rule flags code, rewrite the code. Turn a rule off in the project's config, for the whole project or one directory, only when no rewrite satisfies it without making the code worse, such as one whose fix is a comment that no comments forbids. Name it there with why, where the project documents its lint. Adopting a linter, or raising its strictness, turns its rules on and fixes the hits. Keep suppression comments out of source. A language whose reference names a per-site form uses that form under the same test.
