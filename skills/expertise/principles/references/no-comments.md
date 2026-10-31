# No comments

Put the why in a name, a test, the tool's config or the doc that owns the subject, and leave source code without comments.

A ban is a rule a check can hold, where "comment only the why" is one more sentence for each writer to judge.

- Keep only a comment a tool reads, where deleting it changes what the tool does, such as a shebang, a build constraint, a license identifier or a pure annotation. It stands alone, with no reason beside it.
- Fix the code rather than add a suppression, formatter hint or inline tool setting, even though a tool reads each. Turn a check off in the tool's config file, with its reason there, only when no rewrite meets it without making the code worse.
- Mark a generated file in `.gitattributes`, not with a header comment.
- Say what a doc comment or docstring would say through a better name, type or test, even on a published API or where a runtime reads it. Put a package's usage in its README.
- Treat a test tool's annotations, such as an expected-output comment, the same way.
- Let a config file, such as TOML, YAML or a CI workflow, carry a comment that gives a reason and nothing else, since it has no name or test to hold one. Leave markup and styles without comments.
- When a change touches a line with a comment, move its why first, then remove it. Leave comments elsewhere for a change of their own.

Example: `// retry: the API drops the first call after idle` becomes a constant `IDLE_DROP_RETRIES` and a test of the dropped call.
