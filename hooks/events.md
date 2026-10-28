# Hook events

The plugin's hooks append to `events.jsonl` in the plugin's data directory (`$CLAUDE_PLUGIN_DATA`), for the events a session transcript does not show plainly, in the format [agent-record defines](https://github.com/cniska/agent-record/blob/main/SPEC.md#213-hook-events): its fields, kinds and versioning are there, and the hooks write regardless of any reader. This page says only what this plugin writes and when. [agent-record](https://github.com/cniska/agent-record), where installed, archives the file and counts its signals from it; the hooks never read the file back.

- A write fails open: a hook that cannot write the line says so on stderr and decides exactly as it would have.
- `agent` at `SubagentStop` is the stopping subagent, and at `PreToolUse` on `SubagentHandback` the subagent handing back.

## Kinds

### `gate`

A plugin gate decided whether work goes on.

| Field | Value |
|---|---|
| `gate` | `commit` (the commit gate on a `git commit`) or `verdict` (the reviewer's report check at `PreToolUse` on `SubagentHandback`, or at `SubagentStop` when the run ends without a hand-back) |
| `decision` | `allow` or `deny`; for `verdict`, `deny` refuses the hand-back or the stop, so the reviewer keeps running |
| `reason` | a code from the table below |
| `repo` | the repository's absolute top level, or `null` |
| `head` | `commit` only: the commit `HEAD` named, so the new commit is its child; otherwise `null` |
| `fingerprint` | `commit` only, where the commit carries code: a SHA-256 of the sorted set of code-path sides the gate judged, each a line of the side (`staged` or `working`), its mode and blob (`000000 0` for a deleted side), and its path; otherwise `null` |

Only a command that runs `git commit` gets a line; the commit gate is silent on every other command.

The [commit gate](../docs/plugin.md#commit-gate) says which sides of a path it judges and what entry covers one.

| Gate | Decision | Reason | When |
|---|---|---|---|
| `commit` | `allow` | `accepted` | every judged side of every code path matches an accepted entry for that path |
| `commit` | `allow` | `no_code_change` | no code path differs from `HEAD` in the index or the working tree: only Markdown, paths `HEAD` marks `linguist-generated`, or nothing |
| `commit` | `allow` | `scratch_repo` | the command creates its repository with `git init` or `git clone` under a temp directory (`$TMPDIR`, `/tmp`, `/private/tmp`, `/var/folders`), and every place it commits from is there too |
| `commit` | `allow` | `outside_repo` | the working directory is not in a repository |
| `commit` | `deny` | `not_accepted` | no accept is recorded for the repository |
| `commit` | `deny` | `changed_since_accept` | a judged side matches no accepted entry, and an uncovered path has an accepted entry for other content, one whose accept commit is no longer an ancestor of `HEAD`, or one a commit since its accept touched |
| `commit` | `deny` | `outside_accept` | a judged side matches no accepted entry, and no uncovered path has an accepted entry at all |
| `commit` | `deny` | `multiple_commits` | the command runs more than one commit |
| `commit` | `deny` | `repo_created` | the command creates the repository it commits to, by `git init` or `git clone`, with a commit that may land outside a temp directory |
| `commit` | `deny` | `repo_unclear` | the command reaches its repository in a way the gate cannot follow |
| `commit` | `deny` | `repo_not_found` | the directory the command names is not a repository |
| `commit` | `deny` | `gate_error` | the gate itself failed, so it refused |
| `verdict` | `deny` or `allow` | `missing_verdict` | the report has no `Verdict:` line |
| `verdict` | `deny` or `allow` | `missing_repo` | a `Verdict:` line has no `Repo:` line directly above it |
| `verdict` | `deny` or `allow` | `repo_relative` | the `Repo:` path is not absolute |
| `verdict` | `deny` or `allow` | `repo_not_found` | the `Repo:` path is not a repository |
| `verdict` | `deny` or `allow` | `repo_repeated` | two `Repo:` lines name the same repository |
| `verdict` | `deny` or `allow` | `worktree_mismatch` | the report cites files in another worktree of the `Repo:` repository and none in the one it names; when `Repo:` names a linked worktree, files in the main checkout do not count |
| `verdict` | `deny` or `allow` | `same_reviewer` | the report accepts a repository its reviewer returned earlier, so the accept is discarded and a fresh reviewer must judge the fix |
| `verdict` | `deny` or `allow` | `missing_findings` | the report lacks one of `## Findings`, `## Conflicts`, `## Follow-ups` and `## Clean` |
| `verdict` | `deny` or `allow` | `accept_with_findings` | the report accepts with something other than `none` under `## Findings`; `## Follow-ups` never holds back an accept |
| `verdict` | `deny` or `allow` | `accept_covers_nothing` | the report accepts a repository while the diff files the reviewer read name at least one path and none of them has its new side in that checkout's index or working tree; the reason names those paths and, where another worktree of the repository holds them, names that worktree and asks for it on the `Repo:` line, as `worktree_mismatch` does; where none does, it says the diff no longer matches the change, most likely edited after the diff was written, and asks the reviewer to request a fresh diff |
| `verdict` | `deny` or `allow` | `third_return` | a well-formed return is the third or later on one commit of `repo`: returns from distinct reviewers on the same `HEAD` whose briefs name diff files sharing a path; the deny is a note, asking the reviewer to add a line telling the author to stop fixing the commit, park it, and bring whoever coordinates them what the returns show and the one decision that would end them |

A `verdict` gate judges the report a reviewer passes to `SubagentHandback`, at `PreToolUse`, while the reviewer still runs to read a deny. `SubagentStop` judges the run the same way unless its final block is a hand-back, which `PreToolUse` already allowed; there the report is the final message. One bound covers both events: each reason a reviewer was denied is kept in a file for its agent id under the plugin's data directory, and the same reason again is allowed, so a reviewer that never fixes its report still ends. Neither the deny nor that allow records a verdict, though a return naming its repository still voids that repository's accept of each path in the diff files its brief names, and is kept against the reviewer's agent id so a later accept from that agent for that repository is `same_reviewer`. `third_return` is the exception: its report is well formed, so the hand-back after its deny, or its allow when the deny could not be kept, records the verdict as any return, and that hand-back logs no `gate` line. The noted reviewer's own `verdict` line follows its `third_return` line, so a commit reviewed after its third return is one with a `verdict` line for `repo` from an `agent` other than the one on the `third_return` line, after that line and before the next commit-gate `allow` in `repo`.

### `verdict`

The reviewer handed back a well-formed verdict, or ended its run with one, and the commit gate now holds it: one line per `Repo:` and `Verdict:` pair in the report.

| Field | Value |
|---|---|
| `verdict` | `accept` or `return` |
| `repo` | the repository's absolute top level |
| `fingerprint` | a SHA-256 of the repository's recorded accept set once the verdict is recorded, each entry a line of the `HEAD` commit at its accept (`-` before the first commit), its mode and blob, and its path; a return drops the entries of the paths in the diff files its brief names, so it carries the hash of the set that remains |
| `reason` | `no_diff` when the pair has `Reason: no_diff` on the line above its `Repo:`, saying the brief gave no diff to read, otherwise `null` |
| `findings` | the findings under `## Findings`, each counted by its `Severity:` as `critical`, `major` or `minor`, and as `unrated` when it has no readable one; `fix` and `consider` are always 0, since the report has no such kinds |
| `conflicts` | the `- **Where:**` bullets under `## Conflicts` |
| `follow_ups` | the `- **Where:**` bullets under `## Follow-ups`, the defects that were there before the change and do not block it; none of them is counted under `findings` |
| `rules` | each finding's `**Rule:**` under `## Findings`, one entry per finding that names one |

Finding counts and the rules a review cites are written, so a reader sums them without parsing the report. A report the hook cannot count leaves all four `null`: findings, conflicts or follow-ups written as prose rather than bullets, a count over 1000, or a report naming more than one repository, whose findings no line can claim alone.

### `permission_prompt`

Claude Code is about to ask the owner to allow a tool call (`PermissionRequest`).

| Field | Value |
|---|---|
| `tool` | the tool's name |

No hook fires when the owner answers. The answer and its time are the next result of that tool call in the transcript of `session` and `agent`.

### `permission_denied`

Auto mode refused a tool call (`PermissionDenied`).

| Field | Value |
|---|---|
| `tool` | the tool's name |
| `tool_use` | the tool call's id, which the transcript also holds |
| `reason` | `rule` (a classifier rule), `unevaluated` (auto mode could not judge the call), `classifier_unavailable` or `other` |
| `rule` | the classifier rule's name for `rule`, otherwise `null` |

## Left out

- **Pushes.** Git already records each one, from any shell: every push moves the remote-tracking ref and appends `update by push` with its time to that ref's reflog (`git reflog show --date=iso refs/remotes/origin/<branch>`), shared by every worktree of the clone. agent-record reads it there; a hook would have to parse each command for a push and would miss pushes made outside a session.
- **Token use per agent.** agent-record's `usage` table already holds tokens per session, from the transcripts.
- **The answer to a permission prompt.** No hook fires on it, and the transcript holds it.
