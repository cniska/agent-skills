---
name: ui-design
description: Design user interfaces for the web, mobile phones and tablets, the terminal and native Apple platforms. Use when building or changing a screen, page, sheet, command output or TUI where layout, touch target size, the keyboard, dark mode, state communication, visual hierarchy, responsive behavior and product polish matter.
---

# UI Design

Design the interface as a coherent product surface, not as a collection of technically valid widgets.

## Before designing

- Read the existing interface, theme tokens, typography, layout primitives and nearby screens before choosing a new shape.
- Find the repository's canonical owner of those tokens and the real target sizes. Extend source tokens or primitives; do not edit generated output or invent a viewport contract the product does not have.
- Search the project's history for visual corrections and reuse the lessons that apply. Treat repeated fixes as requirements: alignment, surface contrast, spacing, text scaling, state clarity and calm degradation.
- Read the references for the screen's platform first, and no others: [Web](references/web.md) for a page a browser renders; [Mobile](references/mobile.md) for a phone or tablet screen, Flutter or native; [Apple platforms](references/apple.md) for a native macOS or iOS screen built from system components, read beside Mobile on iOS; [Terminal](references/terminal.md) for a command's help, errors, progress and output and a TUI's screens.
- Name the primary question the screen answers. Keep the first viewport focused on that question, and give each element the prominence its frequency of use earns: what people need often stays up front, and a rare path, such as account recovery, sits behind a small, clearly labeled control.

## Visual contract

- Design tokens are the visual source of truth; on a native screen built from system components, the system's text styles, semantic colors and control metrics are those tokens. Put surfaces, text, borders, spacing, type scale, radii, breakpoints and motion values in the canonical token layer; UI code contains no unexplained design constants. Local numbers that belong to a component's layout algorithm remain local and named by their purpose.
- Use the shared token set consistently, choosing each token by its role, never because its value matches. Do not scatter one-off values through widgets or styles, and do not edit generated token output. Build each role, such as a sheet, a button or a field, from its one shared component, never a hand-rolled copy beside it.
- Preserve the product's established visual language. A product with its own design system, such as a Flutter app built from its own UI package and token source, extends that system first; a native screen built from system components takes the platform's own, from its first-party screens. When neither exists, choose a restrained visual system that supports the product's audience and primary question, then express it through shared tokens.
- Establish hierarchy before decoration. Align edges, bands, columns and repeated rows, and keep an element that sibling screens share, such as the field of each step in a flow, at the same position on each. Consistent gaps matter more than ornamental containers: one gap for each relationship, the same above and below a group and between tiles across and down, and text inside a control or card padded alike on all four sides. An inner corner rounds less than the corner that holds it, and an overlay stands apart from what lies behind it in every theme the product ships.
- Let text, labels, shape and placement carry meaning. Color may reinforce a role or state but never carries it alone, and the accent is spent on one role, such as links or the primary action, never on decoration. Keep independent semantic dimensions—such as role, location and state—separate.
- Show the smallest useful supporting detail beside the primary fact. Do not invent metrics, activity, controls or empty decorative panels to make a screen feel complete.

## State and interaction

- Model states explicitly rather than combining scattered booleans. Map the product's real domain states to distinct words and structure; do not force a generic running, waiting, blocked, failed, stale or completed taxonomy onto a different domain.
- Make loading, empty, unavailable and stale states calm and honest. Old data must not look live, and an unavailable source must not silently become fabricated content. A loading placeholder takes the geometry of what it stands in for, with one loading pattern across the product, and a full-screen empty, first-load or failure state centers on the screen, not on the space under the header.
- An error says what happened and how to fix it, in text beside what caused it, never as a bare code. A field's label stays visible while it is filled in, and a field marked invalid stays marked while focused.
- A destructive action asks to confirm in proportion to what it destroys, and says what it destroys in words, never by red alone.
- Going back returns the person to where they were, scroll position and entered text included.
- Nothing jumps: no element moves, resizes or reflows because another appeared, disappeared or changed, such as an error message under a field or a busy button's spinner. Reserve the space a message that comes and goes needs, or keep it where it pushes nothing; a number that changes in place takes tabular figures, and data that arrives in parts lands at once.
- A setting applies the moment it is chosen, and a stored appearance or language applies before the first frame, so the screen never flashes the other one.
- Move only what the user asked to move, with the product's own transition, or the platform's on a native screen built from system components, and use motion otherwise only to explain a changed fact or connection state. Respect reduced-motion settings and avoid continuous animation that competes with reading.
- Keep controls proportional to the actual product boundary. A visibility surface should not grow administrative actions merely because the underlying data can support them.

## Responsive and accessible behavior

- Check the interface at its real presentation sizes, including fullscreen desktop and narrow mobile or pane layouts where relevant. If the product has no established targets, choose them from how the surface is actually used.
- Preserve the reading order when columns collapse. Do not solve narrow layouts by clipping, shrinking text below comfortable reading size, or letting headings and controls collide.
- Every drag or gesture has a visible alternative, such as a button beside a swipe action.
- Respect the platform's text enlargement and scaling settings. Verify long labels, localization growth and status messages in the same layout.
- Keep focus, contrast and non-color meaning perceivable without turning the surface into a high-contrast warning board, to at least WCAG 2.2 AA: text contrast 4.5:1, or 3:1 for large text, and 3:1 for control boundaries and states; text enlarged to 200% with nothing lost; each target at least the size the screen's platform reference sets, its hit area free to reach past what is drawn. A control shown only as a glyph is named in words a screen reader speaks.

## Review gate

Before calling a design done, use representative fixture data that exercises the meaningful domain states, long labels and empty or stale sources. Before the owner sees it, capture each state it touches at the target sizes and the largest text size, in each theme the product ships, light and dark, and check the pixels for alignment, equal margins, shared baselines and type size; automated checks do not stand in for this. Then a fresh agent that did not make the change runs `ui-review` on the same shots, the `designer` agent where the host can start one and otherwise a subagent that loads `ui-review`, and the change waits for its accept; the author's own look never stands in for it.

## See also

- `ui-review` — how a fresh agent judges the running interface against these rules

## Red flags

- Choosing a new visual language before reading the existing one
- Using color, animation or decorative metrics to manufacture hierarchy
- Treating a passing test suite as evidence of visual quality
- Letting narrow layouts clip, collide or hide the primary question
- An element that shifts because a message or control appeared beside it
- A native screen designed from the guidelines' prose with no first-party screen copied
- A screen held to the platform's own look where the product has a design system of its own
- Adding one-off tokens or state flags instead of extending the shared model
