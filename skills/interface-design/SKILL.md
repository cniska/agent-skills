---
name: interface-design
description: Design or review user interfaces for web or Dart/Flutter products when visual hierarchy, state communication, responsive behavior, and product polish matter.
---

# Interface Design

Design the interface as a coherent product surface, not as a collection of technically valid widgets.

## Before editing

- Read the existing interface, theme tokens, typography, layout primitives and nearby screens before choosing a new shape.
- Find the repository's canonical owner of those tokens and the real target sizes. Extend source tokens or primitives; do not edit generated output or invent a viewport contract the product does not have.
- Search the project's history for visual corrections and reuse the lessons that apply. Treat repeated fixes as requirements: alignment, surface contrast, spacing, text scaling, state clarity and calm degradation.
- Name the primary question the screen answers. Keep the first viewport focused on that question; move investigation detail behind deliberate disclosure.

## Visual contract

- Design tokens are the visual source of truth. Put surfaces, text, borders, spacing, type scale, radii, breakpoints and motion values in the canonical token layer; UI code contains no unexplained design constants. Local numbers that belong to a component's layout algorithm remain local and named by their purpose.
- Use the shared token set consistently. Do not scatter one-off values through widgets or styles, and do not edit generated token output.
- Preserve the product's established visual language. When one does not exist, choose a restrained visual system that supports the product's audience and primary question, then express it through shared tokens.
- Establish hierarchy before decoration. Align edges, bands, columns and repeated rows. Consistent gaps matter more than ornamental containers.
- Let text, labels, shape and placement carry meaning. Color may reinforce a role or state but never carries it alone. Keep independent semantic dimensions—such as role, location and state—separate.
- Show the smallest useful supporting detail beside the primary fact. Do not invent metrics, activity, controls or empty decorative panels to make a screen feel complete.

## State and interaction

- Model states explicitly rather than combining scattered booleans. Map the product's real domain states to distinct words and structure; do not force a generic running, waiting, blocked, failed, stale or completed taxonomy onto a different domain.
- Make loading, empty, unavailable and stale states calm and honest. Old data must not look live, and an unavailable source must not silently become fabricated content.
- Use motion only to explain a changed fact or connection state. Respect reduced-motion settings and avoid continuous animation that competes with reading.
- Keep controls proportional to the actual product boundary. A visibility surface should not grow administrative actions merely because the underlying data can support them.

## Responsive and accessible behavior

- Check the interface at its real presentation sizes, including fullscreen desktop and narrow mobile or pane layouts where relevant. If the product has no established targets, choose them from how the surface is actually used.
- Preserve the reading order when columns collapse. Do not solve narrow layouts by clipping, shrinking text below comfortable reading size, or letting headings and controls collide.
- Respect browser text enlargement and Flutter text scaling. Verify long labels, localization growth and status messages in the same layout.
- Keep focus, contrast and non-color meaning perceivable without turning the surface into a high-contrast warning board.

## Review gate

Before calling the interface done, use representative fixture data that exercises the meaningful domain states, long labels and empty or stale sources. Review screenshots or the running surface at the target sizes in addition to automated checks. Ask an independent reviewer when the workflow provides one; otherwise record a deliberate self-review against hierarchy, alignment, spacing, contrast, typography, state clarity, responsive behavior and whether every visible element earns its place.

## Red flags

- Choosing a new visual language before reading the existing one
- Using color, animation or decorative metrics to manufacture hierarchy
- Treating a passing test suite as evidence of visual quality
- Letting narrow layouts clip, collide or hide the primary question
- Adding one-off tokens or state flags instead of extending the shared model
