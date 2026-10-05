# Design patterns

The rules `design-review` holds all code to. A violation is a finding, and in a module review it is a cause. Rules for particular kinds of code are in `ui.md`, `api.md` and `agent.md`; how tests are written belongs to `test-review`.

# Architecture

## Size everything to the need

Build what the job needs now (YAGNI). YAGNI covers capabilities, not the code's health: a refactor that makes the code easier to change is never speculation. A feature, command, table, option or extension point with no current use goes, however much work went into it; when the need arrives, it is built then. Anything beyond the need is speculation, and speculation is usually the wrong design, because the need that should shape it has not arrived yet. A fix is sized to its problem: small when the problem is small, a redesign when the design is the cause. Before removing something, find out why it exists (Chesterton's fence); if the reason no longer holds, it goes.

Spot it:

- speculative generality
- a lazy class or module that does too little to exist
- a command, query or export nothing calls
- an option nobody sets
- support for a case the project does not have

## A known pattern for a known problem

Where a known problem is present, use the established pattern by its name, in its plain form: a registry for variants added in one place, a pipeline for ordered phases, a policy for a swappable rule, effect handlers for side effects, a queue for queued work, a state machine for a lifecycle, a store for an aggregate's persistence, a factory for construction. Name the file for the pattern (registry, pipeline, policy, effects, queue, store), in the language's file-name case. Build it from functions and data; use a class only where state and behavior truly belong together. Where the problem is not present, neither is the pattern.

An extension point is the one exception to "no second implementation yet": where a library declares a seam for users to plug in a store, transport or tool, a minimal interface is built, and its second implementation is not.

Spot it:

- a pattern or interface with a single implementation, outside a declared extension point
- a class hierarchy where one function would do
- a builder for an object with three fields
- a known pattern under a made-up name
- a known problem solved ad hoc, such as three copies of a variant list with no registry, or phases run as nested calls instead of a pipeline

## One mechanism per question

Each question is decided in one place: one admission per act, one source of truth per fact, one type per concept. A second mechanism beside the first drifts from it, and every new case must then be added to both.

Spot it:

- checks inside writers that an earlier admission already made
- a refusal whose only caller has already decided the condition
- a lookup whose only job is to map one union onto another
- a flag passed alongside the record it could be read from
- a value computed in two ways, or the same state read two ways
- information leakage: one format, path layout or wire shape known by two modules, so changing it takes coordinated edits

## Each module has a public API

A module's public API is the small set of files the repo marks as public, such as its rules and its contract. Everything else in the module, such as its store, its helpers and the files for its parts, is internal and imported only from inside the module. Other modules use the public API alone. The one re-export is the language's own way of marking a package's surface, such as a Dart library file over `lib/src/` or a crate root; inside the package nothing gets a second path.

Spot it:

- an import of another module's store or internal file
- a module whose callers reach into several of its files for one job
- a re-export giving an internal a second path, beyond the package's one surface file

## Bounded contexts

