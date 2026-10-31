# Update

A formal verification skill exists: realign it and its check with today's code, under its own name.

When the skill falls short of [Create](create.md), first add what Create step 3 and the records of step 5 require: the check wired under the task runner, the checker pinned, the coverage record, and the sync commit. With none recorded, take the sync commit as the last commit that touched the verification files, and say so in the report. The model and its properties stay as they are until step 3 below. Then:

1. **Baseline run**, once, before any edit to the model or its properties, with its result noted. Green here shows only that the stale model still agrees with itself. Red may be drift or a defect, which step 5 settles.
2. **Walk the covered history** from the sync commit to `HEAD`, commit messages included. Follow covered functions through renames, splits and moves, and look for code added since that mutates guarded state. Sort each change into one of four kinds:
   - inert for the model, decided by reading the model rather than trusting the commit message.
   - a change of shape the model no longer matches, such as one step becoming two or a new path to guarded state.
   - an intended shift in what the code guarantees, backed by its tests, docs or message.
   - a guarantee that may now fail, with nothing saying the shift was meant.
3. **Revise from the source.** Rewrite each changed part so it traces again to a file and symbol, one indivisible step still one action, before rerunning and without shaping it toward a pass. A property moves only with an intended shift in the guarantee, and the report quotes its text before and after beside the evidence. Bounds stay put unless the code change invalidates them, and a reduced bound goes in the report.
4. **Scope of edits:** the model or harness, its property files, the check's wiring and the skill. Product code changes only at the user's request.
5. **Second run, each result judged.** Prove a pass again as Create step 6 proves it, since an updated model may have lost the power to fail. Retrace each failure in the actual code. A step the code cannot take is a modeling error to fix and name. A path the code can take is a bug, reported with the commit that first let it through, its path in the code's vocabulary and one sentence on the harm. A replay test showing the bug is evidence in the report, not a product commit. The entry point calls the check only once this run is green. A check left red stays on the topic branch, out of the entry point, as Create step 6 says.
6. **Bring the skill in line**: the coverage record, commands, bounds, assumptions, the wall-clock time of step 5's proving run, and the sync commit moved to the commit checked. A check with no proving run keeps its old time, and a blocked one also keeps its old sync commit. Then walk the skill end to end as its reader would.
