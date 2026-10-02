---
name: explain-diff
description: Explain a diff's intent and risk in the session, then quiz the reader on it, so a change is grasped before review, handoff, or merge. Use when a change is complex, unfamiliar, or headed to other people.
argument-hint: "[pr-url-or-number]"
---

# Explain diff

A diff shows *what* changed. It never shows *why*, *what to worry about*, or *whether you actually understood it*. This skill recovers the first two — intent and risk — and then tests the third: you do not pass on a change whose explanation you cannot give. It explains and gates; it does not judge (that is `review`) or sell the change for merge (that is `pr`).

Written for readers who read code fluently. Explain the why and the risk, never the what — the diff carries the what. High-signal, not a tutorial: no beginner walkthrough, no narrating mechanics the diff already shows.

Three modes: **Self** (no argument) — current branch diff against `main`, including uncommitted changes; **PR** (URL or number) — someone else's PR; **Commit** (a sha or range) — `git show` or `git diff` of it, with its messages as stated intent.

## Workflow

1. **Gather the change and its intent.** Intent is *stated* in spec IDs, design notes, ADRs, commit messages, or a linked issue — find it before inferring. **Self:** diff the current branch against `main` (`git diff main...HEAD`, plus `git diff HEAD` for uncommitted work); read `git log main..HEAD` for commit messages, and for an uncommitted change check the diff's own spec/doc hunks first — read those and the small contract files before the biggest code hunk, and treat them as the commit message you do not have. **PR:** fetch with `gh pr diff <N>` and read intent from `gh pr view <N>` — the description and any linked issue. Prefer stated intent to inferred; the code says what it does, never what the author meant. Unless this session is already a fresh agent that has not seen the change, delegate the whole gather-and-draft pass to one whenever available, whatever the diff's size — a session that touched the change explains its own mental model back, and the gaps it papers over are exactly the ones it cannot see. Hand the agent only where to look: repo or worktree path, diff range or PR number, and tooling quirks it would otherwise trip on (a shell proxy that rewrites command output, an unusual build). Never your intent, rationale, alternatives weighed, or findings — a cold reader that converges on your reading independently is signal; one you briefed is an echo. Run it on a **balanced-tier** model or better. Keep the comprehension gate in this session regardless: the reader answers it, not a delegate.
2. **Name the change's goal** and the problem it solves, then the separable parts that deliver it. Group hunks by part, not by file — a part that spans five files is one story, not five. Git's hunk-header heuristic can mislabel the enclosing function; verify against the file rather than trusting the diff's own labels.
3. **For each part, give three things:** the **intent** (what it is for), the **load-bearing decision and the alternative not taken** (why this shape), and the **risk** (what could break, what a reviewer should scrutinize).
4. **Surface the non-obvious.** Implicit contracts touched, invariants relied on, ordering or concurrency, migrations, **trust dependencies** (where one component assumes an invariant another enforces without checking it — especially across a process or network boundary), anything a careful reader would miss on a first pass.
5. **Separate stated from inferred.** Never present an inferred *why* as fact. A reverse-engineered intent no source confirms is a guess — mark it as one.
6. **Stay high-signal.** Omit what the diff makes obvious. Mechanical renames, moves, and reindentation earn one line, generated files none. Measure length against the change's *meaning*, not its line count.

## Output

Write the explanation in the session as Markdown — the builder's account of the change, the way a plan is the planner's and a review the reviewer's. Lead with the change's goal and the problem it solves, then one `##` section per part with its intent, the load-bearing decision and the alternative not taken, and its risk. Close with **What to scrutinize** (the parts a reviewer must not skim) and **Assumptions I could not confirm** (inferred intent, flagged). Size it to the change's meaning: a narrow change is a few sentences under each heading, and a section with nothing to say is omitted. No code blocks restating the diff.

Spell out abbreviations and acronyms on first use. Gloss an unfamiliar or domain-specific term in a short parenthetical; when several recur throughout, front-load one short glossary instead, then use the terms bare.

## Comprehension gate

After the explanation, quiz the reader yourself, one question at a time: a few multiple-choice questions, medium difficulty — *why this shape and not the alternative, what breaks if X changes, where the invariant lives*, never trivia or gotchas. One correct answer per question, with plausible distractors drawn from real misunderstandings of the diff and nothing that gives the answer away by position or phrasing. Ask through the harness's multiple-choice question tool where it has one, otherwise in plain text. Tell the reader whether each answer was right and why before asking the next, and end with the score and the parts of the change a wrong answer points back to.

The gate is a rule, not education: **you do not pass on code whose explanation you cannot give.** A wrong answer sends the reader back to that part of the diff or to its author before the change is merged, handed off, or shipped. With no human in the session — a subagent, a scheduled run — open the gate with **Understanding: unchecked**, list the questions without answers, and return the answer key to the caller separately from the explanation.

## See also

- `review` — judge the change once it is understood; explain-diff builds the understanding review acts on
- `pr` — describe the change for merge; explain-diff is for grasping it, not the PR body
- `spec` — the source of stated intent; cite its IDs rather than inferring
- `debug` — when the risk is behavioral, a minimal repro proves it rather than asserting it

## Red flags

- Presenting inferred intent as stated fact
- No "what to scrutinize" — an explanation that names no risk explained nothing
- A walkthrough so long the reader would rather just read the diff
- Asking the gate's questions all at once, revealing answers before the reader commits, or a guessable gate — correct answer in a fixed position, or a distractor that's a joke, an impossible claim, or trivia instead of a plausible misunderstanding
- Briefing the subagent with your intent, rationale, or findings, so it grades your reading instead of forming its own
- Trusting a diff's hunk-header function label without checking it against the file
