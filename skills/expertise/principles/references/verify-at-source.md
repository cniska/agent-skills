# Verify at the source

Check each factual claim where it is defined, and cite that place.

A claim repeated from memory or a summary reads as checked, and text that ships, such as a prompt, a doc or an error message, carries its error to every reader.

- Cite code by a quote, heading or symbol, by `path:line` only in a review of a fixed diff or session, and outside the repo by a pinned revision or a dated URL.
- Delete a sentence that cannot be verified rather than rewording it.
- Back a quantifier such as `only`, `never` or `every` with an exhaustive sweep, or weaken it to what was checked.
- Read another agent's finding, or a memory note, at its source before acting on it or stating it, and report the rest as unverified.

Example: a doc says the command "only reads `config.toml`". A search of the source finds it reads `.env` too, so the sentence names both.
