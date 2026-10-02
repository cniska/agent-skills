---
name: database-design
description: Design or change a database schema. Use when adding or altering tables, columns, views, access rules, database functions, or migrations.
---

# Database design

Design the schema as the domain's record, with the database holding its own invariants rather than trusting the code that writes to it.

## Before designing

- Where the schema doc and the DDL or code that enforces it differ, the code wins and the doc is fixed in the same change.
- Find how this repo changes its schema: forward-only migrations, or derived tables rebuilt from their sources. Never mix the two for one table.
- Search the repo's history and past sessions for schema corrections, and treat a repeated fix as a requirement.

## Columns and constraints

- **Decide what one row stands for before naming it** — a dated occurrence or the thing it recurs from, an attempt or its outcome — and what each value records: a decision made, or a result observed later. Say which in the schema doc.
- **Nullability is a claim about the domain.** `not null` forecloses states that may legitimately exist; nullable invites a caller that forgets. Ask which states the table must represent, not which are convenient now. Where null carries meaning, such as unlimited stock, the schema doc says so.
- **Store a fact once.** A role or flag that a relation already implies — account type from membership — is derived, never a column that can contradict it.
- **Add no column nothing reads yet.** Personal data collected without a use is a liability, not an option kept open.
- **A closed set needs somewhere for the unclassifiable case**, or callers file it under the nearest value and the data stops meaning anything.
- **A JSON column has a checked shape**, or the stable fields become columns. An unconstrained nullable JSON column accepts anything.
- **Names use the business term and fit what the table will hold**, not its first caller.
- **An inner join on a nullable column drops rows.** A row with no parent leaves a view by choice, never by accident.

## Access

Where more than one kind of caller reaches the database:

- Isolation lives in the database: row-level security on every table, or every row carrying its owner in the key and every query scoped by it.
- A table hidden from clients has security enabled, no policy, and no client grant. An enabled table without policies that something still reads is a bypass hiding elsewhere.
- Writes that carry an invariant go through privileged functions, with direct writes revoked. Each such function has an explicit authorization check, a pinned search path, and execute revoked from everyone before it is granted — most engines grant to all by default.

## Changing the schema

- Never edit a migration that has been applied anywhere; fix it with a new one. Fold changes to an unmerged migration into it rather than stacking corrections.
- A breaking change is two changes: expand to accept both shapes, deploy, then contract once no deployed code uses the old one.
- A derived table has a rebuild path from its sources, and readers refuse a database whose schema version is older than the code.

## Review gate

Before calling a schema change done, apply it to an empty database and to one with representative rows, and, where callers are isolated, exercise access as another owner, as each other kind of caller, and anonymously. Report each finding with the table, column or policy, and the state it allows or forbids.

## See also

- `review` for the migration checks at review time
- `adr` for recording a schema decision that is expensive to reverse
- `security-review` for trust-boundary risk beyond the schema

## Red flags

- A flag column that restates a relation
- A column with no reader
- An unconstrained JSON column
- A table with security enabled and no policy that clients still read
- A privileged function missing its authorization check, pinned search path, or revoked default grant
- An edited applied migration, or a breaking change in one step
- A schema doc that still describes the old shape
