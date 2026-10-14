# The reviewer

A fresh agent that did not write the work runs [design-review](../skills/expertise/design-review/SKILL.md) on each commit, and on the design wherever its shape is open. The agent that made a change never judges how it is built.

- **It judges the way I would in review**, against my design rules: architecture, patterns and code smells.
- **For each problem it states what is wrong and what it should be instead**, so its findings steer the work toward the shape I would have given it.
- **On how code is built, its verdict wins** over other reviewers.

The plugin runs it as the [reviewer agent](plugin.md#reviewer-agent), and the [commit gate](plugin.md#commit-gate) holds each commit until it accepts.

## Fix and Consider

It ranks each finding Fix or Consider.

- **Fix** is a design the next case would copy, or one that misleads the next writer.
- While a Fix finding stands, the reviewer returns the change.
- Every Fix finding is fixed, and the re-review judges only the fix.
- **Consider** is local mess, and when only Consider findings remain, the reviewer accepts.
- Consider findings are fixed in their own follow-up commit after the accepted one, as is neighboring code the review turns up, never left in a backlog.
- A finding a re-review raises about other code starts its own fix rather than blocking the accept.

Only a finding that needs my decision, or sits in a change another person owns, goes into the task's report.
