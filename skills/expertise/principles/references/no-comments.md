# No comments

Code carries no comments. A why goes into a name, a test, the tool's config, or the doc that owns the subject. A ban is a rule a check can hold, where "only the why" is one more sentence to judge.

- A comment stays only when a tool reads it and deleting it changes what that tool does, such as a shebang, a build constraint, a license identifier or a pure annotation. It stands alone, with no reason beside it.
- A suppression, formatter hint or tool setting is refused even so: fix the code. A check is set off in the tool's config file, where its reason can live, only when no rewrite of the code meets it without making the code worse. A file is marked generated in `.gitattributes`, not by a header comment.
- Doc comments and docstrings are refused, on a published package's API and where a runtime reads them too, as are a test tool's annotations such as an expected-output comment. A doc comment explains what a better name, type or test should say; fix that instead. A package's usage lives in its README.
- The ban covers source code. A config file (TOML, YAML, a CI workflow) may carry a reason comment, since it has no name or test to hold one. Markup and styles carry none.
- A comment on a line the change touches goes with it, its why moved first. Comments elsewhere are left for a change of their own.
- A config comment never narrates the change and is never a banner or separator.
