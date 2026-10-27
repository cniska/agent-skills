---
name: ui-review
description: Review a change to a running interface, its UI and its UX, from captures of every state it touches, measured and set beside the screen it copies, and say what is wrong and what it should be instead. Use on each commit that changes an interface, and before the owner sees any of its screens.
argument-hint: "<diff, captures and reference captures>"
---

# UI review

Judge a running interface the way the owner does on looking at it: whether each screen the change touches looks right, reads right and works right. The rules a screen is held to live in `ui-design` and its platform references, which this review cites by section and never restates; this skill is how to judge against them and what evidence a judgment needs. Findings are stated as findings, never softened into suggestions.

## Evidence

- **Captures of the running interface.** Judge the screens a run of the changed build produced, never a mock or the source alone: stills miss hover, focus and small sizes, so the run captures those too ([GitLab](https://handbook.gitlab.com/handbook/product/ux/product-designer/mr-reviews/)). A review with no capture is source-only: it says visual quality is unverified and returns.
- **Every state, not one shot.** Each state the change touches, such as empty, some and many items, error, waiting, disabled, focus, hover, search focus and the keyboard up ([GitLab's list](https://docs.gitlab.com/development/contributing/design/)), in each theme the product ships, at each target size and at the largest text size, largest and smallest layouts first ([HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout)). A changed state with no capture is a finding.
- **The diff beside the captures.** Tokens, hand-set values and the components a screen is built from do not show in pixels; read the diff for them.
- **The owner's own reviews.** Search the session record for the owner's past corrections on the screen's subject, such as its alignment, spacing, wording or prominence. A correction that applies is judged as a rule, cited by session and time.

## Judge

- **Against a named reference screen.** On a native platform, each screen cites the first-party screen it copies, as `ui-design`'s Apple platforms reference requires, and each shot sits beside that reference's capture in the same theme and size. On a platform with no first-party screens, such as the web, it cites the product's own established screen it extends, as `ui-design`'s "Preserve the product's established visual language" says. A screen that cites no reference it has is a finding. A screen with no reference of either kind is a conflict for the owner.
- **Measured, not only looked at.** Check alignment, equal margins, shared baselines and type size, and that nothing jumps: compare each element's position between the states, and between sibling screens that share a layout, from the frames in the capture's accessibility dump where the project's verify skill emits one, else from the pixels. Measure contrast and target size against `ui-design`'s "Responsive and accessible behavior". Blur the capture to check the primary element still dominates ([NN/g's squint test](https://www.nngroup.com/articles/visual-hierarchy-ux-definition/)).
- **UX as well as UI.** Walk the flow through each step, its exits and its undo, and check it against [the ten usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/), naming the heuristic a finding breaks. Read the wording against the reference screen's and against `ui-design`'s "State and interaction". Check each element's prominence against how often it is used, as `ui-design`'s "Before designing" says.
- **Tokens and design systems.** Judge the diff against `ui-design`'s "Visual contract" and, on Apple platforms, its "System components, never hand-rolled styles". A literal repeated across screens, or a hand-set value equal to a system default, is a finding. On a platform with no system of its own, such as the web, each finding moves the screen toward one shared token set and component system.
- **Taste stays the owner's.** A call no rule, reference, owner correction or cited source settles goes under Conflicts, never Findings. A departure from the reference screen or an established pattern is not taste: without evidence for it, it is a finding ([GOV.UK](https://www.gov.uk/service-manual/design/making-your-service-look-like-govuk)).

## Report

Report in the review report shape from `principles`, ending with a `Verdict:` line. Each finding's **Where** names the screen, the state, the theme, the size and the capture or frame it rests on, plus `file:line` where the diff holds the cause. **Severity:** critical when a state hides, clips or loses what the user needs or cannot be operated; major when it breaks a rule, the reference or an owner correction; minor for the rest.

## See also

- `ui-design` — the rules a screen is held to, and its platform references
- `design-review` — the same judgment on how the code is built
- `principles` — the review report shape
- `search-sessions` — the owner's past corrections on a screen's subject
- `workflow-review` — turns the owner's repeated UI corrections into rules for `ui-design` or this skill
- `verification-setup` — the verify skill whose run produces the captures and frame dumps

## Red flags

- An accept with a changed state, theme or text size left uncaptured
- Judging a screen with no reference screen named beside it
- Alignment or spacing called right by eye where frames were there to measure
- A screen judged on looks alone, its flow, wording and prominence unread
- A taste call raised as a finding
- A hand-set value or repeated literal passed because the pixels look right
