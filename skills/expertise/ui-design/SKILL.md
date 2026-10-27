---
name: ui-design
description: Design user interfaces, native Apple-platform screens included. Use when building or changing a screen where visual hierarchy, state communication, responsive behavior, and product polish matter.
---

# UI Design

Design the interface as a coherent product surface, not as a collection of technically valid widgets.

## Before designing

- Read the existing interface, theme tokens, typography, layout primitives and nearby screens before choosing a new shape.
- Find the repository's canonical owner of those tokens and the real target sizes. Extend source tokens or primitives; do not edit generated output or invent a viewport contract the product does not have.
- Search the project's history for visual corrections and reuse the lessons that apply. Treat repeated fixes as requirements: alignment, surface contrast, spacing, text scaling, state clarity and calm degradation.
- For a native screen on an Apple platform, read [Apple platforms](references/apple.md) first.
- Name the primary question the screen answers. Keep the first viewport focused on that question, and give each element the prominence its frequency of use earns: what people need often stays up front, and a rare path, such as account recovery, sits behind a small, clearly labeled control ([NN/g: progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/)).

## Visual contract

- Design tokens are the visual source of truth; on a native platform the system's text styles, semantic colors and control metrics are those tokens. Put surfaces, text, borders, spacing, type scale, radii, breakpoints and motion values in the canonical token layer; UI code contains no unexplained design constants. Local numbers that belong to a component's layout algorithm remain local and named by their purpose.
- Use the shared token set consistently, choosing each token by its role, never because its value matches ([Atlassian](https://atlassian.design/foundations/tokens/design-tokens)). Do not scatter one-off values through widgets or styles, and do not edit generated token output.
- Preserve the product's established visual language; for a native app that is the platform's own, taken from its first-party screens. When neither exists, choose a restrained visual system that supports the product's audience and primary question, then express it through shared tokens.
- Establish hierarchy before decoration. Align edges, bands, columns and repeated rows, and keep an element that sibling screens share, such as the field of each step in a flow, at the same position on each. Consistent gaps matter more than ornamental containers.
- Let text, labels, shape and placement carry meaning. Color may reinforce a role or state but never carries it alone. Keep independent semantic dimensions—such as role, location and state—separate.
- Show the smallest useful supporting detail beside the primary fact. Do not invent metrics, activity, controls or empty decorative panels to make a screen feel complete.

## State and interaction

- Model states explicitly rather than combining scattered booleans. Map the product's real domain states to distinct words and structure; do not force a generic running, waiting, blocked, failed, stale or completed taxonomy onto a different domain.
- Make loading, empty, unavailable and stale states calm and honest. Old data must not look live, and an unavailable source must not silently become fabricated content.
- An error says what happened and how to fix it, in text beside what caused it, never as a bare code ([HIG: Writing](https://developer.apple.com/design/human-interface-guidelines/writing), [GOV.UK](https://design-system.service.gov.uk/components/error-message/)).
- Nothing jumps: no element moves, resizes or reflows because another appeared, disappeared or changed, such as an error message under a field. Reserve the space a message that comes and goes needs, or keep it where it pushes nothing.
- Move only what the user asked to move, with the platform's own transition, and use motion otherwise only to explain a changed fact or connection state. Respect reduced-motion settings and avoid continuous animation that competes with reading.
- Keep controls proportional to the actual product boundary. A visibility surface should not grow administrative actions merely because the underlying data can support them.

## Responsive and accessible behavior

- Check the interface at its real presentation sizes, including fullscreen desktop and narrow mobile or pane layouts where relevant. If the product has no established targets, choose them from how the surface is actually used.
- Preserve the reading order when columns collapse. Do not solve narrow layouts by clipping, shrinking text below comfortable reading size, or letting headings and controls collide.
- Respect the platform's text enlargement and scaling settings. Verify long labels, localization growth and status messages in the same layout.
- Keep focus, contrast and non-color meaning perceivable without turning the surface into a high-contrast warning board, to at least [WCAG 2.2](https://www.w3.org/TR/WCAG22/) AA: text contrast 4.5:1, or 3:1 for large text, and 3:1 for control boundaries and states; pointer targets 24 by 24 CSS pixels or spaced to match; text enlarged to 200% with nothing lost.

## Review gate

Before calling a design done, use representative fixture data that exercises the meaningful domain states, long labels and empty or stale sources. Before the owner sees it, capture each state it touches at the target sizes and the largest text size, in each theme the product ships, light and dark, and check the pixels for alignment, equal margins, shared baselines and type size; automated checks do not stand in for this. Then a fresh `designer` agent that did not make the change runs `ui-review` on the same shots, and the change waits for its accept; the author's own look never stands in for it.

## See also

- `ui-review` — how a fresh agent judges the running interface against these rules

## Red flags

- Choosing a new visual language before reading the existing one
- Using color, animation or decorative metrics to manufacture hierarchy
- Treating a passing test suite as evidence of visual quality
- Letting narrow layouts clip, collide or hide the primary question
- An element that shifts because a message or control appeared beside it
- A native screen designed from the guidelines' prose with no first-party screen copied
- Adding one-off tokens or state flags instead of extending the shared model
