---
name: writing
description: Write or edit prose for its reader, plain and direct, without generic AI phrasing, keeping its meaning and confidence. Use when writing or editing anything people read, such as an email, a message, a README or doc, a proposal, a PR description or a review, or instructions an agent follows, such as a skill, a rules file or a brief.
---

# Writing

Write naturally for the intended reader. Lead with the point, then give the detail or evidence that supports it, in a tone that fits the context.

## What matters

- **Short and direct.** Use short sentences and clear language, each point in the fewest words that keep its meaning, without sounding clipped. Expand shorthand that drops articles or verbs, and rewrite phrasing bent to stay short ("the test it is failing" for "a failing test").
- **Concrete over abstract.** Name the real problem early. Explain tradeoffs, constraints, reliability and verification when they matter. Give a claim its mechanism, result or example, and name the source behind an attribution or remove the claim.
- **Plain words.** Prefer plain words and active actors. Split dense sentences, and repeat the same term instead of cycling through synonyms. Break a noun cluster of more than three words with a verb or a preposition: "the worker brief temp folder path" becomes "the path to the worker's temp folder".
- **Controlled intensity.** Use contrast only when it marks a real distinction. Cut lines that restate the prose for rhythm: a repeated "Not X. Y." formula, two-beat slogans ("A prompt asks. A sandbox decides."), and wordplay that reuses a word as the hinge. Reduce the punchiness when a draft starts sounding like a manifesto, and allow rhetorical emphasis in public writing only when the substance earns it.
- **The owner's words as theirs.** Restate what the owner said or decided in clear English, as theirs, rather than quoting their wording. Carry copy the owner set on purpose for a product as they set it.

## Edit

Preserve the intended meaning and level of confidence. Remove words or structure that make the reader work harder without adding a fact.

- Cut marketing language, vague enthusiasm, filler transitions, corporate padding, and summary lines that sound wise but state nothing a reader could check.
- Cut forced groups of three, false ranges, ornate metaphors, stock framing phrases, and human traits given to a tool, rule or document ("a sandbox does not skim", "confidently wrong"). Agents and models are real actors.
- After an edit, re-read each "it", "its", "either", "both" and "above" against what its own sentence and the neighboring sentences now name, and name the thing where more than one fits.
- Use emphasis, headings and bullets where they help the reader scan, and words rather than punctuation to carry emphasis.
- Keep uncertainty when the evidence is uncertain, and cut hedging that adds no precision.

## Adapt to the medium

- **Email:** Keep the directness and leave room for warmth.
- **Chat:** Put the point first. Use bullets only when they improve scanning.
- **Docs and proposals:** Structure the argument around decisions, tradeoffs and evidence. State assumptions.
- **PR review replies:** Lead with the action or finding. Let the thread carry its own history and references.
- **Resumes:** Lead with concrete actions and outcomes. Follow the format's point-of-view convention.
- **Instructions an agent follows:** Skills, agent definitions, rules files and briefs. Give one instruction per sentence, so two instructions joined by a semicolon become two sentences. Put the condition before the command: "When the check fails, stop." Use one word for each concept and give each word one meaning. Name a concrete threshold, such as a count, a size or a named state, in place of a qualitative word such as "large" or "often".

For technical readers, assume shared context. For any reader outside the code, reduce jargon and explain consequences alongside mechanisms. Keep the writer's point of view when it serves the purpose and audience.

## Documents that last

A README, a spec, an architecture doc, a decision record or an agent rules file is read long after it is written, so it holds only what stays true.

- It changes in the same commit as the behavior it describes, as no drift in `principles` says.
- It states what holds now. History lives in version control.
- Each fact lives in one place; link to its owner rather than restating it.
- Leave out volatile numbers (sizes, ports, line counts, latency), and describe a collection that can grow without counting it.
- Say what is, not what isn't. Use plain words over metaphor such as spine, rail, seam, blast radius, theater or posture. Cut restatement and filler: any word or sentence whose deletion loses nothing.
- A page takes the structure, depth and voice of the pages beside it.
- Use US spelling, unless the repo already uses another.
