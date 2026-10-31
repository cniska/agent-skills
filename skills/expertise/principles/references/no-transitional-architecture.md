# No transitional architecture

Land the replacement, migrate its consumers, and remove the old path.

While both paths run, every later change has to keep both correct, and nothing forces the old one out.

- Remove any compatibility shim, dual-read fallback or flag that keeps the old path running beside the new.
- Make a migration a step someone runs, not a shape the code keeps.
- Count a deprecation finished when the old code is deleted, not when it is announced.

Example: a config file moves from JSON to TOML. The change converts existing files with a one-time command and deletes the JSON reader, rather than reading both.
