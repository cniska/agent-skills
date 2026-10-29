# Plan: structured hand-backs for the reviewer, designer, researcher and worker

**Unratified.** A worker wrote this for task `agent-skills-review-structured-verdict` (brief: `agent-ops/briefs/agent-loop-agent-skills-review-structured-verdict.md`, at agent-ops `d870c92`). The coordinator checks it and resumes the worker to build it. Each choice the owner did not make is marked **Choice** with the alternative and its cost.

## Outcome

The four agents hand back their fields as schema-checked data. Each makes one call to a plugin MCP tool whose input schema holds the fields. A `PreToolUse` hook checks that call against the same schema, applies the reviewer gate's checks, stores the payload, and refuses a hand-back from any of the four that made no valid call. The parent reads the stored payload through a second tool of the same server. Prose remains only in the fields a person reads, such as a finding's Why and Instead, a recommendation, and a worker's summary.

## Grounding

Facts the design rests on, each checked at its source on 2026-10-29 against Claude Code 2.1.285, the installed version.

- **No host structured output reaches a subagent the Agent tool starts.** Agent frontmatter has no output-schema field, and the docs say unknown fields are ignored ([sub-agents](https://code.claude.com/docs/en/sub-agents.md)). `--json-schema` and the SDK's `outputFormat` apply to a top-level run only ([structured outputs](https://code.claude.com/docs/en/agent-sdk/structured-outputs.md)). A workflow script's `agent(prompt, { schema })` does have the host check a subagent's JSON ([workflows](https://code.claude.com/docs/en/workflows.md)), but only from a workflow script, and `task` and `coordinate` start agents through the Agent tool.
- **Plugin agents cannot declare their own MCP servers.** The docs say plugin subagents ignore the `hooks`, `mcpServers` and `permissionMode` fields ([sub-agents](https://code.claude.com/docs/en/sub-agents.md)), so a root `.mcp.json` is the only route to a plugin tool.
- **`SubagentHandback` is no channel to build on.** It exists only in auto mode, behind a flag. The binary's `lko(e){return e.mode==="auto"&&OKe()}` gates it, `OKe` reads `CLAUDE_CODE_SENDMESSAGE_HANDBACK` or the `tengu_lively_waffle` flag, and the prompt calls it with `{message: <your full report>}`, a single string. The docs publish no schema for it and give no way to extend one ([tools reference](https://code.claude.com/docs/en/tools-reference.md)).
- **A plugin MCP tool is documented end to end.** A plugin ships `.mcp.json` at its root. Its tools are named `mcp__plugin_<plugin>_<server>__<tool>`, and a subagent's `tools:` list grants one by that full name ([mcp](https://code.claude.com/docs/en/mcp.md)). `PreToolUse` fires on a subagent's tool calls, with `agent_id` and `agent_type` in its input. It gets `tool_input`, can deny with a reason the model sees, and with `permissionDecision: allow` skips the permission prompt unless the server sets `anthropic/requiresUserInteraction` ([hooks](https://code.claude.com/docs/en/hooks.md)). `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` are expanded in a plugin's MCP config and exported to a stdio server ([manifest reference](https://code.claude.com/docs/en/plugins/manifest-reference.md)).
- **The host does not check an MCP tool's input against its schema.** An MCP tool's host-side schema is a passthrough object, and a missing required field only sends telemetry (binary: `tengu_mcp_input_missing_required`). The docs tell servers to validate their own arguments ([mcp](https://code.claude.com/docs/en/mcp.md)). The hook's check is therefore the only one.
- **MCP tools are deferred by default** behind tool search, and a deferred tool called before its schema is fetched fails ([mcp](https://code.claude.com/docs/en/mcp.md), "Configure tool search"). The reviewer and designer have no `ToolSearch`. A tool whose `_meta` sets `anthropic/alwaysLoad: true` loads upfront (same page; the binary maps `alwaysLoad` to `anthropic/alwaysLoad`).
- **`claude plugin eval` does not start a plugin's real MCP servers by default.** It registers a substitute server under each server's name. A tool with a mock file answers from it and is allowed without a grant. A tool with no mock is not available, unless the run passes `--allow-real-servers` ([plugin evals](https://code.claude.com/docs/en/plugin-evals.md), "Mock MCP servers"; binary: `--mocks (record | off; default: record). record: a plugin server with no mock is NOT started`). `evals/lib/run.sh` passes neither flag. A case's own `mocks/` directory applies to that case alone.
- **A subagent's tool calls reach `claude plugin eval`'s trace.** The eval runner's trace reader (binary, function `Sp`) walks every `assistant` event of the run's stream and pushes each `tool_use` block into `toolCalls`, whatever its `parent_tool_use_id`. Its only use of `parent_tool_use_id == null` is to spot a top-level auth error. The stream carries a subagent's `tool_use` blocks by default, with `parent_tool_use_id` set ([headless](https://code.claude.com/docs/en/headless.md), "Follow subagent messages"). `tool_used` matches `input_match` against `JSON.stringify` of the call's input (`Wl`, `Cp`) and counts denied calls too (`ym`).
- **`evals/lib/trace.ts` already keeps every assistant line,** a child's included, since `parseLine` filters only on `type`. So the saved traces gain the subagent's call as an assistant line carrying `parent_tool_use_id`, and **no `evals/lib` change is needed**. The sibling task's files stay untouched.
- **Event reasons are free text** in agent-record's format (`agent-record/SPEC.md` FR-79), so new `gate` reason codes need no change there.

## Decisions

1. **Channel: one plugin MCP server, `report`, in bash with jq.** It runs in other people's sessions, as the hooks do, so it keeps `AGENTS.md`'s hook runtime: bash and `jq`, never Bun or Node. It speaks newline-delimited JSON-RPC on stdio: `initialize`, `ping`, `tools/list` and `tools/call`, plus `notifications/initialized`, which needs no reply. Every tool it lists carries `_meta: {"anthropic/alwaysLoad": true}`, so an agent without `ToolSearch` can call it, and none sets `requiresUserInteraction`.
   - **Choice:** an MCP tool over the alternatives. A JSON object inside the `SubagentHandback` message is text the model types, with no host check and no channel outside auto mode. A `SubagentStop` check of the last message is still a parse of prose. An agent-scoped `mcpServers` is ignored for plugin agents. A workflow's `agent({schema})` would need `task` and `coordinate` to start agents from workflow scripts. The cost of the chosen route is a small bash server and a jq validator in every user's session, kept for one call per agent.
   - **Choice:** JSON tool input, not TOON. The owner first asked to "return toon instead of freeform md" (session 3ca1638e, 2026-10-28T20:12:34Z), then accepted the coordinator's "schema-checked shape" wording. An MCP tool's input is JSON. `read_report` could render TOON for a reader, at the cost of a TOON encoder in jq; the plan renders JSON.
2. **Tools.** Each tool's input schema is the data contract. `read_report` is the only one whose output matters.
   - `verdict`: used by the reviewer and the designer, one shared shape.
   - `research`: used by the researcher.
   - `task_report`: used by the worker.
   - `read_report({id})`: used by any parent. It returns the stored record for an agent id, or for a session id when a top-level `claude --agent cniska-skills:worker` run has no agent id, as JSON in `structuredContent` and as text.
3. **One schema file, read by both server and hook.** `mcp/report-schemas.json` holds a `$defs` section and the four input schemas. When the server answers `tools/list`, it inlines each `$ref` with jq, so every listed schema stands alone. The hook validates `tool_input` against the same file with a jq validator, `hooks/report-schema.jq`. The validator covers only the keywords the file uses: `type`, `enum`, `required`, `properties`, `additionalProperties: false`, `items`, `minItems`, `minLength` and `pattern`. A test fails when the file uses any other keyword. The hook's check is the only one, since the host does not check MCP input.
4. **The shared shapes (`$defs`).**
   - `location`: `{path: absolute path, line?: integer ≥ 1, end_line?: integer, note?: string}`. Screens and captures use `path` to the capture file, with `note` naming the state, theme and size.
   - `finding`: `{where: [location, ≥1], rule: string, severity: critical|major|minor, why: string, instead: string}`. Findings, conflicts and follow-ups all use it, so the bullets in `review-report.md` map one to one.
   - `clean`: `{rule: string, places: [location]}`.
   - `judgment`: `{repo: absolute path, verdict: accept|return, reason?: no_diff|verify_gap|run_blocked|run_short, findings: [finding], conflicts: [finding], follow_ups: [finding], clean: [clean]}`.
   - `verdict` input: `{diffs: [absolute path], judgments: [judgment, ≥1]}`.
   - `research` input: `{recommendation: string, evidence: [{claim, source: {kind: session|file|url, ref}}, ≥1], against: string, owner_conflicts: [string], unverified: [string], sort: proposal|idea|drop, drop_reason?: string}`.
   - `task_report` input: `{task, outcome: landed|plan_ready|blocked|parked|stopped, summary, plan?: absolute path, second_opinion?: {sort, recommendation}, landed?: {repo, branch, sha, ci_runs: [{workflow, url, conclusion}]}, branch_kept?: string, choices: [{choice, why}], owner_questions: [string], follow_ups: [finding], open: [string], steps_skipped: [{step, why}], plugin_update_due: boolean}`.
   - **Choice:** each repository gets its own `judgment`, carrying its own findings. Today one report spans every `Repo:` pair, and finding counts are `null` when there is more than one repo. Per-repo judgments let `accept_with_findings` and the counts hold per repo. The cost is a longer payload in the rare cross-repo review.
5. **The hook's flow.** A new entry, `hooks/report-record.sh`, runs at `PreToolUse` on matcher `mcp__plugin_cniska-skills_report__(verdict|research|task_report)`, and at `PreToolUse` on `SubagentHandback` and at `SubagentStop`, where it replaces today's `review-record.sh` entries.
   - **On a report tool:**
     1. Check the shape. A failure is denied with `payload_invalid`, naming the JSON path, what the schema requires there, and the fix.
     2. Check the caller. `verdict` is accepted only from `agent_type` reviewer or designer, `research` only from researcher, and `task_report` only from worker or a top-level session. Any other caller is denied with `wrong_agent`.
     3. For a reviewer's `verdict`, run the reviewer checks below.
     4. Store `{tool, agent_type, agent_id, session_id, payload, gate}` at `$CLAUDE_PLUGIN_DATA/reports/<agent_id or session_id>.json`, and return `permissionDecision: allow`, so the call never waits on a permission prompt.
     5. Refuse a second call after a stored one with `already_reported`, always, since the hand-back is then open.
   - **At hand-back or stop:** for agent types reviewer, designer, researcher and worker, deny once with `missing_report` when no record exists for the agent, naming the tool to call. This uses the existing `deny_once` bound, so a run that never complies still ends.
   - **Choice:** the hook validates every caller's shape, not only the reviewer's, as the brief's "schema-checked data" asks for all four. Only the reviewer's verdict feeds the commit gate. The designer's is stored, never recorded as an accept, as today.
6. **Reviewer checks, moved from text to data in `hooks/review-record.sh`.** That file becomes a library that `report-record.sh` sources.
   - Deleted: `verdict_pairs`, `parse_report`, `has_sections`, `findings_empty`, `brief_and_reads`, `brief_paths`, `returned_paths`, `reviewed_paths`, and the prose path grep in `cited_worktrees` (`absolute_paths` over the report).
   - **Diff files come from data.** `payload.diffs` lists the diff files judged. Each entry must be a file the reviewer read through a `Read` call in its own transcript, a `tool_use` block, so data too. Otherwise the call is denied with `diff_not_read`. A return voids the accepts of the paths in those diffs. An accept covers the paths in those diffs, through the existing `diff_paths`, `current_entries` and `record_accept`.
   - **Choice:** the reviewer's payload names the diffs, not the brief. Nothing structured carries the parent's brief, since the Agent tool's input is `{prompt, subagent_type, description}`. The cost: a reviewer could leave a diff it read out of a return, and that diff's accepts would survive. Today the brief's prose decides instead.
   - **Repo checks use `judgment.repo`.** These are `missing_repo` through the schema, plus `repo_relative`, `repo_not_found` and `repo_repeated`.
   - `worktree_mismatch` reads the absolute `location.path` values of the judgment's findings, conflicts, follow-ups and clean places.
   - `accept_with_findings` is denied when `verdict == accept` and `findings` is not empty.
   - `no_diff` is the only `reason` a reviewer may give. A designer-only reason from a reviewer is denied with `payload_invalid`.
   - The designer's `verify_gap`, `run_blocked` and `run_short` keep today's order rule, checked as data.
   - **Choice:** gate notes the reviewer cannot act on go into the stored record, not a demand for a prose line. `same_reviewer`, `accept_covers_nothing` when no worktree holds the paths, and `third_return` stop denying the reviewer to add a sentence for the author. Each becomes `gate: {recorded: bool, code, fix, returns_on_commit}` in the record, which the parent reads through `read_report`. `accept_covers_nothing` whose paths match another worktree is still denied as `worktree_mismatch`, since the reviewer can fix its `repo`. The cost: the `third_return` deny, and its `gate` line in the log, disappear. agent-record's signals read only `gate` and `verdict` lines, and a `verdict` line still follows every recorded verdict.
   - **Event log:** a `verdict` line per judgment, with counts taken straight from the payload. `findings` is grouped by `severity` (`fix`, `consider` and `unrated` are always 0), `conflicts` and `follow_ups` are array lengths, and `rules` is `findings[].rule`. Counts are never `null` again, except over the 1000 cap. `gate` lines keep their shape and gain the reason codes `payload_invalid`, `wrong_agent`, `missing_report`, `diff_not_read` and `already_reported`. They lose `missing_verdict`, `missing_repo` (now a shape error), `missing_findings` and `third_return`.
7. **The parent reads data.**
   - `task`: a review's verdict, findings and gate notes come from the reviewer's stored report. The third-return park reads `gate.returns_on_commit`.
   - `coordinate`: a worker's hand-back fields come from its `task_report`.
   - `second-opinion`: the sort comes from `research.sort`.
   - The skills stay host-neutral, as `AGENTS.md`'s no-project-specifics rule asks: "report through the structured report tool your agent definition names; with none, in the review report's shape as prose". The tool names live only in `agents/*.md` and `docs/plugin.md`.

## Change list

New files, for the coordinator to add to scope:

```diff
+ .mcp.json                         plugin MCP config: server "report", command "${CLAUDE_PLUGIN_ROOT}/mcp/report-server.sh", env CLAUDE_PLUGIN_DATA
+ mcp/report-server.sh              bash+jq stdio JSON-RPC server: tools/list from the schema file, tools/call ack, read_report
+ mcp/report-server.test.sh         drives initialize, tools/list, tools/call and read_report over stdin; refuses an unknown method and an id outside [A-Za-z0-9_-]
+ mcp/report-schemas.json           $defs plus the verdict, research and task_report input schemas
+ hooks/report-schema.jq            the subset JSON Schema validator, errors as {path, rule, want}
+ hooks/report-schema.test.sh       the validator against the schema file: each keyword proven able to fail; an unsupported keyword fails the test
+ hooks/report-record.sh            entry for the report tools, SubagentHandback and SubagentStop
+ hooks/report-record.test.sh       shape, caller, missing_report, already_reported, storage
```

Changed files:

- `hooks/hooks.json`: adds `PreToolUse` on the report tools and points `SubagentHandback` and `SubagentStop` at `report-record.sh`. This is a gate-file change, so it is subject to the open obstacle on auto mode.
- `hooks/review-record.sh`: becomes the reviewer library, with the text parsers deleted as Decision 6 lists.
- `hooks/subagent-gate.sh`: `subagent_report` and the settled-block reading go. `deny_once`, `was_denied`, `judges`, `agent_transcript` and `left_to_handback` stay.
- `hooks/events.md`: the new codes and the record as data.
- `hooks/review-gate*.test.sh` and `review-gate.test-harness.sh`: the harness builds `PreToolUse` input for `mcp__plugin_cniska-skills_report__verdict` with a `tool_input` payload in place of report text. Each case keeps its intent. The parse cases (`review-gate-report.test.sh`) become shape cases.
- `agents/reviewer.md` and `agents/designer.md` gain `mcp__plugin_cniska-skills_report__verdict` in `tools`. The closing-lines rules (`Repo:`, `Verdict:`, `Reason:`) become "call `verdict` once, then hand back a one-line pointer".
- `agents/researcher.md` gains the `research` tool. Its four-part shape and `Sort:` line become the payload.
- `agents/worker.md`: the worker states its report, as `task` rule 8 says, through `task_report`.
- `scripts/agents.test.sh`: asserts each agent's `tools` line, including the report tool, and that the tool names an agent file uses exist in `mcp/report-schemas.json`.
- `skills/expertise/principles/references/review-report.md`: the fields are defined once and rendered two ways: the payload when the caller names a report tool, the Markdown sections when a person reads the review.
- Skills: `skills/workflow/review/SKILL.md` (step 7 and Report), `skills/expertise/ui-review/SKILL.md` (its `Verdict:` line), `skills/workflow/task/SKILL.md` (rules 4 and 8, Close's reading of a verdict), `skills/workflow/coordinate/SKILL.md` and its `references/report.md` (reading a hand-back), and `skills/workflow/second-opinion/SKILL.md` (the sort). This is through `skill-writing`.
- Docs, through `docs-writing`: `docs/plugin.md` (Reviewer, Designer and Researcher agent sections, the sequence diagram's `Verdict:` arrows, a new "Report server" section) and `docs/reviewer.md` (the `no_diff` line).
- `.claude-plugin/plugin.json`: no change. A root `.mcp.json` is picked up as is.
- `evals/scenarios/review-*`: graders, saved traces, and a new `mocks/report/verdict.md` per case; see Evals.

## Evals

The payload shows up in a trace as the reviewer's own `tool_use` of `mcp__plugin_cniska-skills_report__verdict`, an assistant line with `parent_tool_use_id` set. `tool_used` and `tool_order` see it in a real run, and `evals/lib/trace.ts` sees it in a saved trace, as Grounding says.

| Grader | New form |
|---|---|
| `review-*/returned` | `tool_used` on `verdict`, `input_match: '"verdict":"return"'` |
| `review-sound-fix/accepted` | `tool_used` on `verdict`, `input_match: '"verdict":"accept"'` |
| `review-sound-fix/never-returned` | `tool_used` on `verdict`, `input_match: '"verdict":"return"'`, `max: 0` |
| `review-symptom-fix/names-siblings` | `tool_used` on `verdict`, with `input_match` lookaheads for a `"path":"…tests/search\.test\.ts"` and a `"path":"…tests/feed\.test\.ts"` location |
| `review-symptom-fix/names-raised-timeout` | `tool_used` on `verdict`, with `input_match` on a `tests/feed.test.ts` location whose `line` falls within the test that sets `{ timeout: 8000 }` (file lines 6 to 14, the timeout on 13), in either key order |
| `review-wrapped-helper/names-fixture` | `tool_used` on `verdict`, with `input_match` on a location in `fixtures/scratch.ts`, which defines `scratchDir` |
| `reviewer-dispatched` | unchanged |

- Each `review-*` case gains a mock, `evals/scenarios/<case>/mocks/report/verdict.md`, answering with the server's acknowledgement, so the reviewer's call is allowed and lands in `toolCalls` under its full name. `allowed_tools` cannot grant an MCP tool, and the real server never starts under `run.sh`'s flags. The hooks still load in a run; whether `PreToolUse` fires on a mocked call is unverified, and no grader depends on it.
- Every saved trace is rewritten: the reviewer's tool call is an assistant line with `parent_tool_use_id`, and the Agent tool's result carries the one-line pointer. `expected.json` keeps each trace's expectations. A new `follow-up-sibling.jsonl` in `review-symptom-fix` files the siblings under `follow_ups`, to record the limit below.
- Each converted grader is proven able to fail offline through `mise run test:evals`, which already requires every grader to be seen both passing and failing.
- **Known limits:**
  - `input_match` is a regex over the serialized input. A sibling filed under `follow_ups` instead of `findings` matches as well, since both use `location`.
  - A parent that calls `verdict` itself is denied by the hook, yet `tool_used` counts denied calls. A `tool_order` of `Agent` (reviewer) before `verdict` narrows this but cannot close it.
  - Neither limit is in the brief. Closing them needs a grader type that `claude plugin eval` lacks.

## Slices

Each slice is a commit, reviewed before it is made. The branch lands whole.

- [ ] 1. Schema file, jq validator and its tests.
- [ ] 2. MCP server, `.mcp.json` and the server tests.
- [ ] 3. `report-record.sh` with the shape, caller, missing-report and storage checks, and its tests, for all four tools. `hooks.json` is not yet changed, so the plugin keeps working on the old path.
- [ ] 4. The reviewer checks moved to data in `review-record.sh`, the text parsers deleted, and the review-gate tests ported. Then the switch in one commit: `hooks.json`, the agent files' `tools` and report rules, `scripts/agents.test.sh` and `events.md`. No commit leaves a hook demanding a tool no agent can call.
- [ ] 5. `review-report.md` and the skills that read reports.
- [ ] 6. Eval graders, per-case mocks and saved traces.
- [ ] 7. `docs/plugin.md` and `docs/reviewer.md`.

## Validation

- `mise run validate`, `mise run test` (it picks up `mcp/*.test.sh` through `scripts/test-shell.sh`'s glob), `mise run lint` (shellcheck covers the new shell files), and `mise run test:evals` and `mise run test:triggers`. Each suite is bounded by `code-writing`'s bounded-run script and started only while the one-minute load average is below 28.
- No paid eval runs. A live check, with the plugin reloaded and a reviewer started on a small diff, goes to the owner as `mise run plugin:update` and a restart, after landing.

## Open questions

Each is stated as a marked assumption with the recommended answer.

- **A1, settled: the eval runs no real MCP server by default.** Per-case mocks, in scope under `evals/scenarios/review-*`, make the tool callable, as Evals says. A paid run still has to confirm that a mocked call from a subagent reaches the trace; that run is the owner's.
- **A2: `SubagentHandback` coexists.** In auto mode the subagent still ends with `SubagentHandback`, whose message becomes a one-line pointer. The hook denies it once when no report was stored.
- **A3: the plan file's fate.** `plans/` is new in this repo. Recommend deleting it in the branch's last commit, since agent-ops keeps plans. The alternative is keeping it as a record.
- **A4: gate files.** If auto mode refuses the `hooks.json` change or the removal of `review-record.sh`'s entries, the worker stops at the accept with the change staged and hands the owner the commands, as the brief says.
