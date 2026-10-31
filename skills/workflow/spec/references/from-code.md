# A spec from code

Drafting from an existing codebase reverse-engineers the what from the how. The code says what the system does, never what its author intended.

- **State each requirement as observed behavior.** Flag each one you cannot confirm as deliberate, since a stopgap or a tuned default frozen as contract steers future work toward preserving it.
- **Mark the draft** as reverse-engineered and unverified against intent. Remove the mark once a reviewer accepts the spec and the acceptance suite proves every criterion.
- **Write an accepted requirement as settled where the owner signs off through review.** Where the owner has made a reviewer's accept their standing sign-off, that accept is their confirmation, so the spec carries no line saying a requirement awaits the owner's confirmation.
