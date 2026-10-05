# API rules

Load these when the scope defines an interface other code or a user calls: a public module surface, a CLI command, a tool, an endpoint or a schema.

## One operation, one API

An operation has one entry point. Splitting one operation across several calls that must be used together confuses every caller.

Spot it:

- two calls that are always made as a pair
- the same operation reachable two ways

## No mode flags

A function, command or tool that behaves in two ways is split in two, or takes an explicit field that names the case. A boolean parameter that switches behavior is a smell.

Spot it:

- a boolean argument that changes what the call does
- a parameter whose presence changes the behavior

## A thing is what it says it is

A name promises a behavior, and the behavior keeps the promise. A tool that is not really a tool, or a command that does something besides its name, is renamed or redesigned.

Spot it:

- a name that describes only part of what the code does
- a concept used as something it is not

## A contract serves its caller, not its engine

An interface's inputs follow what its caller is doing, not what the implementation can do. Two surfaces that share an engine, such as a search and an edit over one parser, keep separate contracts.

Spot it:

- one input schema serving two operations with different intent because they share code

## A partial result says so

A result is whole, or it says what it left out. A capped list reports the full count or marks its count as a lower bound, and an input too large to answer whole is refused with an error naming its size. A missing input to a ranking or filter fails the call rather than answering from what remains, and a filter naming an unknown value is refused rather than matching nothing.

Spot it:

- a truncated list or read with no mark of what it withheld
- a ranking computed after one of its inputs failed

## Each output stream has one job

A command's stdout carries only what it was asked to produce; errors, warnings and notices go to stderr. A machine-readable mode writes only parseable records, and an empty result is an empty stream. Styling appears only when the destination is a terminal.

Spot it:

- a notice or banner before JSON output
- an error written to stdout
- escape codes in piped output

## A small surface

Export only what callers need. Options come as one typed object, not a long list of positional parameters. The surface grows only when a caller needs more.

Spot it:

- exports with no caller outside the module
- more than three positional parameters
