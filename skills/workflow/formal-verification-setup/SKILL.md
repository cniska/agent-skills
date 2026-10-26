---
name: formal-verification-setup
description: Create or update a project-local formal verification skill whose check model-checks or proves the costliest promise the tests seldom exercise, run as one of the repo's checks. Use when concurrency, retry logic, a state machine, a parser or unsafe memory handling needs a guarantee a test suite cannot give, or when an existing formal verification skill may have drifted from the code.
argument-hint: "[area-or-property]"
---

# Formal verification setup

A test covers the cases someone wrote down; a formal check covers all of a stated scope, such as each interleaving a model allows, each input below a bound, or the whole input space. This skill finds where in the repo that reach pays off most, checks a single property there, and hands the next agent, arriving cold mid-change, a project-local skill to recheck it. Its verdict has to be one the owner can rely on and act on with no knowledge of the checker's syntax.

The mode follows from whether a formal verification skill already exists in the project: a project-local skill, hand-written or not, whose check feeds named source to a model checker, a prover or a verifier that reads the code itself, or drives property-based inputs through named functions over a stated scope. **Create** (none exists) writes `<project>-formal-<area>`; **Update** (one exists) realigns that skill and its check with today's code under the skill's own name. Never write a second skill beside an existing one.

## Placement

The skill goes in the directory of skills the repo's agents load, never in a directory of skills it ships to others. The check itself lives in the repo's own tool setup and task runner, beside its other checks. Make the change on a topic branch in its own worktree and commit it there; pushing and the PR stay with the user.

## Create

1. **Pick the target by reading the code.** Start from an area or bug the user named; otherwise read the code and ask only what it cannot show. Choose the guarantee whose failure would hurt users most and that no current test drives to its failing case, not the property easiest to check.
2. **Let the question pick the tool**, the cheapest one that answers it, and tell the user why. A question about steps landing in a harmful order goes to a model checker run on a compact abstraction of the design, TLA+ by default whatever the language. Whether the code holds for every input, such as memory safety, integer overflow or an invariant of a data structure, goes to a verifier that works on the source; where the language has none, say so and fall back to property-based inputs driven through the actual functions, never through a hand-written imitation of them. When no bound is enough and the claim must cover any size, reach for a proof assistant. Favor whatever the team can already set up on their own machines.
3. **Make it one of the repo's checks.** The check is one command under the repo's task runner, and once it is green, as step 6 says, the repo's check entry point calls it, so every change that runs the repo's checks runs it too. Pin the checker in the repo's own tool setup at a version that cannot move. For TLA+ that is an immutable `tla2tools.jar` release fetched with its checksum, one line in mise where the repo uses it, never the rolling `v1.8.0` prerelease, and a pinned Java beside it. Let the checker's non-zero exit on a violation fail the check, as TLC's does, rather than parse its output.
4. **Write the model or harness to these rules:**
   - **Faithful.** Each variable, action and assumption traces to a file and symbol in the repo, named with this repo's nouns. Each action is one indivisible step in the code, and its name or its line in the coverage record gives that code's file and symbol.
   - **Able to fail**, as proven able to fail in `principles` says, shown for each property against a deliberately broken copy of the guarded code.
   - **Results stand.** A violation in today's code is a result to report; never loosen a property or the model to turn it green, and touch product code only at the user's request.
   - **Scoped honestly.** A pass is stated with its bounds and assumptions, and with what the model leaves out.
   - **Plain to read.** Say in plain words what must always hold, and separately what goes wrong for users if it does not. A counterexample is told as a short sequence of plain steps in the code's own words, then replayed against the real code through a test written per `test-writing`; a step the code cannot take means the model is wrong.
   - **Cheap.** Keep the bounds small enough that the check takes no longer than the repo's slowest existing check.
   - **Tracked.** A coverage record names, per check, the files and functions it models, beside the sync commit: the newest commit whose code the model was checked against and found to match.
