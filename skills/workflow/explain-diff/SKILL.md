---
name: explain-diff
description: Explain a diff's intent and risk in the session, through a fresh reader, so a change is grasped before review or merge. Use when asked to explain a change, or when a change is complex, unfamiliar, or headed to other people.
---

# Explain diff

A diff shows what changed, but not why or what to worry about. Recover both, the intent and the risk, for a reader who reads code fluently. Explain the change and leave judging it to `review` and presenting it for merge to `pr`.

## Workflow

1. **Hand the pass to a fresh agent** whenever one is available, whatever the diff's size, unless this session already is one that has not seen the change. A session that touched the change explains its own mental model back, and misses the gaps that model papers over. Hand the agent only where to look: the repo or worktree path, and the diff range or PR number. Keep your intent, rationale, alternatives weighed and findings out of its brief, since a cold reader that reaches your reading on its own is signal and one you briefed is an echo. Run it on a **balanced-tier** model or better. The agent runs steps 2 to 8, or this session does when it is the fresh one or no fresh agent is available. Check the draft's claims against the code before presenting it, since a cold reader misreads too.
2. **Gather the change.**
   - **The work in this session**, when no PR is named: the current branch against `main` plus uncommitted changes, or the session's own commits when it worked on `main`, with their commit messages. For an uncommitted change, read the diff's own spec and doc hunks and the small contract files before the biggest code hunk, and treat them as the commit message you do not have.
   - **Someone else's PR**, by URL or number: its diff and description.
3. **Find the stated intent** in spec IDs, design notes, ADRs, commit messages, a PR's description or a linked issue before inferring any. The code says what it does, but not what the author meant.
4. **Name the change's goal** and the problem it solves, then the separable parts that deliver it. Group hunks by part, since a part that spans five files is one story. Check each hunk's enclosing function against the file, since the diff's hunk header can name the wrong one.
5. **Give each part three things:** the **intent**, what it is for; the **load-bearing decision and the alternative not taken**, why it has this shape; and the **risk**, what could break and what a reviewer should scrutinize. Prove a behavioral risk with a minimal repro, as `debug`'s Reproduce step does.
6. **Surface the non-obvious**: implicit contracts touched, invariants relied on, ordering or concurrency, migrations, and **trust dependencies**, where one component assumes an invariant another enforces without checking it, most of all across a process or network boundary. Name every site that branches on what changed, such as an `instanceof`, a code match or a catch, whether or not the diff touches it, and anything else a careful reader would miss on a first pass.
7. **Mark each inferred why as a guess.** Present as fact only intent a source confirms.
8. **Keep to what the diff does not show.** Give mechanical renames, moves and reindentation one line and generated files none. Size the explanation to the change's meaning, not its line count.

## Output

Write the explanation in the session as Markdown: the builder's account of the change, the way a plan is the planner's and a review the reviewer's. Lead with the change's goal and the problem it solves, then one `##` section per part with its intent, the load-bearing decision and the alternative not taken, and its risk. Close with **What to scrutinize**, the parts a reviewer must read closely, and **Assumptions I could not confirm**, the inferred intent. A narrow change takes a few sentences under each heading, and a section with nothing to say is left out.

Spell out abbreviations and acronyms on first use. Gloss an unfamiliar or domain-specific term in a short parenthetical. When several such terms recur throughout, front-load one short glossary instead, then use the terms bare.
