# Testing: A design's struct size is its tree's - take a size pin's base from a red run on yours

**Date**: 2026-11-10
**Lesson**: The byte counts in a design document were measured on the tree the design started from; a lane that starts elsewhere must read its pin's base from a red run of the pin on its own tree, and pin the delta, not the design's number.

**Why**: Node layouts move with every phase that lands. The node-data design (tmp/redesign/nodedata-design.md) counts every phase from the wrapper redesign's P4..P8 tree, where Node's state is 8 bytes smaller than on main. A lane told to start from MAIN that pins the design's numbers pins a size no tree has.

**What Happened**: Lane nd1 batch 1 (N8, CharacterData's data 48 -> 16 bytes) was briefed "Text.State 208 -> 176". The red run of the new pin on main b1bd4eae568 printed Text.State and Comment.State at 216 bytes - main still has the 8 bytes P4..P8 removes, and tests/dom/perf3e1_text_slottable_test.zig already pinned 216. The pin was written as 216 -> 184 (the same -32; arena block 224 -> 192) and the brief's figure reported as the design tree's.

**Fix**: Write the pin, run it red on the tree you start from, and read the printed layout before committing the number: the red run is the measurement. Grep the existing pins for the type (an older pin of the same State moves in the same commit as the change). Pin what your change does (here the data's own 16 bytes and the -32) beside the whole-block number, so a later merge of another lane's phase moves one pin, not the meaning.

**Takeaway**: **A size in a design is measured on the design's tree: take your pin's base from a red run on your own tree, and pin the delta your change makes.**
