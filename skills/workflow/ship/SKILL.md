---
name: ship
description: Run pre-release checks, choose the version bump, cut the release, and verify it reached every channel. Use when a new version is ready to tag and publish, or once its tag is pushed.
---

# Ship

Gate a release over the whole project, choose the version bump from the commits, cut the release, and once the tag is pushed verify that it reached every channel. Review has already judged each change, so this gate judges the project as it stands.

The project owns the release mechanics. Its `AGENTS.md` names the verify and release commands. Its release entry point, a script or a CI workflow, owns the version bump, the changelog, the tag and any pre-release gates of its own, so run it and follow what it reports. Releases take different shapes, such as a tagged version bump or a checksummed artifact built and published, and this skill assumes none. Where the project has no release entry point, take the manual path in step 5.

The owner pushes the tag. Each run ends at the push commands or at the verdict on a pushed tag.

## Workflow

1. **Verify the preconditions.** Each must pass to proceed:
   - on the release branch, `main` unless the project says otherwise
   - a clean working tree
   - commits since the last release tag, since a tag over no new commits releases nothing
   - the project's verification passes, and where the project has a spec, that verification runs the spec check over a complete acceptance suite, with every criterion tested and none left a todo or skipped
   - the user-facing docs, and `SPEC.md` where the project has one, reflect each user-visible feature since the last tag: cross-reference the `feat` subjects and run `doc-review` over those docs, and any drift it finds fails this check
   - tracked files outside `.env` hold no secrets in common key shapes, such as `sk-`, `Bearer `, `-----BEGIN` and provider API-key variable names
2. **Run the quality checks**, which warn without blocking: a `TODO` or `FIXME` in non-test source.
3. **Choose the version bump** from the commits since the last `v*` tag, by SemVer and Conventional Commits:
   - **major**: any commit has `BREAKING CHANGE` in its body or `!` before the colon in its subject. Before 1.0, such a commit bumps **minor** instead.
   - **minor**: any commit subject is `feat(...)` or `feat:`.
   - **patch**: everything else.

   With no `v*` tag yet, this is the first release. Its version is the one the project records or its release entry point chooses, no bump is computed, and the report reads `none → <version>`.
4. **Report** in the format below, then ask the owner to confirm.
5. **Cut the release.** Run the release entry point with the chosen level, or with the first-release version. Without one, record the version where the project keeps it, write the changelog entry, and create the commit and the annotated tag `v<version>`.
6. **Print the push commands** and stop there for the owner to push.
7. **Verify the release** when the owner says the tag is pushed, or when `ship` runs again against a pushed tag, which skips steps 1 to 6. Wait for each release run the tag started to finish, then check that each passed and that every channel serves the new version: each publish target of the release entry point, such as a package registry or a download page, and each channel the project's `AGENTS.md` lists. This run reports only the Release and Verdict sections.

## Output format

### Preconditions
- pass or fail per check, with the failure's detail

### Quality
- pass or warn per check

### Commits
- a one-line list of the commits since the last tag

### Version
- previous → proposed (`<level>`, with the reason)

### Release (step 7)
- pass or fail for each release run the tag started and for each channel, with the version each channel serves

### Verdict
- **Ship it**: the preconditions pass, with no warnings
- **Ship with caution**: the preconditions pass, with warnings
- **Fix first**: a precondition fails
- **Released**, after step 7: every release run the tag started passed, and every channel serves the new version
- **Release incomplete**, after step 7: each run that failed and each channel that does not serve the new version
