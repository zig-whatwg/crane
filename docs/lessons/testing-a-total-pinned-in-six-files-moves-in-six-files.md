# Testing: A total pinned in six files moves in six files

**Date**: 2026-11-10
**Lesson**: Each node-memory batch pinned the div's whole State block (and the Text's) in its own test file, so a 16-byte change to one level - EventTarget's - had to edit eleven pins in ten files: two of the level itself and nine totals (the div's block in six files, the Text's and the Comment's in two), two of them in the test files of a lane running beside it.

**Why**: A size pin is the right red test for a layout change, and each batch wrote its own ("a div's one block is N bytes: ... less my M"). The total is a sum over every level, so every later change to any level breaks every one of those pins at once. With three node-memory lanes in flight (nd2 on Element's attribute fields, rare1 on ElementRareData, lis1 on EventTarget), each lane's branch rewrote the same lines, and the integrator merges conflicting numbers whose right value is the sum of all three changes.

**What Happened**: Lane lis1 took EventTarget's embedded state from 24 to 8 bytes. The div's block went 264 -> 248 and the Text's and Comment's 184 -> 168; the red run failed eleven tests, in tests/dom/{perf2b6_node_layout, perf2b7_node_copies, perf3d1_element_data, perf3d2_element_rare_data, perf3e1_element_registry, perf3e1_slottable, perf3e1_text_slottable, nd1_text_data_layout, nd2_element_name, nd2_id_class_index}_test.zig.

**Fix**:
1. A batch pins the level it changed (`Embedded(interfaces.EventTarget.State)` is 8) and the size class the total lands in, where the class is the point.
2. The whole block's byte count is pinned in ONE place (a single "node block sizes" test) that every layout batch edits, with its history in that test's comment.
3. When lanes change different levels at once, say in the merge report which totals each moved by how much, so the integrator writes the sum.

**Takeaway**: **Pin the level you changed; pin a total in one place only - a sum pinned in every batch's file breaks in all of them at once.**

**Status (2026-11-14, lane nm1)**: The one place for a div's total existed (tests/dom/node_block_sizes_test.zig), but the parts were still pinned many times: NodeBase's 80 in four files, Element's embedded 40 in seven, Node's embedded 120 in two, a Text's 160 in two. Lane nm1's layout batch moved all four and found the copies in three rounds of the full native step, not one. node_block_sizes_test.zig now pins the parts too (NodeBase, Node's and Element's embedded states, a Text's and a Comment's block); every other file keeps the FACT it tests (a field is gone, a field's type) and its history as a comment. Before a layout batch: `grep -rnE 'expectSize\(|@sizeOf\(' tests | grep -E '<the types you change>'` and move every hit first.
