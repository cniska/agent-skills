---
name: search-sessions
description: Search past sessions, through the session record or the raw transcripts, for what was said and decided about a subject, and report it cited by session and time. Use when a decision, number or plan was discussed earlier and is not in the repo, or not where you expect it.
---

# Search sessions

Recover what a subject was actually said to be, from the sessions held on this machine. The transcripts record the conversation and the repo records what got committed, and the two disagree often. Report what a session said and where, so a decision rests on the record and not on a guess at what it probably was.

Search before deciding something that may already be settled.

## Workflow

1. **Ask the session record first,** where one is installed. When none is installed, or it finds nothing, search the raw transcripts as [transcripts](references/transcripts.md) says.
2. **Widen once you have a hit.** Read the messages around it in that session. The exchange that settled a question is usually three or four messages, and the sentence that changed the answer is rarely the one that matched.
3. **Collect what makes a hit actionable:** the session id, the time, who said it, and any commit, file or path named in the same exchange. A message saying the thing was written down leads to the artifact.
4. **Check the artifact against the current checkout.** A decision committed in another checkout and never pushed, or written to a file on another branch, cannot be seen from where you stand. Look on the current branch before reporting a decision as present or missing, and say which it is.

## Reporting

Lead with the answer to the question asked, then the evidence. Restate what each message said, as `writing` says, and cite `<session-id-prefix> <timestamp>` after each. Group by decision, not by session.

Say plainly what the search did not find. An absence you looked for is a finding, and reporting it keeps the same question from being asked again. Where a decision lives in a transcript but not in the repo, name the gap and what would close it.
