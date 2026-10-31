---
name: ui-design
description: Design or change a screen so it reads as one product with its siblings — a web page, a mobile phone or tablet screen, a native Apple screen, or a terminal command's output or TUI — with its layout, states, dark mode, touch targets and the keyboard holding at every size it ships. Use when building or changing a screen, page, sheet, command output or TUI.
---

# UI design

Design each screen as part of one coherent product: built from the product's tokens and components, laid out so its main question comes first, honest about every state it can be in, and usable at every size, theme and text size it ships in.

## Before designing

- Read the existing interface first: its theme tokens, typography, layout primitives and the screens nearby. Find the repository's canonical source of those tokens and the product's real target sizes, and change that source rather than its generated output.
- Search the project's history for the owner's visual corrections and apply each one that fits the screen. Treat a correction made more than once as a requirement, such as on alignment, surface contrast, spacing, text scaling or state clarity.
- Read the reference for the screen's platform, and only that one: [Web](references/web.md) for a page a browser renders; [Mobile](references/mobile.md) for a phone or tablet screen, Flutter or native; [Apple platforms](references/apple.md) for a native macOS or iOS screen built from system components, read beside Mobile on iOS; [Terminal](references/terminal.md) for a command's help, errors, progress and output, and a TUI's screens. Each names the reference screen to start from and what its Proof captures.
- Name the primary question the screen answers, and keep the first viewport on it. Give each element the prominence its frequency of use earns: what people need often stays up front, and a rare path, such as account recovery, sits behind a small, clearly labeled control.

## Visual contract

- **Design tokens are the visual source of truth.** Put surfaces, text, borders, spacing, type scale, radii, breakpoints and motion values in the canonical token layer. On a native screen built from system components, the system's text styles, semantic colors and control metrics are those tokens. A number that belongs to one component's layout algorithm stays local, named by its purpose.
- **Choose each token by its role,** never because its value matches. A reference screen gives layout, components and wording, never values: where it shows a size, gap or color, take the project token for that role. Use the existing scale, since a one-off value or an invented step beside it splits the system. Build each role, such as a sheet, a button or a field, from its one shared component.
- **Preserve the product's established visual language.** A product with its own design system, such as a Flutter app built from its own UI package and token source, extends that system first. A native screen built from system components takes the platform's own, from its first-party screens. Where neither exists, choose a restrained visual system that fits the product's audience and primary question, and express it through shared tokens.
- **Establish hierarchy before decoration.** Align edges, bands, columns and repeated rows. Keep an element that sibling screens share, such as the field of each step in a flow, at the same position on each. Use one gap per relationship: the same above and below a group, the same between tiles across and down, and the same padding on all four sides of text inside a control or card. An inner corner rounds less than the corner that holds it, and an overlay stands apart from what lies behind it in every theme.
- **Carry meaning in text, labels, shape and placement.** Color reinforces a role or state and always has a second carrier. Spend the accent on one role, such as links or the primary action, and keep it off decoration. Keep independent dimensions, such as role, location and state, separate.
- **Show the smallest useful supporting detail beside the primary fact,** and only real data: a screen that feels sparse stays sparse rather than gaining invented metrics, controls or empty panels.

## State and interaction

- **Model states explicitly** rather than as scattered booleans, and map the product's own domain states to distinct words and structure, never a generic set borrowed from another domain.
- **Keep loading, empty, unavailable and stale states calm and honest.** Old data is marked as old, and an unavailable source says so in place of content. A loading placeholder takes the geometry of what it stands in for, with one loading pattern across the product. A full-screen empty, first-load or failure state centers on the screen, not on the space under the header.
- **An error says what happened and how to fix it,** in words beside what caused it, with any code secondary. A field's label stays visible while it is filled in, and a field marked invalid stays marked while focused.
- **A destructive action confirms in proportion to what it destroys,** and names what it destroys in words as well as color.
- **Going back returns the person to where they were,** scroll position and entered text included.
- **Nothing jumps.** No element moves, resizes or reflows because another appeared, disappeared or changed, such as an error under a field or a busy button's spinner. Reserve the space for a message that comes and goes, or place it where it pushes nothing. A number that changes in place takes tabular figures, and data that arrives in parts lands at once.
- **A setting applies the moment it is chosen,** and a stored appearance or language applies before the first frame, so the screen never flashes the other one.
- **Move only what the user asked to move,** with the product's own transition, or the platform's on a native screen built from system components. Otherwise use motion only to explain a changed fact or connection state, honor reduced-motion settings, and keep continuous animation away from what people read.
- **Keep controls proportional to the product's boundary:** a screen for seeing something offers the actions its job needs, not every action its data could support.

## Responsive and accessible behavior

- Check the interface at its real presentation sizes, including fullscreen desktop and narrow mobile or pane layouts where they apply. Where the product has no established targets, choose them from how the surface is actually used.
- Keep the reading order when columns collapse. A narrow layout reflows: nothing clips, text stays at a comfortable reading size, and headings and controls never overlap.
- Give every drag or gesture a visible alternative, such as a button beside a swipe action.
- Follow the platform's text enlargement and scaling settings, and check long labels, localized text and status messages in the same layout.
- Meet at least WCAG 2.2 AA without turning the surface into a high-contrast warning board: text contrast 4.5:1, or 3:1 for large text; 3:1 for control boundaries and states; text enlarged to 200% with nothing lost; each target at least the size the platform reference sets, its hit area free to reach past what is drawn. Name a control shown only as a glyph in words a screen reader speaks.

## Review gate

Before calling a design done, fill it with representative fixture data that exercises the meaningful domain states, long labels and empty or stale sources. Capture each state it touches in each theme the product ships, light and dark, at the target sizes and, where the platform scales text, the largest text size, plus what the platform reference's Proof adds. Check the captures yourself for alignment, equal margins, shared baselines and type size, since automated checks miss these. Then a fresh agent that did not make the change runs `ui-review` on the same captures, the `designer` agent where the host can start one and otherwise a subagent that loads `ui-review`, and the change waits for its accept before the owner sees it. The author's own look prepares for that review and never replaces it.
