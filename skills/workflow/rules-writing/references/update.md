# Update

`AGENTS.md` exists and you're adding a rule or change. This is a merge, not an append.

Often no specific rule comes with the request — "bring this file up to standard" on a file that has drifted. Then the skill's conventions are themselves the incoming rules: audit the whole file against them, and verify each existing bullet still matches the code before keeping it. A file can be duplication-free and still assert things that stopped being true. Steps 2–3 apply per rule you land; the rest apply to the pass as a whole.

1. Read the whole file first — you can't dedupe what you haven't read.
2. Find the section the rule belongs in, or for a rule no section fits, one from the menu in [create](create.md). Match the file's existing vocabulary and structure — unless that vocabulary is factually wrong or tool-specific, which you fix rather than preserve.
3. **Merge, don't append:**
   - if an existing bullet overlaps, rewrite that one bullet to cover both — don't add a second.
   - if the rule generalizes several existing bullets, replace them with the one general rule.
   - if the same rule is stated in two sections, dedupe to the single correct home.
4. Trim collateral duplication the change exposes, and apply no drift from `principles` to what it made stale, even outside the target section.
5. Re-check the file still follows every convention in the skill (no hard wraps, one rule per bullet), and that a bridge exists for each agent tool the repo uses.
6. Report **added / merged / trimmed** explicitly — which bullets changed and why.
