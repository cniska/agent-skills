# Apple platforms

Load this for a native screen on macOS or iOS built from system components, before its first sketch or its review. On iOS, read [Mobile](mobile.md) beside it for what every phone shares, such as touch targets, reach, safe areas, the keyboard, back navigation and permission prompts. Each rule names the platforms its evidence covers; a rule marked macOS has no iOS evidence yet, so on iOS check it against an iOS reference screen before applying it.

## Copy a first-party screen (macOS, iOS)

- Start every screen from the closest first-party screen for the same job, captured from the real app on the target OS version, and cite that capture in the change. A layout built from the Human Interface Guidelines' prose alone reads as plausible and still misses Apple's conventions; the guidelines are a lookup, not the design.
- Name the screen copied and what was taken from it: container, stack, control set, wording. Its values are never taken, as the Visual contract in `ui-design` says.
- A project's own map of which of its screens copies which reference lives in that project's own skill, not here.

## System components, never hand-rolled styles (macOS, iOS)

- Build from system controls and containers, in SwiftUI `Form`, `GroupBox`, `Grid`, `LabeledContent` and the built-in button styles, with system text styles and semantic colors at their default metrics. Leave padding, font size, weight, corner radius, color and material to the system wherever it has one.
- To remove a hand-set value, choose the container whose default gives the reference screen's spacing, such as a `Form` section in place of a stack, rather than deleting the value and taking whatever default is left.
- A notice the user must act on, such as a wrong PIN, takes the text style the reference screen gives it, never footnote or caption type.
- In a grouped settings form, each field takes the alignment the reference capture shows from the container's default, never a hand-set alignment; where the default differs from the capture, change the container, as above. Its width takes a token, as the next line says.
- A value the system has no default for, such as a window size or a field width, takes the project token for its role, never the reference screen's value; a new token is added only when none fits.

## Wording

- Titles and buttons take Apple's phrasing and title case, read from the bundle of the app that does the job rather than written from memory.
- Field labels in a macOS password sheet or dialog end in a colon ("Password:", "Verify:" in Notes, Disk Utility and System Settings' Change Password sheet). Notes on iOS labels the same fields without one ("Password", "Verify", "Hint"), with the placeholders "Required" and "Recommended". Rows of a grouped settings form take their labels as the reference capture shows them.

## Where to look (macOS, iOS)

- **Bundle string tables** of the app or framework that does the job give the exact titles, labels, placeholders, messages and buttons, but no layout. A framework both platforms share holds strings for both, so a string in a table is not proof the screen shows it on that platform.
- **Screenshots of the real app** on the target OS version, in light and dark, give layout and control choice.
- **Apple's docs:** the Human Interface Guidelines and API reference.
- **Third-party apps** are secondary evidence only: they show a pattern to compare or avoid, never the screen to copy.

## Reference screens

Capture the named screen before copying it: this table names screens, it holds no captures.

| Job | macOS | iOS | Guidelines page |
|---|---|---|---|
| Settings | System Settings panes; Mail's and Safari's Settings windows | The Settings app | `settings` |
| Form in a sheet | Notes' Set Password sheet; System Settings' Change Password sheet | Notes' password screen (`ICPasswordChangeViewController` in `NotesUI`) | `sheets` |
| Alert, confirmation | Finder's Empty Trash alert | Mail's action sheet on cancelling a draft | `alerts`, `action-sheets` |
| Onboarding | Passwords' welcome, "Welcome to the Passwords App" | Passwords' welcome | `onboarding` |
| List and detail | Notes' and Passwords' main windows | Notes, Mail | `split-views`, `lists-and-tables` |

Each guidelines page sits under `design/human-interface-guidelines/`.

## Proof (macOS, iOS)

- Set each shot beside its reference screen's capture, in the same theme and at the same size, so the fresh agent running `ui-review` judges the pair.