A system splits where its domain splits, into contexts that each own their model, their language and their storage (domain-driven design's bounded context). A context never reads or writes another's tables or internals. It uses the other's published interface, and where the same word means different things on each side, the boundary translates between them. Contexts are drawn only where the domain truly divides; a small system may be one.

The interface between two contexts is an explicit contract. What crosses it is a data transfer object (DTO), a shape of its own and never a domain model or a stored row serialized as it is, so the model can change without breaking a consumer. Its types and schema live in the providing context's contract file, the consumer parses what crosses the boundary against that schema, and a test pins the contract's wire values as literals, so a change on one side fails on the other before it ships. A change to a contract updates every consumer in the same change. Where consumers ship separately, such as a client of a daemon, the contract carries a version checked on connect, and a mismatch is refused, never bridged.

Spot it:

- a query in one context against another context's tables
- one context importing another's internal types instead of its contract
- data crossing a boundary with no schema, or parsed on one side only
- a domain model or a row returned as it is from an endpoint, a CLI command or a tool
- a contract with no test pinning its shape
- a word whose meaning changes depending on which module uses it, with nothing translating at the boundary

## One name per concept

Within a context, a concept has one name in types, functions, tables, CLI output, docs and prompts: the ubiquitous language of domain-driven design. The name comes from the domain, from how the work is talked about, not from the implementation. Where the repo keeps a glossary, the name is settled there before it appears in code. A synonym is renamed to the settled word, never kept beside it.

Spot it:

- two names for one thing
- a type, a table and a doc naming one concept differently
- an implementation word standing in for a domain word

## One place to add a variant

Adding a value to an axis the code varies on touches one place, which holds the variant and its metadata together. A variant declares where it applies, as data on itself, and the runner filters on it. A variant that checks the mode or the caller inside its own body, or a rule with a carved-out exception, marks the axis as wrongly designed.

Spot it:

- shotgun surgery: one change touching many files
- parallel lists or maps keyed by the same names
- metadata kept apart from the thing it describes
- a variant branching on the mode or caller inside itself

## One reason to change per module

A module gathers what changes for the same reason and separates what changes for different reasons (the single responsibility principle). A file holds one concern and is named for it. A catch-all is a set of modules that never got split.

Spot it:

- divergent change: one file edited for unrelated reasons, such as a schema change and an output format change
- a catch-all file (`utils`, `helpers`, `common`), or a file whose name no longer covers what it holds

## Three layers, used in order

UI parses input, calls the business layer and renders the result. The business layer (aggregates and their commands) holds the rules. Persistence (stores over the database, the filesystem, processes and external services) holds every query and side effect. Each layer uses only the one below it, and nothing skips a layer. A layer exists only where it separates a real concern; one that only forwards is indirection. A generic module, such as errors, events or a lifecycle, knows no feature's names.

Files group by domain noun, never by layer: flat with the module as prefix, or one folder per module, whichever the repo already does. The layer shows in the file name the way the repo declares it, such as a suffix for the contract, the store and the command, and a separate app gets its own folder. Code the product does not run, such as a benchmark or an admin script, lives apart from it.

Spot it:

- a query outside a store
- a command or view that imports a store
- business rules in a command or a view
- a generic module importing a feature's names
- temporal decomposition: phase modules that each re-know the same format or rule, where the steps of a real pipeline own different knowledge

## Pure decisions, separate effects

Logic that decides is a pure function (functional core, imperative shell): it takes the state it needs and returns a result, or a description of what should happen, such as an event to record or a command to run. It reads no clock, file, database, environment or process, and it changes nothing. Effects run in one place, a handler at the edge that carries out what the pure code described and holds no rules. The same inputs always give the same output, so the core is tested without mocks and read from its signature.

Spot it:

- a function that both decides and writes, such as an `if` beside an `INSERT` or a check beside a `spawn`
- a rule that reads the clock or the environment itself instead of receiving them
- a decision that needs a mock to test
- a side effect inside a helper whose name sounds pure (`validate…`, `compute…`)
- a poll for a state its source could emit

## Records are not models

A stored row and a domain model are different types, and one mapping in the store converts between them. An aggregate root owns its parts, is loaded and saved through one store, and changes only through its commands, which record domain events. The aggregate is the consistency boundary: one transaction changes one aggregate, another aggregate is referenced by its id and never held, and a change that must follow in another aggregate is driven by a domain event. An entity is identified by its id, not by its fields. The domain generates an entity's id before it is written; a store never mints one. Rows that must agree are written in one transaction. Where they live in stores that share no transaction, the new copy is written before the old one goes, and the write is idempotent on the id, so an interrupted run leaves a duplicate the next run finishes, never a loss.

Spot it:

- a row type used in logic
- nullable fields the table ties to a kind
- `as` casts in readers
- an autoincrement or row id used as the domain id
- two writes that must both land, outside a transaction
- one transaction changing two aggregates, or one aggregate holding another instead of its id
- a delete of the source before its copy is confirmed

## Shared fields plus typed details

A record with variants keeps the fields every variant has, plus one details object its kind decides. `code-writing` states the rule; these are its symptoms.

Spot it:

- a type or table with many optional fields; count which fields each kind actually sets
- a temporary field set only in some states
- fields whose valid combinations take a sentence to explain, such as a `done` flag beside an optional `doneAt` time
- a boolean that must be kept in step with another field

## Each layer owns its ids and verbs

A transport or storage id is never used as a domain id. Contract files hold types and schemas only. Each layer keeps its own verbs, and a verb means one thing everywhere: a service `create`s where its store `insert`s, and a verb that may throw, such as `load`, is named so.

Spot it:

- one id doing two jobs
- logic in a contract file
- a verb that is neither the layer's own nor the domain's

## Dependencies are passed in

Collaborators arrive as parameters, never as module-level singletons or lookups. Secrets come from the environment and every other setting from the config file; both are parsed once, by schema, at the entry point, and passed down. Dependencies are declared. A backing service, such as a database or an external API, is an attached resource named by config and swappable without a code change. A process is disposable: it starts fast, shuts down cleanly, and loses nothing that was not already persisted when it is killed. Cancelling an act stops its work in flight: the signal reaches the external call, no further step starts, and nothing downstream takes in the result nobody received. Tests, CI and production run the same way against the same kinds of services.

Spot it:

- a module-level client or singleton
- the environment read below the entry point
- a non-secret setting read from the environment
- state that exists only in a running process
- a backing service's address or kind fixed in code
- a code path that runs only in tests, or only in production
- an abort that discards the outcome while the work runs on

## Observable by design

Every act that changes state or crosses a boundary logs that it started and how it ended, at a level a developer can turn on, with the ids that tie it to its task, and never repeating a payload an earlier line already holds. A new guard, effect or tool ships with its logging, so a bad run is diagnosed from the trace, not by adding a print. A service writes its logs to stdout as an event stream, and the environment routes and stores them; a local tool with no such environment keeps them in one place the user can query. Observability comes before configurability: what cannot be seen is not made tunable.

Spot it:

- a state change or external call with no log line
- a log line repeating the input the previous line logged
- an error logged without the id that finds its task

## Coded errors

Every error carries a code and its facts as fields, and an operation is defined so an error cannot arise where that is honest, such as removing what is already gone. `code-writing` states the rule; these are its symptoms.

Spot it:

- a bare error with no code, such as `throw new Error(` or `raise Exception(`
- a default code such as `command_failed`
- a code read out of a message, or a branch on message text
- an error class whose only field is a constant code, with its facts inside the message

## Writes return the record

A write returns the record it wrote (`INSERT … RETURNING *` in SQL). `code-writing` states the rule; these are its symptoms.

Spot it:

- a write returning an id or a row count (`lastInsertRowid`, `.changes`)
- a write followed by a read of the same row

## Operations are idempotent

Running an operation again, or again after a crash at any step, leaves the same state as running it once. A thing's identity comes from what already names it: a retried request finds the record its first attempt created, and creating a thing is a get-or-create on that identity. An effect of several steps checks the world or the record before each step, so a rerun finishes the work instead of repeating it. An act the state no longer admits is refused by that state, never applied twice. Setup and install converge: a second run changes nothing.

Spot it:

- an id minted on every call where the caller's identity already names the thing
- an insert with no unique key or conflict clause for something that exists once
- a setup or install that duplicates entries, or fails, when run twice
- a multi-step effect that a crash between steps leaves half-done, with no way for a rerun to finish it
- a migration step that cannot safely run twice
- a retry that can apply an act twice

# Code

## No indirection

A function that only passes its arguments on, a wrapper around a single call, or a file that exists to forward goes. So does a split whose name says no more than its body. This is the first thing to look for.

Spot it:

- a middle man: a function whose body is one call
- an export used by one caller in the next file
- a message chain (`a.b().c().d()`) walking through objects to reach one value
- an import alias or type alias with no name clash forcing it

## No abstraction before the third copy

Code is cheap to write, so nothing is abstracted in advance (rule of three). A small block gets a name at its third copy, a substantial one at its second, or at its first when the next copies are already planned. Copies kept apart on purpose, each local to its boundary, stay apart.

Spot it:

- a generic parameter used once
- a helper with one caller that takes parameters, generics or options for callers that do not exist

## Use what exists

A helper the repo already has is used rather than written again, and before a new helper lands its duplicate is searched for. A removal or rename is complete: no name, field, option, doc line, test or alias of the old design survives it.

Spot it:

- a hand-rolled version of a helper that exists elsewhere in the repo
- a name, config key or doc line left over from a removed feature

## No tech debt

Nothing lands that someone has to come back to: no TODO, no stub, no shim, no compatibility layer, no dual path, and no comment excusing a workaround. Leaving a feature unbuilt is fine; building half of it is not. Debt that is found is removed now, and a known bug is fixed, not filed. The fix removes the cause; a change that adds a condition in front of state it leaves in place is a symptom fix. With agents writing the code, the right fix costs about what the shortcut costs, so nothing justifies debt.

Spot it:

- a TODO, a "later", or a comment explaining a workaround
- a stub behind a feature
- a normalization or backfill for a stored format the code no longer writes
- a known gap or bug written into a doc instead of fixed
- a new check guarding against state that should not exist

## One shape per job

Once a job has a pattern, every instance of that job follows it.

Spot it:

- two error styles in one module
- two writer signatures, or two outcome styles (return versus throw), for the same kind of act

## Flat control flow

A function reads top to bottom and does one thing. `code-writing` states the rule; these are its symptoms.

Spot it:

- a nested ternary
- `if/else` where the `if` branch returns
- a boolean flag set inside a loop and read after it
- a variable declared wider than the block that uses it
- in a language with truthiness, a truthy test on a value that may legally be `0`, empty or `false`
- a function too long to read without scrolling

## Named constants

A literal with a meaning is a named constant, defined once, grouped with its kin, and taken from a measurement or an external contract rather than guessed; a value's own domain, such as the digits of a puzzle, is not a magic number. `code-writing` states the rule; these are its symptoms.

Spot it:

- a bare number or escape sequence in an expression
- a set, regex or lookup built on every call where it could be built once (a compile-time constant is not this)
- the same literal in two files
- a limit, timeout or threshold with no measurement behind it

## An invalid value never exists

Input is parsed once, at the boundary, into a type that states exactly what holds (parse, don't validate), and a default exists only where one value is right for everyone. `code-writing` states the rule; these are its symptoms.

Spot it:

- `string` used for an id or a time
- a type written by hand beside the schema it duplicates
- a `typeof` chain where a parse belongs
- an unchecked cast, non-null assertion or escape from the type system outside a store's row mapping
- validation repeated below the boundary
- a null-coalescing or `or` fallback on a value the type says is present, or one that turns a missing required value into a stand-in
- a default that picks a vendor, model or option for the user

## Immutable by default

Data does not change in place, and a concept defined by its value is a value object. `code-writing` states the rule; these are its symptoms.

Spot it:

- a field or collection left mutable that nothing needs to change
- a parameter, or an outer variable, mutated inside a function or callback
- an in-place sort or splice on shared data
- primitive obsession: a primitive standing in for a value object with rules of its own

## Absent is null; the caller that needs it throws

A read that may find nothing returns the language's one empty value, and the caller that knows the thing must exist raises. `code-writing` states the rule; these are its symptoms.

Spot it:

- `{}`, `""` or `[]` returned for a missing record
- a second empty value beside the one the language provides, such as TypeScript's `undefined` beside `null`
- a caller testing a result for emptiness to learn whether it existed

## Catch only at the edge

An error is caught only at the edge that shows it, or to undo a side effect and rethrow, and never used for control flow. `code-writing` states the rule; these are its symptoms.

Spot it:

- a catch on the success path that logs and continues, or returns a default
- a typed error caught and rethrown as another type
- errors used for control flow: a `try` that tests whether something exists, a throw that exits a loop, or a caught "not found" that picks a branch; the expected case is a return value (the empty value, a result type), and a throw means something went wrong

## Exhaustive over closed sets

A closed union is handled exhaustively, so the compiler flags every match a new member misses. `code-writing` states the rule; these are its symptoms. An exhaustive match is not the "switch statements" smell, and it is not replaced by polymorphism.

Spot it:

- an if-chain over a union
- a lookup keyed by any string where its keys are a union
- repeated switches: the same `switch` over one union in several files, where the per-variant data belongs in one place (see "One place to add a variant")

## Access fails closed

A permission or gate check denies unless something explicitly allows it, and it runs once, at the act it guards.

Spot it:

- a check that allows when its input is missing or unknown
- the same permission check at several layers of one act

## What the user sees

Nothing internal reaches the user: a blocked, retried or internally corrected step never shows, and the output is consistent every time. An error the user sees is one clear sentence saying what happened and what to do. Show what the task at hand needs, and keep detail and advanced controls one step away (progressive disclosure), except anything the user needs to catch a mistake, which stays in view. No option or customization exists unless it is truly needed. The system sends values and codes, and the client turns them into text.

Spot it:

- an internal step, stack or raw error shown to the user
- output that differs between runs of the same act
- every option or detail on the first screen
- display text built on the server

## Names

Names are short but unambiguous. Factories follow one convention per repo: the language's own (`new`, `from_…`) or, where it has none, `create…`. No brand name appears in an identifier, except in the one factory that creates the product itself. A folder is named for its domain noun, and a file for the one thing it exports, in the language's file-name case.

## Code shaped for its tests

Production code is never shaped for a test: nothing is exported only for a test, and no parameter, flag or wrapper exists only so a test can reach in. A test goes through the public surface and fakes only external services and models. How a test itself is written is `test-review`'s concern.

Spot it:

- an export whose only importer is a test
- a parameter or default only a test sets
