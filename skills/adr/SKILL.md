---
name: adr
description: Create or update architecture decision records. Use when an important technical decision is made, changed, or needs recording after the fact.
---

# ADR

An architecture decision record states one important technical decision: the problem it solves, what was chosen, what was ruled out, and what the choice costs. It exists so a settled question is not argued again, by a person or an agent.

Three modes, inferred from the request:

- **New** — a decision was just made and has no record.
- **Edit** — a recorded decision changed, stopped holding, or the records need bringing up to date.
- **Backfill** — decisions made earlier need records, mined from history.

## Conventions this skill enforces

- **Technical and important only** — expensive to reverse, or relied on by more than one part of the system, and surprising without context: a reader of the code would wonder why, or a constraint the code cannot show forced it. A deliberate departure from the obvious path qualifies; the obvious choice made for the obvious reason does not. Product scope belongs to the spec, a convention to the agent rules; a record may hold the why behind a convention, while the rule itself stays where agents read it.
- **One decision per record.** A detail of a recorded decision, such as how one function implements it, belongs in that record or its owning doc, not a record of its own.
- **The title names the problem, never the technology** — "Backend platform", not "Use Postgres". The chosen technology goes in the Decision.
- **Sections:** Context, Decision, Alternatives (only when known), Consequences. A rejection that is not obvious is the most valuable line, since it is the one that would otherwise be suggested again.
- **A record states the decision that holds today.** When the decision changes, edit its record; when it stops holding, delete it. Git keeps the history, so no status, date, or supersede chain.
- **Short.** The why and the cost; link the doc that owns the detail rather than restating it, and leave out volatile numbers. Where the owning doc already states the decision, its alternatives, and its reasons, the record is a link to it, or no record at all.
- **Facts are verified at their source** — the code, migration, config, or owning doc — and a fact that cannot be verified is deleted.
- **Reasons and alternatives come from the owner** — their own words, or an argument they explicitly accepted, about this decision. Cite who said it; an assistant's proposal or summary is not the owner's reason. A reason that is a consequence of the decision, or that would equally reject something the system does elsewhere, is not the reason.
- **Never invent an alternative or a reason.** Search past sessions first (the `search-sessions` skill), then ask the owner. When the owner is not available, draft only what the sources support and list the open questions with the draft.
- **Find the repo's convention before writing** — existing records, their README or template, the agent rules, and tooling such as an `.adr-dir` file or an `adr-tools` setup. Continue its directory, markup, and numbering; never start a second scheme.
- **The existing format keeps its structure; these content rules still apply.** Structure is the section set, markup, and numbering; a template's example titles and placeholder text are not. Where the structure conflicts with these rules, such as a required status section, keep it, fill it with the value that means the decision holds today, and raise the conflict with the owner rather than reformatting the set. With no format, propose a home and a shape and ask before writing.

## Workflow

### New mode

1. **Check it earns a record** against the conventions above.
2. **Read the code and the owning doc** the decision touches, and search past sessions for its alternatives and reasons.
3. **Create the file** with the repo's tool, or the next number in the ADR directory, listed in the index.
4. **Write the four sections**, linking the owning doc for detail.
5. **Run the repo's guard**, if it has one, and check the links it does not.

### Edit mode

1. **Read the record, what changed, and the code it claims** — re-verify every claim, not only the ones the change touches; drift is found here.
2. **Find everything the change touches** — search the topic, not only links to the record number, across the other records and the owning docs.
3. **Still holds?** Rewrite the record to the current state; a rejected alternative that became the choice moves into the Decision.
4. **No longer holds, never earned a record, or duplicates its owning doc?** Delete it and its index line; move a convention to the agent rules. Never mark a record superseded.
5. **Change the owning docs and the other records in the same change**, so no doc contradicts a record.

### Backfill mode

1. **Mine the history** — past sessions under every path the repo has lived at, commits, PR bodies, founding documents — for decisions, with dates to order them, options, and reasons.
2. **List candidates oldest first** with their sources, and let the owner cut it to the important technical ones that still hold.
3. **Ask the owner for every missing reason or alternative** before drafting.
4. **Draft each record as in New mode**, then have an independent reader check every claim against its source, including who said it and about which question.

## See also

- `docs` — the owning doc a record links to
- `spec` — product requirements, which are not records
- `agents-md` — conventions, which are not records
- `search-sessions` — mining past discussion for reasons and alternatives
- `second-opinion` — the independent check of a drafted set
- `why` — tracing recorded rationale and whether it still applies

## Red flags

- A title that names the technology instead of the problem
- A status, a date, or a "superseded by" line the repo's format does not require
- Restating detail that an owning doc already holds
- An alternative or a reason the sources do not show, or one an assistant gave and the owner never accepted
- A reason that would equally reject something the system already does
- A record for a convention, a product decision, or a detail of another record
- Editing a record while the owning doc still says the old thing
- Adding a new record that contradicts an existing one instead of editing it
