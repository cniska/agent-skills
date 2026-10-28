# Apple platforms

Load this for a native screen on macOS or iOS built from system components, before its first sketch or its review. On iOS, read [Mobile](mobile.md) beside it for what every phone shares, such as touch targets, reach, safe areas, the keyboard, back navigation and permission prompts. Each rule names the platforms its evidence covers; a rule marked macOS has no iOS evidence yet, so on iOS check it against an iOS reference screen before applying it.

## Copy a first-party screen (macOS, iOS)

- Start every screen from the closest first-party screen for the same job, captured from the real app on the target OS version, and cite that capture in the change. A layout built from the Human Interface Guidelines' prose alone reads as plausible and still misses Apple's conventions; the guidelines are a lookup, not the design.
- Name the screen copied and what was taken from it: container, stack, control set, wording. Its values are never taken, as the Visual contract in `ui-design` says.
- A project's own map of which of its screens copies which reference lives in that project's own skill, not here.

## System components, never hand-rolled styles (macOS, iOS)

- Build from system controls and containers, in SwiftUI `Form`, `GroupBox`, `Grid`, `LabeledContent` and the built-in button styles, with system text styles and semantic colors at their default metrics. No custom padding, font size, weight, corner radius, color or material where the system has one.
- To remove a hand-set value, choose the container whose default gives the reference screen's spacing, such as a `Form` section in place of a stack, rather than deleting the value and taking whatever default is left.
- A notice the user must act on, such as a wrong PIN, takes the text style the reference screen gives it, never footnote or caption type.
- In a grouped settings form, each field takes the alignment the reference capture shows from the container's default, never a hand-set alignment; where the default differs from the capture, change the container, as above. Its width takes a token, as the next line says.
- A value the system has no default for, such as a window size or a field width, takes the nearest project token, never the reference screen's value; a new token is added only when none fits.

## Wording

- Titles and buttons take Apple's phrasing and title case, read from the bundle of the app that does the job rather than written from memory: "Passwords Is Locked" (macOS, and in the iOS runtime's string table), "Enter Recovery Key" and "Set Password" (macOS).
- Field labels in a macOS password sheet or dialog end in a colon ("Password:", "Verify:" in Notes, Disk Utility and System Settings' Change Password sheet). Notes on iOS labels the same fields without one ("Password", "Verify", "Hint"), with the placeholders "Required" and "Recommended". Rows of a grouped settings form take their labels as the reference capture shows them.

## Prompts (macOS)

- **One field:** Passwords' locked window (macOS 26, Touch ID off) shows one centered secure field with the placeholder "Enter password". There is no Unlock button and no arrow; Return submits. The login window and screen-saver unlock carry the prompt in the field's placeholder: "Enter Password", or "Touch ID or Enter Password".
- **Unverified:** Passwords' strings also hold an "Unlock" button, which may appear only with Touch ID on. Copy no Unlock button until a capture with Touch ID on shows one.
- **Several fields:** the sheet keeps a Cancel button and a button named for its action: "Cancel" and "Set Password" in Notes' Set Password sheet and in FileVault's, "Cancel" and "Choose" in Disk Utility's encrypted-image dialog. The strings do not say which is the default button; take that from a capture of the reference screen.

## Where to look (macOS, iOS)

- **Bundle string tables** give the exact titles, labels, placeholders, messages and buttons, but no layout. A `.strings` file reads with `plutil -convert json -o - <file>`; a `.loctable` is one plist keyed by locale, and some hold no `en`, so read `en_GB`. Strings compiled into a nib show with `strings` on the nib.
  - macOS: under `/System/Library/PrivateFrameworks/<Name>.framework/Versions/A/Resources/`, `/System/Applications/<App>.app/Contents/Resources/` and `/System/Library/CoreServices/`.
  - iOS: frameworks at `System/Library/PrivateFrameworks/<Name>.framework/` and apps at `Applications/<App>.app/`, under the Simulator runtime's root, `/Library/Developer/CoreSimulator/Volumes/<volume>/Library/Developer/CoreSimulator/Profiles/Runtimes/<runtime>.simruntime/Contents/Resources/RuntimeRoot`; `xcrun simctl list runtimes` names the installed runtimes.
  - A framework both platforms share holds strings for both, so a string in a table is not proof the screen shows it on that platform.
- **Screenshots of the real app** on the target OS version, in light and dark, give layout and control choice.
- **Apple's docs:** a Human Interface Guidelines or API reference page serves JSON at `https://developer.apple.com/tutorials/data/<path>.json`, where `<path>` is the page's URL path, such as `design/human-interface-guidelines/sheets` or `documentation/swiftui/form`. Its prose reads with `jq -r '[.. | .text? // empty] | join(" ")'`.
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
