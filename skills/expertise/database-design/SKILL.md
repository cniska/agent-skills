---
name: database-design
description: Design or change a database schema so the database holds the domain's invariants itself — rows, columns, constraints, indexes, access rules and migrations. Use when adding or altering tables, columns, views, access rules, database functions or migrations, or when checking a migration in review.
---

# Database design

Design the schema as the domain's record, with the database holding its own invariants instead of trusting the code that writes to it.

## Before designing

- Where the schema doc and the DDL or code that enforces it differ, the code wins, and the doc is fixed in the same change.
- Find how this repo changes its schema: forward-only migrations, or derived tables rebuilt from their sources. Change each table one way only.
- Search the repo's history and past sessions for schema corrections, and treat a repeated fix as a requirement.
- Record a schema decision that is expensive to reverse in a decision record.

## Columns and constraints

- **Decide what one row stands for before naming it,** such as a dated occurrence or the thing it recurs from, an attempt or its outcome. Decide what each value records: a decision made, or a result observed later. Say which in the schema doc.
- **Nullability is a claim about the domain.** `not null` forecloses states that may legitimately exist, and a nullable column invites a caller that forgets. Ask which states the table must represent, not which are convenient now. Where null carries meaning, such as unlimited stock, the schema doc says so.
- **Store a fact once.** Derive a role or flag that a relation already implies, such as account type from membership, so no column can contradict it.
- **Add a column only once something reads it.** Personal data collected without a use is a liability.
- **Give a closed set a value for the unclassifiable case,** or callers file it under the nearest value and the data stops meaning anything.
- **Check a JSON column's shape,** or move its stable fields into columns. An unconstrained nullable JSON column accepts anything.
- **Name with the business term,** fitted to everything the table will hold, not to its first caller.
- **Join a nullable column on purpose.** An inner join on it drops the rows with no parent, so a row leaves a view only by choice.

## Indexes

- **Declare each relation between tables as a foreign key,** so the database keeps it rather than the code.
- **Give each foreign key an index that leads with its columns, in order.** Without one, deleting a referenced row scans the referencing table once per row. Where the repo has tests, a schema test enforces it.
- **Give every query an index for its access path, and every index a query that uses it.** Each index slows every write.
- **Enforce an invariant over a subset of rows with a partial unique index,** such as one active row per owner.

Follow [indexes](references/indexes.md) when a change adds a query, an index or a foreign key.

## Access

Where more than one kind of caller reaches the database, follow [access](references/access.md).

## Changing the schema

- Leave a migration that has been applied anywhere as it is, and fix it with a new migration. Fold changes to an unmerged migration into it rather than stacking corrections.
- Make a breaking change in two steps: expand to accept both shapes and deploy, then contract once no deployed code uses the old shape.
- Give a derived table a rebuild path from its sources, and have readers refuse a database whose schema version is older than the code.

## Review gate

Before calling a schema change done, apply it to an empty database and to one at the largest size its data plausibly reaches, and run any rebuild or drop the change implies at that size. Where callers are isolated, exercise access as another owner, as each other kind of caller, and anonymously. Report each finding with the table, column or policy, and the state it allows or forbids.
