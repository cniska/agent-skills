# Report

A report tells the owner what is in flight, in the order they act on it. Build it from the ledger, the in-flight list rule 4 keeps, each repo's git and the agents the host can list, never from the conversation, so a fresh session can give it too. Gathering it changes nothing; the ledger is rewritten as rule 4 says.

## Sources

- **The ledger**, found as rule 4 says, and the shared file its `shared` key names, for the work several coordinators share. Running, landed and at-risk work is this coordinator's own; another coordinator's workers are not in its report.
- **The in-flight list**, as rule 4 says, for this coordinator's running workers as rule 4 tells them apart, and its queued tasks, from the task tool rule 4 names.
- **Each repo the ledger names**: `git status`, `git worktree list`, the commits since the last report, and the commits on each branch its remote lacks, compared against `git ls-remote` rather than a tracking ref that may be stale.
- **Every agent the host can list**, and the latest output of each.

## Shape

1. **For the owner**, one section in two parts:
   - **Questions**: decisions and steps waiting on the owner, the most blocking first, each answerable in a line. This holds an unlanded branch only once rule 3's recheck passed it, each task waiting on a parked or given-up branch as rule 3 says, and an owner step only once rule 4's check found its wait unmet.
   - **Your asks**: each task marked as the owner's ask, as rule 1 says, with its status (queued, running, waiting or landed since the last report) and what blocks it, or "nothing".
2. **Running**: each other agent, what it is doing, and its last sign of progress.
3. **Landed since the last report**: per repo, by commit.
4. **At risk**: work not committed, not pushed or not reviewed, and agents gone quiet. Take this from git, not the ledger; a ledger claim git contradicts is itself a finding. So is a rule, decision or lesson the ledger or its shared file holds.
5. **Next**: the open work in the order it starts, by owner's order in `principles`, opening with the use it puts first; work nothing blocks starts without asking.

An empty section says "none". End with every choice made that the owner did not ask for.
