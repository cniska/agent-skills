# Doc patterns

Named shapes a doc falls into and the shape it should take instead. A diff review cites one by name as the **Rule** of a finding; a whole-doc review uses them to build the restructure. Each pair keeps every fact: only the form changes.

## A lifecycle in one paragraph

A paragraph names the states a thing can be in, the calls that move it between them, and the caveats of each move, chained with semicolons. A reader looking for one transition reads all of them.

Before:

> `Connection` holds its state as `connecting`, `open` or `closed`, starting in `connecting`; `open()` succeeds into `open` unless the handshake times out, which moves it to `closed`, and `close()` from `connecting` or `open` moves it to `closed`, dropping queued sends; `send` works only in `open` and queues while `connecting`, and a closed connection is never reopened.

After:

> `Connection` holds its state as `connecting`, `open` or `closed`. It starts in `connecting` and is never reopened once `closed`.
>
> ### States
>
> | From | Action | To |
> |---|---|---|
> | `connecting` | `open()`, handshake completes | `open` |
> | `connecting` | `open()`, handshake times out | `closed` |
> | `connecting`, `open` | `close()` | `closed` |
>
> ### Sending
>
> `send` works only in `open` and queues while `connecting`. `close()` drops the queue.

The move: a heading per concern, a From / Action / To table for the transitions, and each caveat as a sentence under the concern it belongs to. A start-state table joins the transitions when the start depends on input.

## A subject with no heading

A README or doc runs install, use, configuration and internals together under one heading, or none. The reader scans for the heading of the subject they came for and finds none.

The move: one heading per subject the reader looks for, in the order a new reader needs them. A section that answers two questions becomes two sections.

## A table with a row of another kind

A table lists one kind of thing, such as gates, commands or options, and one row holds something else: a general rule, a caveat, or a note that fits no column, so its cells run to sentences.

The move: the table keeps only rows of its kind. The odd row becomes a sentence under the table, or its own section.

## Alternatives in one code block

Several ways to do one thing, such as install channels, sit in one fenced block. Copying the block runs all of them.

Before:

````
```sh
brew install tool
npm install -g tool
cargo install tool
```
````

After: a short label per channel, each with its own block holding its one command.

## A README that carries the reference

The README holds every flag, config key and design note, so it runs long and its overview drowns.

The move: each subject the repo's doc map gives another doc moves there, and the README links to it. Where the repo has no map, or its map gives the README everything, the finding asks the owner where the deeper subjects belong rather than choosing the split.

## A diagram that does not earn its place

A chart repeats what a short list says, or answers several questions at once, so reading it takes longer than reading the prose beside it.

The move: cut the chart to one question and a handful of nodes, or delete it and keep the list or table.

## Long bullets

A whole list of bullets runs longer than about two lines each, so the list no longer scans.

The move: each long bullet becomes a paragraph or a subsection of its own, and the list keeps only the short ones.

## History in a doc

The doc says what something used to do, when it changed, or why an older approach was dropped: "was renamed", "previously", "no longer", "since the move to".

The move: state what holds now and delete the rest. Version control keeps the history.

## A restructure that adds words

A rewrite meant to make a doc readable adds headings, tables and also new sentences: an introduction to each section, a restated summary, a caveat repeated under two headings.

The move: each fact appears once after the restructure. Count the words before and after; a restructure that grows the doc beyond its headings and table scaffolding is wrong at the place it grew.
