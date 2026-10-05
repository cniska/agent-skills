---
name: writing
description: Write or edit natural prose for emails, docs, proposals, PR descriptions, reviews, and messages. Remove generic AI phrasing while preserving meaning and audience fit.
---

# Writing

Write naturally for the intended reader. Lead with the point, then give the detail or evidence that supports it. Fit the tone to the context.

## Style

- Use short to medium sentences and clear, direct language. Be concise without sounding clipped.
- Name the real problem early. Explain tradeoffs, constraints, reliability, and verification when they matter.
- Prefer concrete mechanisms to abstractions. Treat claims as things to justify, not decorate.
- Use contrast when it clarifies a real distinction. Cut lines that only restate the prose for rhythm: a repeated "Not X. Y." formula, two-beat slogans ("A prompt asks. A sandbox decides."), and wordplay that reuses a word as the hinge.
- Keep intensity controlled. Reduce the punchiness when a draft starts sounding like a manifesto.

## Edit

Preserve the intended meaning and level of confidence. Remove words or structure that make the reader work harder without adding a fact.

- Cut marketing language, vague enthusiasm, filler transitions, corporate padding, and summary lines that sound wise but state nothing a reader could check.
- Name the source behind an attribution or remove the claim. Replace vague claims with a concrete mechanism, result, or example.
- Prefer plain words and active actors. Split dense sentences; repeat the same term instead of cycling through synonyms.
- Remove forced groups of three, false ranges, ornate metaphors, stock framing phrases, and human traits given to a tool, rule or document ("a sandbox does not skim", "confidently wrong"). Agents and models are real actors.
- Expand shorthand that drops articles or verbs, and rewrite phrasing bent to stay short ("the test it is failing" for "a failing test"). A concise sentence should still read naturally.
- Use emphasis, headings, and bullets when they help the reader scan. Avoid emphasis that adds no meaning.
- Use punctuation that suits the sentence. Rewrite for clarity when punctuation is carrying emphasis the words could express.
- Keep uncertainty when the evidence is uncertain. Cut hedging that adds no precision.

## Adapt to the medium

- **Email:** Keep the directness and leave room for warmth.
- **Chat:** Put the point first. Use bullets only when they improve scanning.
- **Docs and proposals:** Structure the argument around decisions, tradeoffs, and evidence. State assumptions.
- **Public writing:** Allow rhetorical emphasis when the substance earns it.
- **PR review replies:** Lead with the action or finding. Let the thread carry its own history and references.
- **Resumes:** Lead with concrete actions and outcomes. Follow the format's point-of-view convention.

For technical readers, assume shared context. For external readers, reduce jargon and explain consequences alongside mechanisms.
Keep the writer's point of view when it serves the purpose and audience.

## Documents that last

A README, a spec, an architecture doc, a decision record or an agent rules file is read long after it is written, so it holds only what stays true.

- It changes in the same commit as the behavior it describes.
- It states what holds now, never how it got there; history lives in version control.
- Each fact lives in one place; link to its owner rather than restating it.
- No volatile numbers (sizes, line counts, latency), and no counting a collection that can grow.
- Say what is, not what isn't. Plain words over metaphor such as spine, rail, seam, blast radius, theater or posture. Cut any sentence whose deletion loses nothing.
- A page takes the structure, depth and voice of the pages beside it.
- US spelling, unless the repo already uses another.

## Final pass

Check that the draft starts with the point, supports strong claims, removes repeated framing, and sounds like clear judgment rather than generated polish. Preserve the user's intent over stylistic performance.

## Red flags

- Changing the claim to make a sentence sound stronger
- Applying a stock voice to a medium or audience it does not fit
- Replacing precise language with a simpler but less accurate word
- Compressing prose until a reader must decode it
- Letting cleanup erase the writer's useful emphasis
- A lasting document that narrates its history, restates a fact another page owns, or carries a number that will go stale
