---
name: second-opinion
description: Review a consequential call through an independent read from a different model. Use before a decision that is expensive to reverse, or before a document asserts facts.
---

# Second opinion

One model agreeing with itself is not verification. Have a different model attack the call, and treat divergence as signal, not noise.

## Workflow

1. **Pick a reviewer that can know the answer.** Use a `powerful`-tier model other than the one that made the call, run as a `researcher` agent where the host can start one, since it checks each claim against the session record, the repos and their upstreams. Otherwise prefer another model the host runs, since it shares the host's tools and product knowledge. Another provider adds independence only where its knowledge and tools reach the subject; for whether something is still true, live access to the source outweighs anything learned in training.
2. **Hand over the smallest reviewable unit**: the artifact, plus the constraints a decision must meet or the sources a fact should be checked against.
3. **Frame it to disprove.** Write your own position down first and keep it out of the prompt. Ask what is wrong, say the author may be overconfident, and name the kinds of failure to hunt for, not the ones you suspect. Demand a position, and accept "nothing found after checking X" as an answer.
4. **Require a citation for every factual finding**, such as `file:line` or a URL. Read any finding you act on at its source, and report the rest as unverified rather than dropping or adopting them.
5. **Weigh, don't adopt.** Where the reviewer reports through a tool, read its recommendation, evidence and sort from the stored report, not its closing message. Compare the findings with the position you wrote down, apply what survives the source check, and report each disagreement with both positions.
6. **Stop when a pass surfaces nothing new.** Run another pass only after a material change.

## See also

- `skill-writing` — judges a changed skill by its real-use signals instead of debating it
- `review` — structured review of a diff
