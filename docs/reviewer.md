# The reviewer

A fresh agent that did not write the work judges each commit and each design whose shape is open. Before a branch lands, another fresh one runs [review](../skills/workflow/review/SKILL.md) on the whole branch. The agent that made a change never judges how it is built.

- **On a brief or plan the coordinator writes for a worker it judges what to build**: the outcome, the scope, the decisions it settles, whether a worker can build from it, and any claim false at its source. How the work is built waits for the worker's own reviews, so its report leaves that out.
- **On code it judges the way I would in review**, against my design rules in [design-review](../skills/expertise/design-review/SKILL.md): architecture, patterns and code smells.
- **On docs it judges prose for a reader** in [doc-review](../skills/expertise/doc-review/SKILL.md): drift, shape and verbosity. The [agent](../agents/reviewer.md) tells docs from code by file path.
- **On a whole branch it checks correctness, tests and security**, and each other area the diff touches, as `review` says.
- **For each problem it states what is wrong and what it should be instead**, so its findings steer the work toward the shape I would have given it.
- **On how code is built, its verdict wins** over other reviewers.
- **It leaves what the checks enforce to them**: the worker runs validate, test, lint and the commit hooks, so its report never claims one passed and still flags a change that weakens or removes one.

The plugin runs it as the [reviewer agent](plugin.md#reviewer-agent), and the [commit gate](plugin.md#commit-gate) holds each commit until it accepts.

It judges the diff, not the screens: a commit that changes an interface also waits for a fresh [designer](plugin.md#designer-agent), which judges the running interface through [ui-review](../skills/expertise/ui-review/SKILL.md).

## Findings

Its report takes the shape every review in the plugin uses, the [review report](../skills/expertise/principles/references/review-report.md) in `principles`.

- It sorts each problem by whether the change caused it: one the change causes is a finding wherever it sits, and one that was there before is a finding only when it blocks the change, worded as its own fix. Any other bug or security hole that was there before, in a file the diff touches included, is a follow-up: the accept never waits on it, and it becomes a queued task, never a backlog line; a style point that was there before is dropped. A finding is fixed, so it returns the change; it accepts only when there is no finding.
- The re-review is another fresh agent, given the fix to judge and the change's earlier diffs to read, for findings as for its accept. Where any later review, the branch review's first pass included, disagrees with a line an earlier review read and did not flag, whether that review accepted or returned, that is a finding and returns, unless it is against a decision I or the coordinator settled, which is a conflict for me to settle.
- On code none of the change's diffs touch, a problem that was there before the change returns it only when it blocks the change; the fix is its own commit, accepted on its own and committed first, and the returned change's re-review is then handed that commit's diff as the fix, so the change's diff never grows to cover it.
- A brief that gives it no diff to read is returned as `no_diff`, never accepted on a read of something else.

Only a finding that needs my decision, or sits in a change another person owns, and the follow-ups to queue go into the task's report.
