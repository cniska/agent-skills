# Missing captures

Read the verify skill the brief names, its feature map and Evidence, and the run's list of what it could not reach with the reason for each. Put each capture the brief lacks, of a touched state or of its reference screen, under the first of these cases it meets, and name every one under its case:

1. **No reference exists:** a reference screen's capture, where the state's platform reference in `ui-design` names no reference it can reach. A capture of the state itself never stops here. It goes under Conflicts, as "Against a named reference screen" in the skill says, and holds back no accept.
2. **Broken build:** the run says it could not reach the state because the change fails, a product defect. It is a finding on the change.
3. **Verify skill short:** the repo has no verify skill; its feature map has no visible state entry for the state, or leaves out its reference screen or the way to reach it; its Evidence cannot capture what the state needs; or the run blames the harness for a state, or a reachable reference, that the skill lists. It is a finding whose fix is that verify skill made or brought up to the state, not a rerun.
4. **Run blocked:** the run gives a cause that is neither the change nor the harness, such as a host lacking a credential, a toolchain or a simulator, a locked screen, or a defect outside the change. It is a finding that quotes the run's reason, and the commit waits on that blocker.
5. **Run short:** the skill lists the state and its reference and can capture them, yet the brief has no capture, while the run reports no trouble with them or the brief leaves out the run's unreached list or a reason in it. It is a finding that names each capture to attach from the run's evidence directory, or to take on a rerun.
