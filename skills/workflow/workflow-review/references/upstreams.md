# Upstreams

Upstreams bring ideas; the session record brings the evidence. An upstream change earns a proposal only when the evidence already asks for it.

## The list

The upstream list the brief names: an array, one entry per upstream.

- `repo`: `owner/name` on GitHub.
- `for`: optional; `owner/name` of the repo the upstream's ideas are for, whose sessions and ledger gaps its changes are weighed against, in scope for that evidence even when the brief does not name it, and where a proposal from it lands. Absent means the repo the review is for.
- `path`: optional; the read takes only changes under it. The session-start count ignores it, so an upstream can count as moved with nothing to read.
- `only`: optional; `new-skills` limits the read to skills the upstream added.
- `taken`: what the owner took from it.
- `reviewed`: the last commit reviewed.

## Read

1. **Take every entry in list order**, whatever its `for`.
2. **Read only what changed** between `reviewed` and the remote's head, under `path` and within `only`: new or changed skills, hooks, agents and checks, or for an entry with `for`, changes to what that repo does. Skip formatting, renames and churn.
3. **Note the head read up to** for each entry, even when nothing clears the bar.

## The bar

| Change | Outcome |
|---|---|
| Answers friction two independent sessions show, by the two-session rule | Proposal, citing the sessions and the upstream commit |
| Closes a gap the ledger names | Proposal, citing the ledger line and the upstream commit |
| Touches a decision the owner settled | Conflict, naming the decision |
| Anything else | Listed in one line and dropped |

A proposal from an upstream takes the same shape as any other. The upstream commit is the idea, never the evidence.

## Report

An `Upstreams` heading after the one-offs: each entry's dropped changes, one line each, and the head read up to. The list advances to those heads in the commit that lands the report, so the next run starts there.
