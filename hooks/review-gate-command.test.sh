#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

readonly UNRESOLVED='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commit blocked: ~/nowhere is not a repository, so the reviewer verdict for this commit cannot be checked. Name the repository by an absolute path in cd."}}'
readonly MULTIPLE='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commit blocked: this command runs more than one git commit, and the reviewer gate checks one commit per command. Run each commit as its own command."}}'
readonly AMBIGUOUS='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Commit blocked: this command reaches its repository in a way the reviewer gate cannot follow, so the verdict for this commit cannot be checked. Commit with '"'"'cd <absolute path> && git commit ...'"'"'."}}'
CREATE="$(refused "Commit blocked: this command creates the repository it commits to, so no reviewer verdict can cover the commit. Run git init or git clone on its own first, then commit once cniska-skills:reviewer has accepted the diff. A scratch repo passes when the command starts with cd <temp path> && or cd \"\$(mktemp -d)\" && and joins every step with &&.")"
readonly CREATE

home_repo="$HOME/project"
mkdir -p "$home_repo"
(cd "$home_repo" && git init -q -b main && printf 'a = 1\n' >lib.py && git add -A && git commit -q -m base && printf 'a = 2\n' >>lib.py)
assert "a commit after cd into a ~ path is gated against that repo" "$(gate_from 'cd ~/project && git commit -am x' "$scratch")" "$(denied 'lib.py (working tree)')"
assert "a commit through git -C with a ~ path is gated" "$(gate_from 'git -C ~/project commit -am x' "$scratch")" "$(denied 'lib.py (working tree)')"
assert "a commit after cd into a \$HOME path is gated" "$(gate_from "cd \$HOME/project && git commit -am x" "$scratch")" "$(denied 'lib.py (working tree)')"
assert "a commit after cd into a quoted path is gated" "$(gate_from "cd \"$home_repo\" && git commit -am x" "$scratch")" "$(denied 'lib.py (working tree)')"
assert "a commit after cd into a \${HOME} path is gated" "$(gate_from "cd \${HOME}/project && git commit -am x" "$scratch")" "$(denied 'lib.py (working tree)')"
assert "a commit after cd into a bare ~ is gated against the home repo" "$(HOME="$home_repo" gate_from 'cd ~ && git commit -am x' "$scratch")" "$(denied 'lib.py (working tree)')"
assert "a commit after cd and ; is gated against that repo" "$(gate_from 'cd ~/project; git commit -am x' "$scratch")" "$(denied 'lib.py (working tree)')"
assert "a commit message that mentions cd does not hide the repo" "$(gate_from "cd ~/project && git commit -am 'cd into place'" "$scratch")" "$(denied 'lib.py (working tree)')"
assert "a commit naming a directory that is not a repository is refused" "$(gate_from 'cd ~/nowhere && git commit -am x' "$scratch")" "$UNRESOLVED"
assert "a commit from outside any repository naming none passes to git, which refuses it" "$(gate_from 'git commit -am x' "$scratch")" ""
for command in \
  '(cd ~/project && git commit -am x)' \
  'git add -A && cd ~/project && git commit -am x' \
  'pushd ~/project && git commit -am x' \
  'git -C ~/project -C . commit -am x' \
  'cd ~/project && git -C sub commit -am x' \
  'GIT_DIR=~/project/.git git commit -am x' \
  'GIT_WORK_TREE=~/project git commit -am x' \
  'git --git-dir=~/project/.git commit -am x' \
  "bash -c 'cd ~/project && git commit -am x'" \
  '(cd ~/project && git commit)'; do
  assert "a commit reaching its repo as [$command] is refused" "$(gate_from "$command" "$scratch")" "$AMBIGUOUS"
done
for command in \
  'git -C ~/project commit -am x && git -C ~/other commit -am y' \
  'cd ~/project && git commit -am x && cd ~/other && git commit -am y' \
  'cd ~/project && git commit -m x && git add -A && git commit -m y' \
  'git commit -m a && git commit -m b'; do
  assert "a command with two commits [$command] is refused" "$(gate_from "$command" "$scratch")" "$MULTIPLE"
done
assert "a commit quoted inside bash -c is not a command the gate reads" "$(gate_from "bash -c 'git commit -am x'" "$home_repo")" ""
for command in \
  $'cat >msg.txt <<EOF\ngit commit -m a && git commit -m b\nEOF\ngit -C ~/project commit -F msg.txt' \
  $'cat <<-\'EOF\' >msg.txt\n\tgit commit -m a\n\tEOF\ngit -C ~/project commit -F msg.txt' \
  "grep -n 'git commit' notes.txt && git -C ~/project commit -am x" \
  "grep -n 'git init' notes.txt && git -C ~/project commit -am x" \
  "jq -r 'select(.command | test(\"git commit\"))' log.jsonl; git -C ~/project commit -am x"; do
  assert "one commit beside commit text in [$command] is gated as one" "$(gate_from "$command" "$scratch")" "$(denied 'lib.py (working tree)')"
