# Chesterton's Fence

Before removing or changing something, find out why it exists: read its history (`git blame`, `git log -S`), its callers, its tests and the repo's recorded decisions.

- When the reason still holds, such as a hot path or a contract another system depends on, leave it, and that ends the matter.
- When the reason no longer holds, it goes, and the change says what the reason was.
- When no reason can be found after that search, say what was checked; an unknown reason is not permission to keep it forever, nor to remove it blind.
