# The reviewer

A fresh agent that did not write the work runs [design-review](../skills/expertise/design-review/SKILL.md) on each commit, and on the design wherever its shape is open. The agent that made a change never judges how it is built.

- **It judges the way I would in review**, against my design rules: architecture, patterns and code smells.
- **For each problem it states what is wrong and what it should be instead**, so its findings steer the work toward the shape I would have given it.
- **On how code is built, its verdict wins** over other reviewers.

The plugin runs it as the [reviewer agent](plugin.md#reviewer-agent), and the [commit gate](plugin.md#commit-gate) holds each commit until it accepts.

## Findings

Its report has three sections: Findings, Conflicts with a decision I settled, and the rules it checked and found Clean.

- Every finding is fixed, so any finding returns the change; it accepts only when Findings is empty.
- Each finding carries a severity, critical, major or minor, to count how well a change was built the first time; it never decides whether a finding is fixed.
- The re-review is another fresh agent, given only the fix to judge.
- A finding about neighboring code also returns the change, so it is fixed in that change, never left in a backlog.
- A brief that gives it no diff to read is returned as `no_diff`, never accepted on a read of something else.

Only a finding that needs my decision, or sits in a change another person owns, goes into the task's report.
