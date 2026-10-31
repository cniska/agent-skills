# Chesterton's Fence

Find out why something exists before you remove or change it.

Something that looks pointless often guards a case its author met and you have not, such as a hot path or a contract another system depends on. Removing it brings that case back.

- Read its history, its callers, its tests and the repo's recorded decisions.
- When the reason still holds, leave it.
- When the reason no longer holds, remove it, and say in the change what the reason was.
- When no reason turns up, say what was checked, then keep or remove it on what the change needs; an unknown reason alone justifies neither.

Example: a retry around a file read looks redundant. Its history shows it was added for a network drive that returns stale reads, which the project still supports, so it stays.
