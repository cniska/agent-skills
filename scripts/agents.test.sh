#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS="$(cd "$HERE/../agents" && pwd)"
SKILLS="$(cd "$HERE/../skills" && pwd)"

pass=0
fail=0
assert() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$3" "$2"
  fi
}

frontmatter_list() {
  awk -v key="$2" '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && $0 ~ "^" key ":" { in_list = 1; next }
    in_list && /^  - / { sub(/^  - /, ""); print; next }
    in_list { in_list = 0 }
  ' "$1"
}

frontmatter_value() {
  awk -v key="$2" '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && index($0, key ": ") == 1 { print substr($0, length(key) + 3) }
  ' "$1"
}

PLUGIN="$(cd "$HERE/../.claude-plugin" && pwd)"
assert "the plugin is named cniska-skills" "$(grep -c '^  "name": "cniska-skills",$' "$PLUGIN/plugin.json")" 1
assert "the marketplace is cniska and lists cniska-skills" "$(grep -c -e '^  "name": "cniska",$' -e '^      "name": "cniska-skills",$' "$PLUGIN/marketplace.json")" 2
assert "the agents are designer, researcher, reviewer and worker" "$(find "$AGENTS" -type f -name '*.md' -exec basename {} \; | LC_ALL=C sort | tr '\n' ' ')" "designer.md researcher.md reviewer.md worker.md "
assert "worker preloads task and principles, nothing more" "$(frontmatter_list "$AGENTS/worker.md" skills | tr '\n' ' ')" "cniska-skills:task cniska-skills:principles "
assert "worker inherits every MCP tool, so its frontmatter has no tools line" "$(sed -n '2,/^---$/p' "$AGENTS/worker.md" | grep -c '^tools:')" 0
assert "worker drops only the built-in tools no route calls, keeping ToolSearch and every MCP tool" "$(frontmatter_value "$AGENTS/worker.md" disallowedTools)" "Artifact, ArtifactComments, ArtifactData, CronCreate, CronDelete, CronList, DesignSync, EnterWorktree, ExitWorktree, ListMcpResourcesTool, LSP, NotebookEdit, PushNotification, ReadMcpResourceDirTool, ReadMcpResourceTool, RemoteTrigger, ReportFindings, ScheduleWakeup, ShareOnboardingGuide, TodoWrite"
assert "reviewer preloads principles, nothing more" "$(frontmatter_list "$AGENTS/reviewer.md" skills | tr '\n' ' ')" "cniska-skills:principles "
assert "reviewer reads files, loads the review skills and reports its verdict, nothing more" "$(frontmatter_value "$AGENTS/reviewer.md" tools)" "Read, Grep, Glob, Skill, mcp__plugin_cniska-skills_report__verdict"
assert "researcher preloads second-opinion, search-sessions and principles" "$(frontmatter_list "$AGENTS/researcher.md" skills | tr '\n' ' ')" "cniska-skills:second-opinion cniska-skills:search-sessions cniska-skills:principles "
assert "designer preloads ui-review, ui-design, search-sessions and principles" "$(frontmatter_list "$AGENTS/designer.md" skills | tr '\n' ' ')" "cniska-skills:ui-review cniska-skills:ui-design cniska-skills:search-sessions cniska-skills:principles "
assert "designer reads files and the record, loads skills and reports its verdict, nothing more" "$(frontmatter_value "$AGENTS/designer.md" tools)" "Read, Grep, Glob, Skill, Bash, mcp__plugin_cniska-skills_report__verdict"
assert "researcher reads files, the record and the web, and reports its research" "$(frontmatter_value "$AGENTS/researcher.md" tools)" "Read, Grep, Glob, Bash, WebFetch, WebSearch, mcp__plugin_cniska-skills_report__research"
SCHEMAS="$(cd "$HERE/../mcp" && pwd)/report-schemas.json"

for agent in "$AGENTS"/*.md; do
  name="$(basename "$agent" .md)"
  count=0
  while IFS= read -r skill; do
    count=$((count + 1))
    assert "$name preloads $skill, which exists" "$(compgen -G "$SKILLS/*/${skill#cniska-skills:}/SKILL.md" >/dev/null && echo yes || echo no)" yes
  done < <(frontmatter_list "$agent" skills)
  assert "$name preloads at least one skill" "$([ "$count" -gt 0 ] && echo yes || echo no)" yes
  while IFS= read -r skill; do
    assert "$name names $skill, which exists" "$(compgen -G "$SKILLS/*/${skill#cniska-skills:}/SKILL.md" >/dev/null && echo yes || echo no)" yes
  done < <(grep -o '`cniska-skills:[a-z-]*`' "$agent" | tr -d '`' | LC_ALL=C sort -u)
  while IFS= read -r tool; do
    assert "$name names the report tool $tool, which the report server serves" \
      "$(jq -r --arg tool "${tool#mcp__plugin_cniska-skills_report__}" '.tools | has($tool)' "$SCHEMAS")" true
  done < <(grep -o 'mcp__plugin_cniska-skills_report__[a-z_]*' "$agent" | LC_ALL=C sort -u)
done

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
