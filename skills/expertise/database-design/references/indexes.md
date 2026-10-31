# Indexes

- **Turn foreign keys on where the engine needs it.** SQLite enforces foreign keys only on a connection that sets `PRAGMA foreign_keys = ON`.
- **A partial index covers a foreign key** only when its predicate admits every row with a non-null reference.
- **Confirm each access path with the engine's query plan** (`EXPLAIN QUERY PLAN`, `EXPLAIN`) wherever a database can be run, rather than by reading the DDL. On a small table the planner scans anyway, so read plans on data at size, or with scans discouraged, such as Postgres `enable_seqscan = off`.
- **Reshape a query no index can serve.** A whole-table aggregate scans by nature. A query such as a sort over an aggregate gets a different shape, such as a summary row, in place of another index.
- **Design the index for the query.** Equality columns lead, then the range or sort column, so an `ORDER BY … LIMIT` reads the index in order instead of sorting.
- **Drop a non-unique index that is the leading prefix of another,** since the longer one serves its queries.
- **Compare a filtered or sorted column bare.** A function such as `lower(email)` or a JSON extraction, or a `COALESCE` around the column, skips a plain index. So does a per-row security predicate that is the query's only filter, and `(param is null or col = param)` under a generic plan. Index the expression, store the value as a column, or build the query per case.
- **Build an index on a large live table without blocking writes,** such as with Postgres's `CREATE INDEX CONCURRENTLY`. Run it outside the transaction many migration tools wrap each migration in, and check the index is valid afterwards, since a failed build leaves an invalid index behind.
