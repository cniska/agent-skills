# Stack

Which language a program is written in, how a toolchain is pinned, and when a dependency earns its place.

## Language

- **Write a program in a language with a reference in the [skill's table](../SKILL.md#before-the-first-edit).** In a repo, use its own language first, or shell where the shell reference allows it. Any other language, or a runtime the repo does not have yet, is the owner's decision: report it rather than copying it from a precedent in the repo or elsewhere. A brief that asks for a tool in the shape of another copies its behavior, not its language.
- **Some files are not programs.** SQL follows `database-design`, a CI workflow follows [CI workflows](../SKILL.md#ci-workflows), config and data formats follow their own schema, and platform code a framework requires, such as a Flutter app's Android or iOS side, is in the language that platform asks for.
- **A runner can fix the language.** A plugin hook, a git hook, and a script a skill bundles that may assume no runtime are runner-fixed: the repo's own rules decide their language and size, and the shell reference's length limit and the rule keeping command-line programs out of shell do not apply.
- **A project holds this with a check** that refuses a tracked file whose shebang names an interpreter no reference language runs on, such as `perl` or `ruby`, or whose extension is a scripting language with no reference, such as `.pl`, `.rb`, `.php` or `.lua`. The shell reference names the check on shell's length beside it.

## Toolchain

The repo pins its toolchain in the way it has chosen. For a project that has not chosen, suggest `mise`, and install every runtime it can manage through it alone, rather than also through `brew`, `nvm`, `pyenv` or `fnm`. A toolchain `mise` cannot manage, such as the one Xcode ships, is pinned the way the project chose, with the committed file its language reference suggests as the default, and checked against the installed version before a build.

## Dependencies

Every dependency is supply-chain surface. Before adding one, check whether the standard library or a dependency already in the tree covers the job, and say why next to a heavier one when it earns its place. A test-only dependency is a dev dependency.