done
for command in \
  $'cat <<EOF\ngit commit -m a\nEOF' \
  "grep -rn 'git commit' hooks" \
  "jq -r 'select(.command | contains(\"git commit\"))' log.jsonl"; do
  assert "commit text with no commit in [$command] passes" "$(gate_from "$command" "$home_repo")" ""
done
for command in \
  "echo \"\$(git -C ~/project commit -am x)\"" \
  "echo \"\`git -C ~/project commit -am x\`\"" \
  "echo \`git -C ~/project commit -am x\`" \
  "echo \"unbalanced && git -C ~/project commit -am x" \
  "echo \"a && git -C ~/project commit -am x\" 'unbalanced" \
  "bash -lc 'git status && git -C ~/project commit -am x'" \
  "cd '$home_repo' && git commit -am x"; do
  assert "a commit in quotes that still run, or after an unbalanced quote, [$command] is gated" "$(gate_from "$command" "$scratch")" "$(denied 'lib.py (working tree)')"
done
assert "two commits on separate lines are refused" "$(gate_from $'git -C ~/project commit -am x\ngit -C ~/project commit -am y' "$scratch")" "$MULTIPLE"
assert "a commit after a closed heredoc is still counted" "$(gate_from $'cat <<EOF\nx\nEOF\ngit -C ~/project commit -am x && git -C ~/project commit -am y' "$scratch")" "$MULTIPLE"
assert "a commit that creates its repo outside a temp directory is refused" "$(gate_from 'git init -q && git commit -m x' /)" "$CREATE"
assert "a scratch repo created and committed to under a temp directory passes" \
  "$(gate_from 'git init -q -b main r && cd r && git commit -q --allow-empty -m i && git init -q --bare ../o.git' "$scratch")" ""
assert "a scratch repo created, added and committed in a temp directory passes" "$(gate_from 'git init -q && git add -A && git commit -qm start' "$scratch")" ""
assert "a scratch repo named by an absolute temp path passes" "$(gate_from "git init -q $scratch/s && cd $scratch/s && git commit -m x" "$scratch")" ""
assert "a scratch repo named by an absolute temp path from a cwd outside the temp directories is refused" "$(gate_from "git init -q $scratch/s && cd $scratch/s && git commit -m x" /)" "$CREATE"
for command in \
  "git init -q && git -C $scratch status && git commit -m x" \
  "(cd $scratch) && git init -q && git commit -m x"; do
  assert "a temp target that may not move the commit [$command] from outside the temp directories is refused" "$(gate_from "$command" /)" "$CREATE"
done
for command in \
  'git init -q /usr/r && cd /usr/r && git commit -m x' \
  'git init -q ../r && cd .. && git commit -m x' \
  'git init -q && cd && git commit -m x' \
  'git init -q && cd - && git commit -m x' \
  "git init -q && cd \"\$X\" && git commit -m x" \
  'git init -q && GIT_DIR=/usr/r/.git git commit -m x'; do
  assert "a repo created in a temp directory whose commit may land elsewhere [$command] is refused" "$(gate_from "$command" "$scratch")" "$CREATE"
done
assert "a scratch repo under a home outside the temp directories is refused" "$(HOME=/usr gate_from 'git init -q ~/r && cd ~/r && git commit -m x' "$scratch")" "$CREATE"
assert "a repo created from a cwd outside the temp directories with a relative cd is refused" "$(gate_from 'git init -q r && cd r && git commit -m x' /)" "$CREATE"
assert "a commit after cloning into a temp directory passes" "$(gate_from 'git clone -q ~/project copy && git -C copy commit -m x' "$scratch")" ""
checkout="$(cd "$HERE/.." && pwd)"
for command in \
  "cd $scratch/x && git init -q && git commit -m x" \
  "cd $scratch/y && git init -q && git commit -m a && git commit -m b" \
  "git -C $scratch/w init -q && git -C $scratch/w commit -m a && git -C $scratch/w commit -m b" \
  "cd \"\$(mktemp -d)\" && git init -q && git commit -m x" \
  'cd /tmp && git clone -q ~/project copy && git -C copy commit -m x'; do
  assert "a scratch repo reached from a checkout as [$command] passes" "$(gate_from "$command" "$checkout")" ""
