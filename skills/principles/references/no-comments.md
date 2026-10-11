# No comments

Code carries no comments. A why goes into a name, a test, or the doc that owns the subject. A ban is a rule a check can hold, where "only the why" is one more sentence to judge.

- A tool directive is not a comment: a lint or type suppression, or Rust's `// SAFETY:`. It carries its reason on the directive's own line.
- Doc comments stay only on the public API of a package published to a registry, where the doc tool renders them as the package's documentation. Elsewhere a doc comment explains what a better name, type or test should say; fix that instead.
- The ban covers source code. A config file (TOML, YAML, a CI workflow) may carry a reason comment, since it has no name or test to hold one. Markup and styles carry none.
- A comment on a line the change touches goes with it, its why moved first. Comments elsewhere are left for a change of their own.
- Where a comment is allowed, it never narrates the change and is never a banner or separator.
