# Review report

Every review reports in one shape, so a review that runs others merges their results without translating them. Four sections, in this order, each saying `none` when it is empty, and after them only the closing lines the caller asks for, such as `Repo:` and `Verdict:`:

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

Real defects, such as a bug or a security hole, in code no diff of the change touches that do not block the change, in the same bullets.

## Clean

- **<the rule or check>:** the places it was checked in
```

- **Severity** measures how well the work was built the first time and never gates: **critical** breaks behavior, security or data; **major** is a real defect or a broken convention; **minor** is the rest. A review skill may say how its own findings map onto the three.
- **Findings** holds what the change touches, and code it does not touch only where that code blocks the change, such as a bug the change calls into or a hole it makes reachable. Whoever ran the review fixes every finding; the review itself changes nothing. It accepts only when Findings is `none`; Conflicts and Follow-ups never hold back an accept.
- **Follow-ups** go to whoever coordinates the work, or else the owner, each queued as its own task, in the task tool where one is installed, never as a backlog line. A style point or nit in code the change does not touch is dropped, not reported.
- **Where** may cite other places with the same problem, so the fix is one structure. A cited place in code the change does not touch is fixed with the finding only where the fix needs it; otherwise it is a follow-up when it is a real defect, and dropped when it is a style point.
- A rule is marked clean only after the whole scope was checked, not a sample. No summary paragraph or table.