done
for command in \
  'cd /usr/x && git init -q && git commit -m x' \
  'cd /usr/x && git init -q && git commit -m a && git commit -m b' \
  "cd $scratch/z && git init -q && git commit -m a && cd $checkout && git commit -m b" \
  "cd $scratch/z && git init -q && git commit -m a && git -C $checkout commit -m b" \
  "cd $scratch/z && git init -q; git commit -m x" \
  "cd $scratch/z; git init -q && git commit -m x" \
  "cd $scratch/z && git init -q || git commit -m x" \
  "git -C $scratch/w init -q && git -C $scratch/w commit -m a && git commit -m b" \
  "git init -q $scratch/w && git -C w commit -m x" \
  "git init -q $scratch/w && echo \"git -C $scratch/w commit\" && git commit -m x" \
  "(cd $scratch/z) && git init -q && git commit -m x" \
  "cd \"\$(mktemp)\" && git init -q && git commit -m x" \
  "cd \"\$(mktemp -d /usr/gate.XXXXXX)\" && git init -q && git commit -m x" \
  "cd \$(mktemp -d /tmp/gate.XXXXXX)/w && git init -q && git commit -m x" \
  "cd \"\$(mktemp -dp /tmp)\" && git init -q && git commit -m x" \
  "cd \"\$(mktemp -d /tmp/gate)\" && git init -q && git commit -m x" \
  "cd \"\$(mktemp -d /tmp/gate-missing/w.XXXXXX)\" && git init -q && git commit -m x" \
  "D=\$(mktemp -d) && cd \$D && git init -q && git commit -m x" \
  "cd \"\$(mktemp -d)\"; git init -q && git commit -m x" \
  "cd \$(mktemp -d) && git init -q && git commit -m x" \
  "git init -q \"\$(mktemp -d)\" && git -C \"\$(mktemp -d)\" commit -m x" \
  "git init -q \"\$(mktemp -d)\"; git -C \"\$(mktemp -d)\" commit -m x" \
  'git clone -q ~/project copy && git -C copy commit -m x'; do
  assert "a repo created from a checkout whose commit may land outside the temp directories [$command] is refused" "$(gate_from "$command" "$checkout")" "$CREATE"
done
recorded() { local command; command="$(<"$HERE/fixtures/commit-gate/denied-$1.txt")" || return; printf '%s' "${command//@S@/$scratch}"; }
mktemp_sh_c_newlines="$(recorded mktemp-sh-c-newlines)" || exit 1
clone_literal_temp="$(recorded clone-literal-temp)" || exit 1
s_variable_semicolons="$(recorded s-variable-semicolons)" || exit 1
d_variable="$(recorded d-variable)" || exit 1
set_e_semicolons="$(recorded set-e-semicolons)" || exit 1
assert "a denied scratch command that commits inside sh -c across newlines is still refused" "$(gate_from "$mktemp_sh_c_newlines" "$checkout")" "$CREATE"
assert "a denied scratch command that clones under a literal temp path joined by && passes" "$(gate_from "$clone_literal_temp" "$checkout")" ""
assert "a denied scratch command that reaches its directory through S= and ; is still refused" "$(gate_from "$s_variable_semicolons" "$checkout")" "$CREATE"
assert "a denied scratch command that reaches its directory through D= is still refused" "$(gate_from "$d_variable" "$checkout")" "$CREATE"
assert "a denied scratch command that runs set -e; S= and ; is still refused" "$(gate_from "$set_e_semicolons" "$checkout")" "$CREATE"
mkdir -p "$scratch/locked"
chmod 555 "$scratch/locked"
assert "a mktemp -d under a TMPDIR it cannot write to is refused" "$(TMPDIR="$scratch/locked" gate_from "cd \"\$(mktemp -d)\" && git init -q && git commit -m x" "$checkout")" "$CREATE"
chmod 755 "$scratch/locked"
gate_stderr() { jq -cn --arg command "$1" --arg cwd "$2" '{tool_name: "Bash", tool_input: {command: $command}, cwd: $cwd}' | { "$GATE" >/dev/null; } 2>&1; }
for command in \
  'cd /usr/x && git init -q && git commit -m x' \
  'git init -q && git commit -m x' \
  'cd /usr && git commit -am x' \
  'git commit -am x'; do
  assert "a commit outside the temp directories [$command] says nothing on stderr" "$(gate_stderr "$command" /)" ""
done
record_handback "$(report "$repo" accept)" >/dev/null
assert "a git -C commit quoted in echo does not name the commit's repo" "$(gate_from "echo \"git -C $repo commit\" && git commit -am x" "$home_repo")" "$(denied 'lib.py (working tree)')"
assert "a look-alike in a heredoc leaves a commit gated" "$(gate_from $'cat >notes.txt <<EOF\n'"$LOOK_ALIKE"$'\nEOF\ngit -C ~/project commit -am x' "$scratch")" "$(denied 'lib.py (working tree)')"
assert "a look-alike in a heredoc adds no commit" "$(gate_from $'cat >notes.txt <<\'EOF\'\n'"$LOOK_ALIKE"$'\nEOF\ngit status' "$scratch")" ""

finish
