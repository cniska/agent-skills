# Resume

Resume a coordinating session: its ledger, its workers and what they left, on this machine or another, in the cloud or under another account. A move to another machine or account needs the ledger in a pushed repo. There only pushed work exists: a running line whose work is not on the remote restarts from its brief, and the old machine's checkouts are out of reach, so step 3 searches only the remotes and any checkouts here.

1. **Pull the ledger's repo, then read the ledger.** Where a pull already ran at session start, read what it said: a failed pull leaves the ledger behind the remote.
2. **Take the in-flight list from the ledger's running lines** and the brief file each names. A worker still running, such as after compaction, keeps going; check in on it as rule 6 says. Check each other line against its repo's remote with `git ls-remote` and `git log`, not a tracking ref:
   - **Landed**: everything the brief asks is on the remote. Mark it done.
   - **Partial**: some of it is. Restart the worker from its brief, naming what already landed and what remains.
   - **Not started**: none of it is. Restart the worker from its brief as it stands.
3. **Look for work the ledger missed**: gather [the report's sources](report.md#sources) for every repo the ledger names, and read the previous session's last report from the session record.
4. **Review orphaned changes before trusting them**: uncommitted or unpushed work no live worker owns goes to a fresh reviewer, then lands, joins a restarted worker's brief, or is discarded on the owner's word. Remove each worktree once its work landed.
5. **Rewrite the ledger before the first report**: running lines for the workers still running or just restarted, open work for the rest, and what resume found that the ledger lacked. Then build the report from what step 3 gathered.
