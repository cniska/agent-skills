#!/usr/bin/env bash
set -euo pipefail

mkdir -p transcripts/shop transcripts/notes

turn() {
  printf '{"type":"%s","timestamp":"%s","message":{"content":"%s"}}\n' "$1" "$2" "$3"
}

{
  turn user 2026-10-06T09:12:00Z "add the discount code field to checkout"
  turn assistant 2026-10-06T09:40:00Z "The reviewer accepted the change. Should I push to main now?"
  turn user 2026-10-06T09:41:00Z "yes. AGENTS.md says push once the reviewer accepts. stop asking me that."
} >transcripts/shop/a1f3.jsonl

{
  turn user 2026-10-07T13:02:00Z "fix the rounding in the cart total"
  turn assistant 2026-10-07T13:30:00Z "The commit gate blocked the commit: the diff changed since the accept. The only change is the formatter's whitespace. Should I run the reviewer again?"
  turn user 2026-10-07T13:32:00Z "ugh. the formatter touched whitespace and the gate wants a whole new review for that"
} >transcripts/shop/b7c2.jsonl

{
  turn user 2026-10-08T10:05:00Z "add tags to notes"
  turn assistant 2026-10-08T10:44:00Z "The reviewer accepted. Want me to push?"
  turn user 2026-10-08T10:45:00Z "the repo rule already says push after accept. i shouldn't have to answer this every time"
} >transcripts/notes/c9d4.jsonl

{
  turn user 2026-10-09T15:20:00Z "rename the export command"
  turn assistant 2026-10-09T15:51:00Z "The commit gate refused the commit after the formatter ran; the reviewer accepted the change before formatting. Re-run the review?"
  turn user 2026-10-09T15:53:00Z "a gate blocking a formatter-only change is wrong. second time this week."
} >transcripts/notes/d2e8.jsonl

{
  turn user 2026-10-10T08:30:00Z "bump the lockfile"
  turn assistant 2026-10-10T08:34:00Z "Running npm install."
  turn user 2026-10-10T08:35:00Z "this repo uses pnpm, not npm"
} >transcripts/notes/e5f1.jsonl
