# Access

Load this when the schema serves callers of more than one kind.

- **Keep isolation in the database:** row-level security on every table, or every row carrying its owner in the key and every query scoped by it.
- **Hide a table from clients** by enabling security on it with no policy and no client grant. When an enabled table without policies is still read by something, that reader bypasses security somewhere; find it.
- **Route writes that carry an invariant through privileged functions,** and revoke direct writes. Give each such function an explicit authorization check and a pinned search path. Revoke execute from everyone before granting it, since most engines grant it to all by default.
