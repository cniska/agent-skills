---
name: ui-review
description: Review a change to a running interface, its UI and its UX, from measured captures of every state it touches, set beside the reference screen it follows, and say what is wrong and what it should be instead. Use on each commit that changes an interface, on a branch's finished interface before it lands, and before the owner sees any of its screens.
---

# UI review

Judge a running interface the way the owner does on looking at it: whether each screen the change touches looks right, reads right and works right. The rules a screen is held to live in `ui-design` and its platform references; a finding cites the rule it breaks by its section there. State each finding as a finding, with what the screen should be instead.

## Evidence

- **Captures of the running interface.** Judge the screens a run of the changed build produced, since a mock or the source alone hides how the screen actually renders. Stills miss hover, focus and small sizes, so the run captures those too. A terminal interface's capture is the text and exit code its platform reference's Proof names. A review with no capture at all judges the diff alone, says visual quality is unverified, and sorts the gap as below.
- **Every state, not one shot.** Each state the change touches, such as empty, some and many items, error, waiting, disabled, focus, hover, search focus and the keyboard up, in each theme the product ships and at each size, text size or width `ui-design`'s "Review gate" asks for, largest and smallest layouts first. On a branch's finished interface, every screen the branch touched, judged as a whole, in all of those.
- **Each missing capture sorted by its cause.** When the brief lacks a capture of a touched state or of its reference screen, sort it into the cases in [missing captures](references/missing-captures.md): No reference exists, Broken build, Verify skill short, Run blocked or Run short.
- **The diff beside the captures.** Tokens, hand-set values and the components a screen is built from do not show in pixels, so read the diff for them.
- **The owner's own reviews.** Search the session record for the owner's past corrections on the screen's subject, such as its alignment, spacing, wording or prominence. Judge a correction that applies as a rule, cited by session and time.

## Judge

- **Against a named reference screen.** Each screen cites the reference screen its platform reference in `ui-design` names, and each shot sits beside that reference's capture in the same theme and size, or for a terminal at the same width. A screen that cites no reference it has is a finding. A screen whose platform reference names no reference screen it can reach is a conflict for the owner.
- **Measured, not only looked at.** Check alignment, equal margins, shared baselines and type size, and that nothing jumps: compare each element's position between the states, and between sibling screens that share a layout. Take positions from the frames in the capture's accessibility dump where the project's verify skill emits one, else from the capture. Measure contrast and target size against `ui-design`'s "Responsive and accessible behavior" and the figures the platform reference sets. Blur the capture to check the primary element still dominates.
- **UX as well as UI.** Walk the flow through each step, its exits and its undo, and check it against Nielsen's ten usability heuristics, naming the heuristic a finding breaks. Read the wording against the reference screen's and against `ui-design`'s "State and interaction". Check each element's prominence against how often it is used, as `ui-design`'s "Before designing" says.
- **Tokens and design systems.** Judge the diff against `ui-design`'s "Visual contract", its "Preserve the product's established visual language" included, and on a native Apple screen built from system components, its "System components, never hand-rolled styles". A literal repeated across screens, or a hand-set value equal to the default of the component it sets, is a finding. On a product with no system yet, each finding moves the screen toward one shared token set and component system.
- **On its merits.** A screen that looks wrong is a finding, even when no rule, reference, owner correction or cited source names the flaw, and whatever a brief, a plan, a coordinator or an earlier commit asked for. Only a design decision the owner made binds this review: when the screen shows that decision looks wrong, it goes under Conflicts. A choice between options that each look right stays the owner's, under Conflicts. A departure from the reference screen's layout, components or wording, or from an established pattern, is a finding unless evidence supports it. A value that differs from the reference's because the screen takes a project token is no departure.

## Report

Report in the review report shape from `principles`, with the verdict the caller asks for. Each finding's **Where** names the screen, the state, the theme, the size and the capture or frame it rests on, plus `file:line` where the diff holds the cause. **Severity:** critical when a state hides, clips or loses what the user needs or cannot be operated; major when it breaks a rule, the reference or an owner correction; minor for the rest.
