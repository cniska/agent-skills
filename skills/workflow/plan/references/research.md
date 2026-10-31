# Research

Load this before fanning reads out to subagents while planning.

- **Know the load-bearing files before fanning out,** since a fan-out started before that is a guess.
- **Read the code yourself** when one search answers the question, or when the code, spec or prose that carries the change runs to a few hundred lines. A subagent that summarizes a file you could have read costs more than it saves and loses the exact signatures the plan needs.
- **Give each subagent one independent question,** not one file, and run them in parallel, at most 5.
- **Match the tier to the question.** Use the fast tier for retrieval, such as where a thing lives or what it does. Use the powerful tier for judgment, such as which shape fits, what breaks and what it costs. "Does X exist anywhere here?" needs judgment about what counts as an X, so treat a fast-tier "not found" as unproven.
- **Delegate only real work.** A subagent that only confirms a call you already made adds nothing. One that re-derives the call and brings grounding you lacked is worth its cost.
- **Verify each load-bearing claim a subagent returns** before planning on it, since a wrong answer reads the same as a right one and the cost lands in the plan.
