# Mobile

Load this for a phone or tablet screen, before its first sketch or its review: a Flutter screen on either platform, a native Android screen, and a native iOS screen beside [Apple platforms](apple.md). It holds what every phone and tablet shares; what is Apple's own stays in that reference. Where the product has primitives and tokens of its own, they come before every default below.

## Reference screen

- A product with a design system of its own, as a Flutter app built from its own widget package usually has, starts from the product's existing screen that does this job: capture it from the running app, at the target size and in the theme the new screen ships, and cite the capture.
- The first-party rule in [Apple platforms](apple.md) covers a native iOS screen built from system components. It does not cover a Flutter screen built from the product's own primitives, which extends the product's screen instead.
- With no established screen: on iOS, the first-party screen that reference names; on Android, the first-party Android screen for the same job, such as Settings, Contacts or Messages, captured from a running device or emulator, or the Material component rendered on a device or emulator at the screen's target size and theme.
- Material's guideline pages show images and video, not live components, so they are not a capture. The Material web catalog renders live components but trails the current Material release, so a device capture wins over it.
- A third-party app is evidence to compare against, never the starting screen.

## Layout and screen sizes

- Lay out by the window's width class, never by device type, a tablet flag or orientation: compact below 600 dp, medium from 600 to 839, expanded from 840. Rotation, split screen and folding change the class while the app runs, so read it from the window each time, in Flutter from `MediaQuery.sizeOf`.
- A compact window shows one pane; an expanded one shows a list beside its detail. On a wide window, fields and text keep a readable width rather than stretching edge to edge.
- Every orientation and window size keeps the same features and the state on screen; a product that locks orientation says so in its own rules.
- Backgrounds and scrolling lists run edge to edge, under the status bar, the notch and the home indicator or gesture bar; text and controls stay inside the safe area, and a list clears the bottom inset inside its scroll padding so its last row scrolls clear. In Flutter, wrap the body in `SafeArea`, not the whole `Scaffold`; on Android, inset tappable views by the system bars and the display cutout, and swipeable ones by the system gesture insets.
- Put what is used most in the lower half, where a thumb reaches; a rare or destructive control may sit at the top.

## Navigation

- Three to five top-level destinations take a bottom navigation bar on a compact window and a navigation rail from medium up; fewer than three take tabs. Each destination has a one- or two-word label that never truncates, and the selected one is filled as well as colored. A navigation drawer is not used for top-level destinations; a rail that expands takes its place.
- One navigation model per app: every screen goes through the router, so the system back, the on-screen back button and, on iOS, the edge swipe do the same thing. A screen with a back button also takes the back swipe, except where a swipe would lose what was entered, which asks first.
- Back closes what is open and nothing else: it is never taken for logging or a custom prompt, and at the root it leaves the app.
- A sheet drags down by its grip to close, scrolls its own content, stops below the status bar and rises with the keyboard.

## Type

- Text follows the system text size, Dynamic Type on iOS and the font scale on Android, to its largest setting: sizes in sp or through Flutter's `TextScaler`, never fixed. At the largest size rows grow, labels wrap and a sheet scrolls; the primary text is never clipped or cut short.
- Body text is at least 16 sp on Android and 17 pt in a native iOS screen, and no text is below 11 sp, or 11 pt in a native iOS screen.

## Color and theme

- Follow the system's light or dark setting unless the person picks one in the app.
- With Material, use each color role only in its pair, `on-X` text on an `X` fill, and never a container role as text; dynamic color applies only where the product has no palette of its own.
- The status bar and navigation bar icons contrast with what lies under them in each theme.

## Controls and forms

- Build from the product's primitives. With none, use Material 3 components, and in a Flutter app that follows each platform, the `.adaptive` constructors of `Switch`, `Slider`, `Checkbox`, `Radio`, the progress indicators and `AlertDialog`. Never override the platform's back behavior, page transitions, scroll physics or text selection.
- Each field opens the keyboard for its content, a number pad, a phone pad, email or URL, and its Return key names the next step, such as next, search or done, and moves there. Set autofill hints, `autofillHints` in Flutter, on every field the system can fill.
- A field's error replaces its helper text in the same slot, so nothing shifts.
- The whole row of a switch or checkbox is its target, and its label says what it governs.
- A form's commit button stays reachable with the keyboard up.

## States

- Every tappable element shows a pressed state on the frame it is touched.
- A phone loses its network mid-use: say so where the data is, keep what already loaded readable, and retry once the network returns.
- Coming back to the app after the system ended it in the background restores the same screen, scroll position and entered text.

## Motion

- Use the platform's page transitions or the product's own motion tokens: short, near 200 ms, for a control, and longer, near 400 to 500 ms, for a change the size of the screen.
- Honor Reduce Motion on iOS and removed animations on Android, in Flutter `MediaQuery.disableAnimationsOf`: a move becomes a fade or a cut.
- An animation for one event runs every time or never, and finishes before the next change starts.
- A haptic confirms a commit, never every tap, and the system's own haptics setting silences it.

## Input

- Touch targets are at least 48 by 48 dp on Android and in a Flutter app, and 44 by 44 pt in a native iOS screen, at least 8 dp apart. The target may hang into the padding around a smaller glyph, whose visible edge still aligns with its neighbors.
- No gesture claims the screen edges the system uses for back and home. A long press is only ever a shortcut.
- The keyboard never covers the focused field, its sheet or the commit button: the screen gives up the keyboard's inset, in Flutter through `Scaffold`'s `resizeToAvoidBottomInset` and `MediaQuery.viewInsetsOf`, on Android through `imePadding`, and scrolls the field into view. Scrolling or tapping outside the field dismisses the keyboard.
- On a tablet, a hardware keyboard, a pointer and a trackpad work too: focus moves in order with Tab, shows a visible focus state, and a pointer shows hover.

## Interruptions and permissions

- Ask for a permission when the person starts the feature that needs it, never at launch. A screen before the system prompt says why in one sentence and has one button, which opens the prompt.
- After a refusal, the feature degrades in place, says what is off and links to the app's page in Settings; it never asks again on each visit.
- A call, a notification, the app switcher or a move to the background leaves the screen intact: input kept, a timer or game paused, and content the product treats as secret hidden in the app switcher's snapshot.

## Accessibility

- Every control has a label TalkBack and VoiceOver read, naming its purpose without its type, "Delete" rather than "Delete button"; decorative images are hidden, and a row's parts read as one element, in Flutter through `Semantics` and `MergeSemantics`.
- Check with TalkBack or VoiceOver, at the largest text size, with bold text and with reduced motion.

## Proof

- Capture each state on the smallest and the largest phone the product targets, and a tablet where it ships one, in each theme, at the largest text size and with the keyboard up on every screen with a field, and set each shot beside its reference capture on the same size and theme. Take frames from the semantics tree where the project's verify skill dumps one.
