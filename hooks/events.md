# Hook events

The plugin's hooks append one JSON object per line to `events.jsonl` in the plugin's data directory (`$CLAUDE_PLUGIN_DATA`), for the events a session transcript does not show plainly. [agent-record](https://github.com/cniska/agent-record) archives the file as a source of its own; the hooks never read the file back. [agent-record's spec](https://github.com/cniska/agent-record/blob/main/SPEC.md) defines the signals counted from these lines and how a stop is judged.

- The file is only appended to, one line per decision, and never rewritten.
- A write fails open: a hook that cannot write the line says so on stderr and decides exactly as it would have.
- A line never holds a command, a prompt, a tool's input or a report: only the fields below.
- A field that is unknown is `null`, never missing. A new field may be added to a kind without a new version; a field changes meaning or goes away only with a new `v`.

## Every line

| Field | Value |
|---|---|
| `v` | `1`, the format version |
| `ts` | UTC time, ISO 8601 to the second |
| `event` | the kind, below |
| `session` | the session id |
| `agent` | the id of the subagent the hook fired in, or `null` in the main agent; at `SubagentStop`, the stopping subagent |
| `cwd` | the working directory the hook was given |

## Kinds

### `gate`

A plugin gate decided whether work goes on.

| Field | Value |
|---|---|
| `gate` | `commit` (the commit gate on a `git commit`) or `verdict` (the reviewer's report check at `SubagentStop`) |
| `decision` | `allow` or `deny`; for `verdict`, `deny` keeps the reviewer running |
| `reason` | a code from the table below |
| `repo` | the repository's absolute top level, or `null` |
| `head` | `commit` only: the commit `HEAD` named, so the new commit is its child; otherwise `null` |
| `fingerprint` | `commit` only: the diff fingerprint the gate compared with the accepted one, the same value a `verdict` line carries; otherwise `null` |

Only a command that runs `git commit` gets a line; the commit gate is silent on every other command.

| Gate | Decision | Reason | When |
|---|---|---|---|
| `commit` | `allow` | `accepted` | the diff is the one the reviewer accepted |
| `commit` | `allow` | `no_code_change` | the diff changes only Markdown, or nothing |
| `commit` | `allow` | `outside_repo` | the working directory is not in a repository |
| `commit` | `deny` | `not_accepted` | no accept is recorded for the repository |
| `commit` | `deny` | `changed_since_accept` | an accept is recorded, for another diff |
| `commit` | `deny` | `multiple_commits` | the command runs more than one commit |
| `commit` | `deny` | `repo_created` | the command creates the repository it commits to |
| `commit` | `deny` | `repo_unclear` | the command reaches its repository in a way the gate cannot follow |
| `commit` | `deny` | `repo_not_found` | the directory the command names is not a repository |
| `commit` | `deny` | `gate_error` | the gate itself failed, so it refused |
| `verdict` | `deny` or `allow` | `missing_verdict` | the report has no `Verdict:` line |
| `verdict` | `deny` or `allow` | `missing_repo` | the report has no `Repo:` line |
| `verdict` | `deny` or `allow` | `repo_relative` | the `Repo:` path is not absolute |
| `verdict` | `deny` or `allow` | `repo_not_found` | the `Repo:` path is not a repository |

A `verdict` gate denies a reviewer's first `SubagentStop` and allows the second, so a reviewer that never fixes its report still ends; neither records a verdict.

### `verdict`

The reviewer ended with a well-formed verdict, and the commit gate now holds it.

| Field | Value |
|---|---|
| `verdict` | `accept` or `return` |
| `repo` | the repository's absolute top level |
| `fingerprint` | the fingerprint of the diff as it stood when the verdict was recorded |

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
- **Fix and Consider counts and the rules a review cites.** They are in the reviewer's report, which the transcript holds whole.
- **The coach's report check and the task coach hook.** They only ask for a count line or a coach run; the transcript shows the block.
- **The answer to a permission prompt.** No hook fires on it, and the transcript holds it.
