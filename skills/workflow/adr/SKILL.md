---
name: adr
description: Write, update or delete architecture decision records, each stating one important technical or design decision with the owner's reasons and the alternatives ruled out. Use when such a decision is made or changes, or when earlier decisions need records mined from history.
---

# ADR

An architecture decision record states one important technical decision: the problem it solves, what was chosen, what was ruled out, and what the choice costs. It exists so a person or an agent does not argue a settled question again.

## What matters

- **Write it as `writing` says for documents that last.**
- **Record only what is technical and important**: expensive to reverse or relied on by more than one part of the system, and surprising without context, because a reader of the code would wonder why or a constraint the code cannot show forced it. A deliberate departure from the obvious path qualifies. The obvious choice made for the obvious reason does not. Product scope belongs to the spec and a convention to the agent rules. A record may hold the why behind a convention, while the rule itself stays where agents read it.
- **One decision per record.** A detail of a recorded decision, such as how one function implements it, belongs in that record or its owning doc.
- **Title the problem**, such as "Backend platform", and put the chosen technology in the Decision.
- **Write four sections**: Context, Decision, Alternatives when any are known, and Consequences. A rejection that is not obvious is the most valuable line, since it is the one someone would otherwise suggest again.
- **State the decision that holds today.** When the decision changes, edit its record. When it stops holding, delete the record. Git keeps the history, so the record carries the decision alone, with no status, date or chain of superseded records.
- **Keep it short**: the why and the cost. Where the owning doc already states the decision, its alternatives and its reasons, the record is a link to that doc, or there is no record.
- **Verify each fact at its source**, such as the code, a migration, the config or the owning doc, and delete a fact you cannot verify.
- **Take reasons and alternatives from the owner**: what they said about this decision, or an argument they explicitly accepted, restated as `writing` says. Cite who said it. An assistant's proposal or summary counts only once the owner has accepted it. A reason that is a consequence of the decision, or that would equally reject something the system does elsewhere, is not the reason.
- **Source every alternative and reason.** Run `search-sessions` first, then ask the owner. When the owner is not available, draft only what the sources support and list the open questions with the draft.
- **Continue the repo's convention.** Before writing, find the existing records, their README or template, the agent rules, and any ADR tooling the repo has set up. Continue its directory, markup and numbering.
- **Keep the existing format's structure, and apply these content rules inside it.** Structure is the section set, the markup and the numbering. A template's example titles and placeholder text are not structure. Where the structure conflicts with these rules, such as a required status section, keep it, fill it with the value that means the decision holds today, and raise the conflict with the owner. When the repo has no format, propose a home and a shape and ask before writing.

## Modes

- **New**, when a decision was just made and has no record: follow [new](references/new.md).
- **Edit**, when a recorded decision changed or stopped holding, or the records need bringing up to date: follow [edit](references/edit.md).
- **Backfill**, when decisions made earlier need records mined from history: follow [backfill](references/backfill.md).
