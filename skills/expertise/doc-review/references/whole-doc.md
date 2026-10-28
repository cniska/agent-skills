# Whole-doc review

A diff review judges the lines a change reaches, so a doc whose structure was wrong before the change keeps its walls through every edit. This review takes one doc whole, asks what its reader comes to it for, and proposes the smallest restructure that answers those questions.

## Scope

One doc per run. Read the doc whole, the repo's doc map or index, and each doc it links to or that repeats its facts, since ownership decides what stays. The doc does not change during the review.

## Purpose

State in one sentence what the doc is for, from its first sentence and the doc map. List the questions its reader brings, such as how to install, what a command does, or which states a thing moves through. A section that answers none of them is a cut candidate; a question with no section of its own is a missing heading.

## Outline

List the doc's headings in order. Under each, name every subject the section holds and the form each takes: prose, list, table, code block or diagram, with the section's word count.

Mark from the outline:

- a section that holds more than one subject, or a subject spread over several sections
- a subject in the wrong form: prose that maps one set to another, a list of items with several attributes each, a chain of states and moves written as sentences, or a chart for what a list says
- each shape the diff review's checks name, wherever it sits in the doc, not only near a change
- each named shape from [the patterns](patterns.md)
- a fact another doc owns, history, and roadmap written as shipped

## Restructure

Propose the smallest restructure, in this order:

1. **Cuts.** Every sentence, section and chart that goes: a fact restated where a link to its owner will do, history, filler, a section no reader question needs.
2. **Headings.** The new outline, one heading per concern, in the order the reader needs them.
3. **Forms.** For each subject that changes form, the new form, written out: the table with its columns and rows, the list, or the split paragraphs.

The restructure keeps every fact the doc owns; a fact that moves names the doc it moves to. It never grows the doc, as the restructure that adds words pattern says.

## Report

Findings take the shape `principles` holds for a review report. A finding's **Where** is the section, its **Rule** the shape or named pattern it breaks, and its **Instead** that section restructured: the new headings, the table written out, or the rewritten text for a short section. Order the findings by the reader question they block, the most common question first.

Whoever ran the review carries out the restructure in one commit, which then takes the ordinary diff review.
