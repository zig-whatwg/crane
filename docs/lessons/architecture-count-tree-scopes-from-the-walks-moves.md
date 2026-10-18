# Architecture: Count tree scopes from the walk's moves, and prove the count against the literal steps

**Date**: 2026-10-18
**Lesson**: DOM's event path asks, for every parent, whether "target's root is a shadow-including inclusive ancestor of parent". A Crane node has no tree-scope pointer, so that answer costs a root walk per step. Count the moves "get the parent" makes instead, and prove the count with a differential test against a literal implementation of the steps.

**Why**: Blink and WebKit answer every tree-scope question from a TreeScope pointer on each node (EventPath::CalculatePath and CalculateAdjustedTargets; EventPath::buildPath). Crane finds a root by walking parent links. Step 6.9.6 asks its question once per parent and retargeting asks once per item, so taken literally the hottest path in the engine would walk to the root at every node.

**What Happened**: Lane events1 rewrote dispatch across shadow roots (before it, a shadow root had no "get the parent" and every path stopped there). "Get the parent" moves in only three ways:
- (a) a node to its parent, in the same tree;
- (b) an assigned slottable to its slot, one tree deeper;
- (c) a shadow root to its host, back to the tree the walk entered from.

Let `depth` count (b) moves minus (c) moves since dispatch's `target` was last set. Then:
- step 6.9.6 is false exactly on a (c) move at depth 0;
- an item at depth > 0 is in a shadow tree;
- the depth-0 tree's kind is known when the walk reaches its root, and is then filled in for that tree's items;
- retargeting depends only on the parent's root, so it is needed only on (b), (c) and the Window.

This is an argument. The integrator asked for a proof: tests/dom/ev1_event_path_differential_test.zig builds 2,500 random trees and runs 12 random dispatches on each, comparing every item against the steps as written, one root walk per question. The trees mix nested shadow roots, open and closed, named and manual slots, slotted text and a detached tree; the dispatches vary relatedTarget, composed, "load" and activation.

**Fix**: src/dom/event_path.zig (THE WALK in its header). A path with no shadow tree now costs one instance-bridge lookup and pointer walks, where it cost three bridge lookups per node.

**Takeaway**: **When the engine lacks a per-node pointer the algorithm keeps asking about, derive the answer from the walk's own moves - and make a randomized differential test against the literal steps the proof, not the argument.**
