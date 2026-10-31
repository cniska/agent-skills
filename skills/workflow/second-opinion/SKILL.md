---
name: second-opinion
description: Review a consequential call or a document's facts by having a different model try to disprove them, then weigh its findings against your own position. Use before a decision that is expensive to reverse, or before a document asserts facts.
---

# Second opinion

A model that checks its own call tends to agree with itself. Have a different model try to disprove the call, and treat each point where it disagrees as information about the call.

## Steps

1. **Pick a reviewer that can know the answer.** Use a `powerful`-tier model other than the one that made the call, run as a `researcher` agent where the host can start one, since it checks each claim against the session record, the repos and their upstreams. Otherwise use another model the host runs, since it shares the host's tools and product knowledge. Another provider's model adds independence only where its knowledge and tools reach the subject. Whether something is still true needs live access to the source.
2. **Hand over the smallest unit that can be reviewed**: the artifact, plus the constraints a decision must meet or the sources a fact should be checked against.
3. **Ask the reviewer to disprove the call.** Write your own position down first, where the reviewer does not see it. Ask what is wrong, say the author may be overconfident, and name the kinds of failure to hunt for rather than the ones you suspect. Ask for a position, and accept "nothing found after checking X" as one.
4. **Require a citation for every factual finding**, such as `file:line` or a URL. Read a finding at its source before you act on it. Report each finding you did not check as unverified.
5. **Weigh the findings against your position.** When the reviewer reports through a tool, read its recommendation, evidence and sort from the stored report rather than from its closing message. Apply what survives the source check, and report each disagreement with both positions.
6. **Stop when a pass finds nothing new.** Run another pass only after the artifact changes materially.
