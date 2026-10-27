# Terminal

Load this for what a person reads and sees in a terminal, before its first draft or its review: a command's help, errors, progress and output for people, and a TUI's screens. Which stream carries what, the exit codes, help on request and the machine-readable mode are `code-writing`'s "Command-line programs" and `design-review`'s "Each output stream has one job"; this reference covers how the text looks and reads.

## Reference screen

- Extend the product's own established command output or TUI screen for the same job: run it in a real terminal at the target width and capture its output text, escape codes kept, and its exit code, and cite that capture.
- With none, name a well-regarded tool doing the same job, such as git or gh for subcommand help and errors, cargo for build progress, or htop or lazygit for a TUI, and capture it the same way.

## Help

- Lead with a one-line description and the usage line, then examples, then the most used flags, then the rest, then where to read more.
- A command run with a required argument missing prints the short form: the description, an example or two and the flags, ending in a pointer to `--help`.
- Flag descriptions start in one column, and a description that wraps hangs under that column, wrapped to the terminal's width.
- `--version` prints `name version` on its first line.
- A mistyped subcommand suggests the nearest one and never runs it.

## Output for people

- Show what the person asked for and what changed, never internals such as resolved paths, option values or dry-run flags; those wait for a verbose flag.
- One shape per kind of output across every command: the same layout for every result of its kind, the same truncation and the same blank line between steps.
- Columns align, numbers align right, and a wrapped line hangs under the first line's text. A truncated list says how much it withheld, such as "… 12 more lines", the same way everywhere.
- Fit the width the terminal reports, and 80 columns where it reports none. On a narrow terminal, a status line stacks its fields rather than cutting them off.
- Be brief on success and still say what changed.
- Red marks errors alone and dim marks secondary text such as metadata; colors come from the terminal's own 16-color palette, so they stay legible on a light or a dark background.

## Errors

- Write `program: message`, or `program:file:line:column: message` where there is a place, lowercase after the prefix and with no closing period. Follow it with the line that says what to do next.
- Group repeated errors into one with a count, and put the line that matters most last, where the eye lands once the output stops.

## Progress

- Print something within 100 ms of starting. Work that runs past a second shows a spinner, or a bar with a count or percentage when the total is known, under one label for the working state.
- Where the stream is not a terminal, nothing animates: one line per step, or nothing.
- Hide a step's log on success and show it on failure.
- Ctrl-C says it is stopping and stops promptly; a second Ctrl-C skips the cleanup.

## TUI screens

- Redraw without flicker: write only what changed, never a full clear per frame, and draw in the alternate screen.
- Re-lay the screen when the terminal resizes, and restore the cursor, the input mode and the main screen on every exit, a crash included.
- Show the keys in a footer or behind `?`; each key does the same thing on every screen, Escape backs out one level, and Ctrl-C quits.
- A counter or timer takes its full width from the first frame, such as `0s`, and the input line keeps its row while hints and shortcuts open around it.

## Prompts

- Prompt only when stdin is a terminal, and give every prompt a flag, so a script never needs one; a no-input mode fails naming the flags to pass. Never echo a password.
- A force flag skips a destructive action's confirmation.

## Accessibility

- A screen reader reads the stream as text, so no meaning rests on box drawing or a spinner glyph alone, and a plain mode prints plain lines.

## Proof

- Capture the output text with its escape codes and the exit code for each state, success, error, empty and long, at 80 columns and at the narrowest width the product supports, in a light and a dark terminal where it uses color, and set each beside its reference capture at the same width.
