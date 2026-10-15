---
name: search-sessions
description: Search past session transcripts for what was said and decided about a subject. Use when a decision, number, or plan was discussed earlier and is not in the repo, or not where you expect it.
argument-hint: "<subject>"
---

# Search sessions

Recover what a subject was actually said to be, out of the session transcripts on this machine. The transcript records the conversation; the repo records what got committed, and the two disagree often enough to be worth a skill. Report quotes and where they came from, never a paraphrase of what a decision probably was.

Transcripts sit one JSON object per line at `~/.claude/projects/<slug>/<session-id>.jsonl`, with a subagent's own lines under `<session-id>/subagents/*.jsonl`. The slug is the working directory path with `/` replaced by `-`.

Search before deciding something that may already be settled.

Ask `agent-record` (github.com/cniska/agent-record) first, where installed: it indexes every session and the commits they led to. Run `agent-record sync` before the first query, so the record holds the latest sessions. If it fails with `error.code` `lock_held`, another sync is running: search anyway, say the record may lag one sync, and do not retry. `agent-record query search "<words>"` finds a message, `agent-record query thread <session> --at <at>` reads the exchange a hit sits in, with the hit's `at` copied whole, its `Z` included, since a time with no zone is refused `not_a_time`; `agent-record query prior-art "<path fragment>"` finds where a shape already exists on disk, and `agent-record sql "<select>"` reads anything else. The workflow below is for when it is missing or finds nothing.

## Workflow

1. **List every slug for the repo, not just this one.** A worktree or a sibling checkout gets a slug of its own, so one project spreads over several — `-Users-me-code-apps`, `-Users-me-code-apps--claude-worktrees-puzzles`, and so on. Glob for the repo's name and take them all: searching only the current directory's slug is how a conversation held in another checkout goes missing.
2. **Narrow by file first.** A line carries whole tool results and file contents, so a transcript runs to megabytes. `grep -l -F` the subject's terms across the candidate slugs and parse only the files that hit. Honor a stated time window with `find -mtime`; with none given, start bounded, at the last few days and below the largest files (`find -mtime -3 -size -20M`), and widen only when that finds nothing. A scan that runs into the command timeout is stopped and narrowed, never waited on.
3. **Read messages, skip the machinery.** Keep events whose `type` is `user` or `assistant`, and take `message.content` — a string, or the `text` parts of a list. Drop tool calls and their results, skill preambles (`Base directory for this skill:`), briefs pasted in as an opening message, and image placeholders. Search both sides: a decision is often only stated in the reply.
4. **Widen once you have a hit.** Read the messages around it in that session. The exchange that settled a question is usually three or four messages, and the sentence that changed the answer is rarely the one that matched.
5. **Collect what makes a quote actionable**: session id, timestamp, who said it, and any commit, file, or path named in the same exchange. A message saying the thing was written down is the thread to the artifact.
6. **Check the artifact against the current checkout.** A decision committed in another checkout and never pushed, or written to a file on a branch you are not on, is invisible from where you stand. Verify on the current branch before reporting a decision as present or missing, and say which it is.

## Reporting

Lead with the answer to the question asked, then the evidence: quote the words, and cite `<session-id-prefix> <timestamp>` after each. Group by decision rather than by session.

Say plainly what the search did not find — an absence you looked for is a finding, and it is what keeps the same question from being asked again. Where a decision lives in a transcript but not in the repo, name the gap and what would close it.

## See also

- `git` — find the commit or branch a transcript names

## Red flags

- Querying `agent-record`, where installed, without syncing first, or retrying a sync the lock refused
- Passing `--at` a hit's time with its zone dropped
- Searching the current directory's slug alone, so another worktree's conversation reads as never having happened
- Paraphrasing a decision instead of quoting it
- Parsing every transcript instead of grepping for candidates first, or grepping them all before a bounded scan came back empty
- Waiting on a scan that ran into the command timeout instead of stopping and narrowing it
- Pulling raw transcript JSON into the answer, or into context when a targeted extract would do
- Quoting a hit without the session id and timestamp that let someone else find it
- Searching only the user's messages, when the decision was stated in the reply
- Treating a matched line as the decision without reading the exchange around it
- Reporting a decision as recorded without checking whether the artifact exists on the current branch
