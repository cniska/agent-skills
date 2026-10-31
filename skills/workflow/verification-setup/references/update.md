# Update

A verification skill exists: edit it under its own name and prove its feature map against the current app.

When the skill falls short of anything [Create](create.md) steps 2 and 3 ask, whether a section, the feature map, a part of a feature file or what one of them requires, add what it lacks per Create, keeping its content in Create's shape, so a line restating behavior the spec states becomes the ID it restates, then prove it. Otherwise:

1. **Index hygiene.** Fix missing, duplicate, or dead entries in the feature map index.
2. **Source pass.** For each feature file, spawn one read-only agent on a **balanced-tier** model to read the source it describes and return drift with citations — renamed routes, removed commands, new sub-features, a cited spec ID the spec no longer holds or that now names a requirement the line does not rely on, a line restating behavior a spec ID states — and one live recipe. Readers never drive the app or edit files. Sweep recent changes for user-facing features the map lacks; require a concrete source path before calling one missing.
3. **Live pass**, required even when source looks clean. Drive every mapped feature in one session in a throwaway worktree, serially, following the skill's own Launch. Run Doctor before the first drive and after any failed one; a step that fails is a finding.
4. **Triage.** Wrong or missing description is drift: fix the map. Working behavior the harness cannot drive is a harness gap: fix it and re-drive it. Broken app behavior is a product defect: report it and leave product code alone. Edit only the verification skill's own directory and the harness it owns.
5. **Commit only proven corrections.** A defect in a feature the run could not drive stays as written and goes in the outcome, with the unmet prerequisite and the route attempted.
