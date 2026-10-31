---
name: explain-diff
description: Explain a diff's intent and risk in the session, so a change is grasped before review or merge. Use when asked to explain a change, or when a change is complex, unfamiliar, or headed to other people.
---

# Explain diff

A diff shows *what* changed. It never shows *why* or *what to worry about*. This skill recovers both — intent and risk. It explains; it does not judge (that is `review`) or sell the change for merge (that is `pr`).

Written for readers who read code fluently. Explain the why and the risk, never the what — the diff carries the what. High-signal, not a tutorial: no beginner walkthrough, no narrating mechanics the diff already shows.

## Workflow

1. **Hand the pass to a fresh agent** whenever one is available, whatever the diff's size, unless this session already is one that has not seen the change: a session that touched the change explains its own mental model back, and the gaps it papers over are exactly the ones it cannot see. Hand the agent only where to look: repo or worktree path, and diff range or PR number. Never your intent, rationale, alternatives weighed, or findings — a cold reader that converges on your reading independently is signal; one you briefed is an echo. Run it on a **balanced-tier** model or better. The agent runs steps 2 to 8, or this session does when it is the fresh one or no fresh agent is available; check the draft's claims against the code before presenting it — a cold reader misreads too.
2. **Gather the change.**
   - **The work in this session**, when no PR is named: diff the current branch against `main` plus uncommitted changes, or the session's own commits when it worked on `main`, and read its commit messages. For an uncommitted change, read the diff's own spec/doc hunks and the small contract files before the biggest code hunk, and treat them as the commit message you do not have.
   - **Someone else's PR**, by URL or number: read its diff and description.
3. **Find the stated intent** in spec IDs, design notes, ADRs, commit messages, a PR's description or a linked issue before inferring any. Prefer stated intent to inferred; the code says what it does, never what the author meant.
4. **Name the change's goal** and the problem it solves, then the separable parts that deliver it. Group hunks by part, not by file — a part that spans five files is one story, not five. Git's hunk-header heuristic can mislabel the enclosing function; verify against the file rather than trusting the diff's own labels.
5. **For each part, give three things:** the **intent** (what it is for), the **load-bearing decision and the alternative not taken** (why this shape), and the **risk** (what could break, what a reviewer should scrutinize). Prove a behavioral risk with a minimal repro, as `debug`'s Reproduce step does, rather than asserting it.
6. **Surface the non-obvious.** Implicit contracts touched, invariants relied on, ordering or concurrency, migrations, **trust dependencies** (where one component assumes an invariant another enforces without checking it — especially across a process or network boundary), every site that branches on what changed (an `instanceof`, a code match, a catch) whether or not the diff touches it, anything a careful reader would miss on a first pass.
7. **Separate stated from inferred.** Never present an inferred *why* as fact. A reverse-engineered intent no source confirms is a guess — mark it as one.
8. **Stay high-signal.** Omit what the diff makes obvious. Mechanical renames, moves, and reindentation earn one line, generated files none. Measure length against the change's *meaning*, not its line count.

## Output

Write the explanation in the session as Markdown — the builder's account of the change, the way a plan is the planner's and a review the reviewer's. Lead with the change's goal and the problem it solves, then one `##` section per part with its intent, the load-bearing decision and the alternative not taken, and its risk. Close with **What to scrutinize** (the parts a reviewer must not skim) and **Assumptions I could not confirm** (inferred intent, flagged). Size it to the change's meaning: a narrow change is a few sentences under each heading, and a section with nothing to say is omitted. No code blocks restating the diff.

Spell out abbreviations and acronyms on first use. Gloss an unfamiliar or domain-specific term in a short parenthetical; when several recur throughout, front-load one short glossary instead, then use the terms bare.
