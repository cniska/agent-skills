# Web

Load this for a screen a browser renders, a site, a web app or an installed web app, before its first sketch or its review. It holds whatever framework builds the page; a project's own primitives and tokens win over every default here.

## Reference screen

- Extend the product's own established screen for the same job, captured from the running product at the screen's target size and theme, and cite that capture in the change.
- With no established screen, take the matching pattern page of a design system that publishes its rationale, such as GOV.UK's or Atlassian's, capture its live example at the screen's target size and theme, and cite the system and the page.
- Another product's site is a comparison, never the screen extended.

## Layout and screen sizes

- Lay out from the narrowest width up and add a breakpoint where the content breaks, never one per device. Prefer an intrinsic layout, such as a grid of `auto-fill` columns with a minimum width or a wrapping flex row, over a media query.
- Reflow at 320 CSS pixels wide with no horizontal page scroll and nothing hidden; only a data table, a map or media scrolls, inside its own box.
- Ship `<meta name="viewport" content="width=device-width, initial-scale=1">` and never block zoom with `maximum-scale` or `user-scalable`.
- Cap running text near 75 characters a line and a form at a readable width. A wide screen gains margins or a second column, never wider fields.
- Size boxes from their content, never a fixed height that clips at a larger font or a longer translation.
- On a phone browser or an installed web app, set `viewport-fit=cover` and pad by `env(safe-area-inset-*)`; a scrolling page runs to the bottom edge and clears the home indicator inside its scroll padding. Use `dvh` for a full-height layout, since `vh` ignores the browser's own bars.

## Navigation

- Every view a person can return to has its own URL, which Back and Forward restore; a client route never replaces history to hide a step.
- A link navigates and a button acts: an `<a href>` for every destination, so it opens in a new tab and shows its address, and a `<button>` for every action.
- After an action, keep the person where they acted or take them to its result, never to the top of another page.
- Primary navigation keeps one place and one order on every page, and marks the current page with `aria-current` and more than color.
- A step in a multi-step flow has a back link at its top, and asks one question or decision per page.

## Type

- Set font sizes in `rem` so the browser's own text size setting scales them; body text is at least 16 CSS pixels with a line height near 1.5.
- Text survives the reader's spacing overrides, line height 1.5 times the size, paragraph spacing 2 times, letter spacing 0.12 times and word spacing 0.16 times, with nothing clipped or overlapping.
- Load web fonts so they shift nothing: preload the faces the first paint uses, and use `font-display: optional` or a fallback matched with `size-adjust` and the ascent and descent overrides.

## Color and theme

- Ship dark through `prefers-color-scheme`, redefining the color tokens once, with `color-scheme: light dark` so form controls and scrollbars follow, and a `theme-color` meta per scheme.
- Apply a stored theme choice from a script in the `<head>` before the stylesheet paints, so the first paint is never the other theme.
- Pair each surface with the shadow of its own elevation level; in dark, a higher surface is lighter, since a shadow on near-black barely shows.
- A link inside a sentence is underlined; color alone never marks it among words.

## Controls and forms

- Start from the native element: `<button>`, `<a href>`, `<input>`, `<select>`, `<dialog>`, `<details>`. A custom control takes the role, keyboard behavior and states of the native one it replaces.
- A placeholder is never the label; where there is one, it names the action, such as "Search sessions".
- Set `type`, `inputmode` and `autocomplete` on each field, so a phone opens the right keyboard and autofill and password managers work. Allow paste everywhere, and never split a one-time code into boxes that refuse it.
- Ask for each piece of information once per journey, filled in where it was already given.
- Validate when a field is left or the form is sent, never on each keystroke. The message sits by its field and is tied to it with `aria-describedby`, and nothing typed is cleared. A form with several errors also opens with a summary that takes focus and links to each field.
- One primary button per view, labeled with the verb for what it does. Prefer an enabled submit that says what is missing over a disabled one that says nothing.

## States

- Reserve the box of everything that arrives late: `width` and `height` or `aspect-ratio` on every image, video and embed, a `min-height` for content loaded after first paint, kept when the load fails. Insert late content below the viewport or over the page, never above what the reader is reading. Layout shift stays at or below 0.1.
- Every interactive element shows a focus indicator through `:focus-visible`, at least 2 CSS pixels thick and 3:1 against what surrounds it; `outline: none` never ships without its replacement. A sticky header or footer never covers the focused element.
- Content shown on hover also shows on focus, stays while the pointer moves onto it, and closes with Escape. Nothing essential lives on hover alone.

## Motion

- Animate `transform` and `opacity` only, never a property that moves layout.
- Put motion inside `@media (prefers-reduced-motion: no-preference)`, and in script read `matchMedia('(prefers-reduced-motion: reduce)')` and follow its `change` event; reduced keeps a fade where a state change needs one.
- No parallax, scroll-jacking or motion outside the element being scrolled. Anything that moves for more than five seconds on its own, such as a carousel or a muted video, has a pause control.

## Input

- Serve pointer, touch and keyboard at once. Branch on the `pointer` and `hover` media features, never on width or the user agent, and never shrink a target for a fine pointer.
- Pointer targets are at least 24 by 24 CSS pixels, or spaced so a 24-pixel circle on each touches no other; a screen used by touch takes the phone figure in [Mobile](mobile.md).
- Every action works from the keyboard in reading order. Escape closes an overlay and returns focus to the control that opened it, and a modal holds focus inside it, as `<dialog>` opened with `showModal()` does.
- Enter submits nothing while an input method is composing (`isComposing`), so a Japanese or Chinese reader can finish a word.

## Accessibility

- Give the page `lang`, a `<title>` that names the page before the site, one `h1`, headings in order and the `header`, `nav` and `main` landmarks.
- A glyph-only control carries an `aria-label`, and the same words show as a tooltip on hover and focus.
- Announce a status that changes without a reload, such as "Saved", through a `role="status"` region, without moving focus.
- Check by keyboard alone, at 200% zoom, at 320 CSS pixels wide and with a screen reader; an automated audit finds only part of what these find.

## Proof

- Capture each state at 320 CSS pixels and at the widest layout, in each theme, at 200% text size and with keyboard focus shown, and set each shot beside its reference capture at the same width and theme.
- Where a screen loads content after first paint, record its layout shift from a trace of the load.
