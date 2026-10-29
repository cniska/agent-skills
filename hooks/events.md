# Hook events

The plugin's hooks append to `events.jsonl` in the plugin's data directory (`$CLAUDE_PLUGIN_DATA`), for the events a session transcript does not show plainly, in the format [agent-record defines](https://github.com/cniska/agent-record/blob/main/SPEC.md#213-hook-events): its fields, kinds and versioning are there, and the hooks write regardless of any reader. This page says only what this plugin writes and when. [agent-record](https://github.com/cniska/agent-record), where installed, archives the file and counts its signals from it; the hooks never read the file back.

- A write fails open: a hook that cannot write the line says so on stderr and decides exactly as it would have.
- `agent` at `SubagentStop` is the stopping subagent, at `PreToolUse` on `SubagentHandback` the subagent handing back, and at `PreToolUse` on a report tool the agent reporting. At `Stop` there is no `agent`: the session is the one stopping.

## Kinds

### `gate`

A plugin gate decided whether work goes on.

| Field | Value |
|---|---|
| `gate` | `commit` (the commit gate on a `git commit`) or `verdict` (the report check: at `PreToolUse` on a report tool, `verdict`, `research` or `task_report`, and at `PreToolUse` on `SubagentHandback`, `SubagentStop` or `Stop` when the agent ends without a report) |
| `decision` | `allow` or `deny`; for `verdict`, `deny` refuses the report call, the hand-back or the stop, so the agent keeps running |
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
| `verdict` | `deny` or `allow` | `payload_invalid` | the report call's input breaks its tool's schema in `mcp/report-schemas.json`, or a field is missing or given against another field's value, such as `drop_reason` without `sort` `drop`; or a judgment gives a `reason` with `verdict` `accept`, or one its agent may not give: a reviewer may give only `no_diff`, a designer also `verify_gap`, `run_blocked` or `run_short` |
| `verdict` | `deny` | `wrong_agent` | the report tool is not its caller's: `verdict` is the reviewer's and the designer's, `research` the researcher's, `task_report` the worker's; denied every time, and stores nothing |
| `verdict` | `deny` | `already_reported` | the agent calls a report tool while its stored report awaits its hand-back; denied every time |
| `verdict` | `deny` or `allow` | `missing_report` | a reviewer, designer, researcher or worker hands back or stops with no report stored since its last hand-back |
| `verdict` | `deny` or `allow` | `diff_not_read` | a reviewer lists under `diffs` a file it did not read with `Read` |
| `verdict` | `deny` or `allow` | `repo_not_found` | a judgment's `repo` is not a repository |
| `verdict` | `deny` or `allow` | `repo_repeated` | two judgments name the same repository |
| `verdict` | `deny` or `allow` | `worktree_mismatch` | a judgment cites files, in its findings, conflicts, follow-ups or clean places, in another worktree of its `repo` and none in the one it names, where files in the main checkout do not count for a linked worktree; or it accepts while the listed diffs match nothing in its `repo` and another worktree holds them |
| `verdict` | `deny` or `allow` | `accept_with_findings` | a judgment accepts with `findings` not empty; `follow_ups` never holds back an accept |
| `verdict` | `allow` | `same_reviewer` | a note: a judgment accepts a repository its reviewer returned earlier, so the accept is not recorded and a fresh reviewer must judge the fix |
| `verdict` | `allow` | `accept_covers_nothing` | a note: a judgment accepts while the listed diffs name at least one path and none has its new side in that checkout's index or working tree, and no other worktree holds them, so the diff no longer matches the change and the accept is not recorded |

- **When:** a `verdict` gate judges a report at its tool's `PreToolUse`, while the agent still runs to read a deny. It judges an end without a report at `SubagentHandback`, `SubagentStop` or a top-level worker's `Stop`.
- **Bound:** each code that denies, but `wrong_agent` and `already_reported`, is denied once per agent id, or per session id at the top level, until the agent hands back a report, which resets the bound. A later call with the same fault is allowed, stored as not recorded, and records no verdict, so an agent that never fixes its report still ends.
- **Returns:** a reviewer's return voids its repository's accepts for the paths in every diff file it read, whether or not the call is denied, unless it is refused as `already_reported`. It is also kept against the reviewer's agent id, so a later accept from that agent for that repository is `same_reviewer`.
- **Hand-back:** a stored report stands for one hand-back. The end it allows marks it `handed_back` and resets the bound, so an agent resumed after it reports again, and that report replaces it. An end let through past the bound with no new report removes the handed-back one, so no stale report is read as current.
- **Notes:** the two notes deny nothing. The stored record gives each judgment `{repo, verdict, recorded, code, fix, returns_on_commit}` for the caller to read. `returns_on_commit` counts the returns from distinct reviewers on one `HEAD` of `repo` whose read diffs share a path.

### `verdict`

A reviewer reported a well-formed verdict and the commit gate now holds it: one line per judgment in the report a note did not keep from being recorded.

| Field | Value |
|---|---|
| `verdict` | `accept` or `return` |
| `repo` | the repository's absolute top level |
| `fingerprint` | a SHA-256 of the repository's recorded accept set once the verdict is recorded, each entry a line of the `HEAD` commit at its accept (`-` before the first commit), its mode and blob, and its path; a return drops the entries of the paths in the diff files its reviewer read, so it carries the hash of the set that remains |
| `reason` | the judgment's `reason`, `no_diff` when the brief gave no diff to read, otherwise `null` |
| `findings` | the judgment's `findings`, each counted by its `severity` as `critical`, `major` or `minor`; `fix`, `consider` and `unrated` are always 0, since the schema has no such kinds and requires a severity |
| `conflicts` | the judgment's `conflicts` |
| `follow_ups` | the judgment's `follow_ups`, the defects that were there before the change and do not block it; none of them is counted under `findings` |
| `rules` | each finding's `rule`, one entry per finding |

Finding counts and the rules a review cites are written, so a reader sums them without reading the report. A count over 1000 leaves all four `null`.

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
