# Program design

Load this when a planned change reaches past one file. Make its shape concrete before handing off, since a decision on the table is cheaper to change now than at review.

- **File-tree diff:** each file added, changed or deleted, with one line of intent. For an edit to one or two files, a sentence does better than a block.
- **Key signatures:** the new or changed function and type signatures the slice introduces.
- **Call path:** the path from the entry point to the leaf through those signatures.

Put the shape in the plan, where the owner reads it with the rest. When drawing it surfaces a decision, settle that decision with the owner before the plan is done.
