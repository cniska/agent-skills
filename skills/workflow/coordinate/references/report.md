# Report

A report tells the owner what is in flight, in the order they act on it. Build it from the ledger, the in-flight list rule 4 keeps, each repo's git and the agents the host can list, never from the conversation, so a fresh session can give it too. Gathering it changes nothing; the ledger is rewritten as rule 4 says.

## Sources

- **The ledger**, found as rule 4 says, and the shared file it links, for the owner's decisions and standing rules. Running, landed and at-risk work is this coordinator's own; another coordinator's workers are not in its report.
- **The in-flight list**, as rule 4 says, for this coordinator's running workers as rule 4 tells them apart.
- **Each repo the ledger names**: `git status`, `git worktree list`, the commits since the last report, and the commits on each branch its remote lacks, compared against `git ls-remote` rather than a tracking ref that may be stale.
- **Every agent the host can list**, and the latest output of each.

## Shape

1. **Waiting on the owner**: decisions and tasks, the most blocking first, each answerable in a line.
2. **Running**: each agent, what it is doing, and its last sign of progress.
3. **Landed since the last report**: per repo, by commit.
4. **At risk**: work not committed, not pushed or not reviewed, and agents gone quiet. Take this from git, not the ledger; a ledger claim git contradicts is itself a finding.
5. **Next**: the open work in the order to start it, each with the reason it goes there.

An empty section says "none". End with every choice made that the owner did not ask for.
