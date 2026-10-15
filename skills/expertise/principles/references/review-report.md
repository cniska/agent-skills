# Review report

Every review reports in one shape, so a review that runs others merges their results without translating them. Three sections, in this order, each saying `none` when it is empty, and after them only the closing lines the caller asks for, such as `Repo:` and `Verdict:`:

```
## Findings

- **Where:** `file:line`, plus each other place showing the same problem
- **Rule:** the rule or check it breaks, by its heading
- **Severity:** critical | major | minor
- **Why:** one sentence about this code
- **Instead:** the shape to build, or delete

## Conflicts

Findings only the owner can settle, such as one against a decision the owner made, in the same bullets.

## Clean

- **<the rule or check>:** the places it was checked in
```

- **Severity** measures how well the work was built the first time and never gates: **critical** breaks behavior, security or data; **major** is a real defect or a broken convention; **minor** is the rest. A review skill may say how its own findings map onto the three.
- Every finding is fixed, by whoever ran the review; the review itself changes nothing. It accepts only when Findings is `none`.
- A rule is marked clean only after the whole scope was checked, not a sample. No summary paragraph or table.
