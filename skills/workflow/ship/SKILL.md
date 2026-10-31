---
name: ship
description: Run pre-release checks, choose the version bump, cut the release, and verify it reached every channel. Use when a new version is ready to tag and publish, or once its tag is pushed.
---

# Ship

Run a structured pre-release gate, determine the version bump from the commits, cut the release, and once the tag is pushed verify that it reached every channel. This is a release gate over the whole project, not a diff review — review already happened.

The skill orchestrates and gates; the release mechanics belong to the project. Read `AGENTS.md` for the verify and release commands, and defer to them — the release entry point (a script or CI workflow) owns the version bump, changelog, tag, and any project-specific pre-release gates. The release shape varies by ecosystem — tag-and-bump, or build-and-publish a checksummed artifact — and this skill assumes none. Where the project has no release entry point, take the manual path in the workflow.

## Scope

Check the entire project against the preconditions below. Never push; the last human step is pushing the tag.

## Workflow

1. **Verify preconditions** (all must pass to proceed):
   - on the release branch (`main` unless the project says otherwise)
   - working directory is clean
   - commits exist since the last release tag — a tag over no new commits releases nothing
   - the project's verification passes (its verify command per `AGENTS.md`), and where the project has a spec, that command runs the spec check and it passes over a complete acceptance suite: no criterion left a todo or a skipped test
   - user-facing docs, and `SPEC.md` where the project has one, reflect the user-visible features since the last tag — cross-reference `feat` subjects and run `doc-review` over them; any drift it finds fails this check
   - no secrets in tracked files — grep tracked, non-`.env` files for common key shapes (`sk-`, `Bearer `, `-----BEGIN`, provider API-key env names)
2. **Run quality checks** (warn, don't block):
   - no `TODO` / `FIXME` left in non-test source
3. **Determine the version bump** from commits since the last tag (SemVer + Conventional Commits). With no `v*` tag yet, this is the first release: the version is the one the project records, or its release entry point chooses, no bump is computed, and the output reads `none → <version>`.
   - previous tag: `git describe --tags --abbrev=0 --match 'v[0-9]*'`
   - commits: `git log <prev_tag>..HEAD --oneline --no-merges`
   - **major** — any commit has `BREAKING CHANGE` in the body or `!` before the colon in the subject; before 1.0, such a commit bumps **minor** instead
   - **minor** — any commit subject is `feat(...)` or `feat:`
   - **patch** — everything else
4. **Report** using the output format below, then **ask for confirmation**.
5. **Cut the release**: if the project has a release entry point, run it with the chosen level, or the first-release version; otherwise take the manual path — record the version where the project keeps it, write the changelog entry, and create the commit and annotated tag `v<version>`.
6. **Print the push commands** and stop. Do not push.
7. **Verify the release** when the owner says the tag is pushed, or when `ship` runs again against a pushed tag, which skips steps 1-6. Wait for each release run the tag started, where it starts one, to finish, then check that each passed and that every channel serves the new version: each publish target of the release entry point where there is one, such as a package registry or a download page, and each channel the project's `AGENTS.md` lists. This run reports only the Release and Verdict sections.

## Output format

### Preconditions
- pass / fail per check, with failure detail

### Quality
- pass / warn per check

### Commits
- one-line list since the last tag

### Version
- previous → proposed (`<level>` — reason)

### Release (step 7)
- pass / fail for each release run the tag started and for each channel, with the version each channel serves

### Verdict
- **Ship it** — preconditions pass, no warnings
- **Ship with caution** — preconditions pass, warnings present
- **Fix first** — a precondition fails
- **Released** — after step 7: every release run the tag started passed, and every channel serves the new version
- **Release incomplete** — after step 7: each run that failed and each channel that does not serve the new version

## See also

- `agents-md` — where the project's verify and release commands, and the channels a release publishes to, are declared
- `review` — the quality gate that runs before ship; ship assumes it passed
- `git` — commit conventions the version bump reads from
- `doc-review` — drift in user-facing docs and the spec before the tag
- `spec` — the acceptance suite and the check a release waits on