5. **Write the skill** in the shape of the repo's own skills. Its frontmatter names the area and when to load it, for a skill without frontmatter is invisible to the agent. Reading only it, the next agent can see whether its change reaches covered code, run the check, separate a defect in the code from a defect in the model, and revise the model when the change alters behavior on purpose. It carries the coverage record and sync commit, and lets the sync commit advance only after the model is confirmed against the code at that later commit. Every command and path in it is the one this repo actually uses; nothing is left to fill in.
6. **Prove it.** Walk the new skill end to end the way its reader would, against real code broken so it violates the property, the break made inside a temporary worktree and never the working tree. The check has to go red. Back in the working tree it is green, or red only for findings the report names. A check red on today's code is the result: the bug, told in plain steps with its replay test. The model, the skill and the replay test stay on the topic branch, the check joins the entry point and is committed there only once it is green, and the user decides whether a product fix lands first. Record the check's wall-clock time from this run in the skill. A missed break or a step that will not run means fixing the skill or the model, never the break. A skill that never finished this run stays uncommitted.

## Update

When the skill falls short of Create, first add what Create step 3 and the records of step 5 require: the check wired under the task runner, the checker pinned, the coverage record, and the sync commit, taken as the last commit that touched the verification files when none is recorded, which the report says. The model and its properties stay as they are until step 3 below. Then:

1. **Baseline run**, once, before any edit to the model or its properties, with its result noted. Green here shows only that the stale model still agrees with itself; red may be drift or a defect, which step 5 settles.
2. **Walk the covered history** from the sync commit to `HEAD`, commit messages included. Follow covered functions through renames, splits and moves, and look for code added since that mutates guarded state. Sort each change: inert for the model, decided by reading the model rather than trusting the commit message; a change of shape the model no longer matches, such as one step becoming two or a new path to guarded state; an intended shift in what the code guarantees, backed by its tests, docs or message; or a guarantee that may now fail, with nothing saying the shift was meant.
3. **Revise from the source, never from the verdict.** Rewrite each changed part so it traces again to a file and symbol, one indivisible step still one action, before rerunning and without shaping it toward a pass. A property moves only with an intended shift in the guarantee, and the report quotes its text before and after beside the evidence. Bounds stay put unless the code change invalidates them; a reduced bound goes in the report.
4. **Scope of edits:** the model or harness, its property files, the check's wiring and the skill, nothing more. Product code changes only at the user's request.
5. **Second run, each result judged.** A pass is proven again as Create step 6 proves it, since an updated model may have lost the power to fail. Each failure is retraced in the actual code: a step the code cannot take is a modeling error to fix and name; a path the code can take is a bug, reported with the commit that first let it through, its path in the code's vocabulary and one sentence on the harm. A replay test showing the bug is evidence in the report, not a product commit. The entry point calls the check only once this run is green; a check left red stays on the topic branch, out of the entry point, as Create step 6 says.
6. **Bring the skill in line**: the coverage record, commands, bounds, assumptions, the wall-clock time of step 5's proving run, and the sync commit moved to the commit checked. A check with no proving run keeps its old time, and a blocked one also keeps its old sync commit. Then walk the skill end to end as its reader would.

## Output

Name the mode, the skill, the check's command, and the files added or changed. Create states the property and its harm, the tool and why, the bounds, the wall-clock time, what the check found, and what it leaves out. Update gives each check one outcome, **in sync** (nothing since the sync commit changes what it describes, and it passes), **updated** (revised to match today's code, and green), **bug** (the model matches the code, which violates the property), or **blocked** (realigning or running it failed, with the cause), and a check may be updated and bug at once; with the commits read, each change to the model and its reason, the break used to prove a rerun pass, each bug in plain steps, and what is still uncovered. A pass that turned into a failure after the update is named as a stale pass. Model updates land in their own commit, never mixed with a product fix.

## See also

- `task` for the Close step that runs the repo's checks, this one included, on every change
- `principles` for proven able to fail
- `test-writing` for the test that replays a counterexample
- `skill-writing` for the generated skill's shape
- `verification-setup` for the sibling skill that drives the running app

## Red flags

- Writing a second formal verification skill beside an existing one
- Choosing the easiest property to check instead of the costliest one to break
- A green check outside the repo's check entry point, or a checker version that can move, such as the rolling TLA+ prerelease
- A parser over the checker's output where its exit status already fails the check
- An action that bundles steps the code can interleave, or one with no file and symbol behind it
- Loosening a property or the model to turn a red check green
- A pass reported without its bounds, or a counterexample left in the checker's own terms
- A check slower than the repo's slowest existing check
- Breaking the property in the working tree rather than a temporary worktree
- Moving the sync commit without confirming the model describes the code there
- Committing a skill whose check was never seen failing
- Wiring a check that is red on today's code into the check entry point
