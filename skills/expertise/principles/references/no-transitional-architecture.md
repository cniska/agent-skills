# No transitional architecture

Land the replacement, migrate the consumers, and remove the old path. Never keep both alive: no compatibility shim, dual-read fallback or flag that keeps the old path running beside the new.

- Where a cut needs a migration, the migration is a step someone takes, not a shape the code keeps.
- A deprecation is finished when the old code is deleted, not when it is announced.
