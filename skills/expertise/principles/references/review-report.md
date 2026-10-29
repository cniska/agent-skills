# Review report

Every review reports in one shape, so a review that runs others merges their results without translating them. The fields are the same in either rendering. Where the caller names a report tool, the outermost review makes its call, once, with every field merged, under the names its schema gives; a review that another runs hands its fields to that review as sections and never calls the tool. Otherwise they are four sections, in this order, each saying `none` when it is empty, and after them only the closing lines the caller asks for:

```
## Findings

- **Where:** `file:line`, plus each other place showing the same problem
- **Rule:** the rule or check it breaks, by its heading
- **Severity:** critical | major | minor
- **Why:** one sentence about this code
- **Instead:** the shape to build, or delete

## Conflicts

Findings only the owner can settle, such as one against a decision the owner made, in the same bullets.

## Follow-ups

Real defects, such as a bug or a security hole, that were there before the change and do not block it, in the same bullets.

## Clean

- **<the rule or check>:** the places it was checked in
```

- **Severity** measures how well the work was built the first time and never gates: **critical** breaks behavior, security or data; **major** is a real defect or a broken convention; **minor** is the rest. A review skill may say how its own findings map onto the three.
- **Sort each problem by whether the change caused it**, never by whether it sits on a changed line:
  - A problem the change causes is a finding wherever it sits, a line the diff leaves as it was included, such as a description the change makes wrong or a caller it breaks.
  - A problem that was there before the change and blocks it, such as a bug the change calls into or a hole it makes reachable, is a finding worded as its own fix, never as one the change introduced.
  - Any other problem that was there before the change, in a file or hunk the diff touches included, is a follow-up when it is a real defect and is dropped, not reported, when it is a style point.
- **Findings:** whoever ran the review fixes every one; the review itself changes nothing. It accepts only when there is no finding; conflicts and follow-ups never hold back an accept.
- **Follow-ups** go to whoever coordinates the work, or else the owner, each queued as its own task, in the task tool where one is installed, never as a backlog line.
- **Where** may cite other places with the same problem, so the fix is one structure. A cited place whose problem the change did not cause is fixed with the finding only where the fix needs it, and is otherwise sorted like any other problem that was there before the change.
- A rule is marked clean only after the whole scope was checked, not a sample. No summary paragraph or table.
