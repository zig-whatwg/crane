# Debugging: Materialize coordinates before overwriting a vector

**Date**: 2026-10-23
**Lesson**: Compute every new coordinate from saved scalar inputs before assigning an aggregate back to its input vector.

**Why**: Zig's aggregate result location can be the destination itself. Reading a component later in the initializer can therefore observe an earlier component write.

**What Happened**: The CSS contrast adapter converted LCH with `v = .{ v[0], v[1] * @cos(angle), v[1] * @sin(angle) }`. On Zig 0.16, the second coordinate overwrote chroma before the third coordinate read it. Infinite chroma at 90 and 200 degrees then selected the opposite contrast color from the browser majority. A scratch native diagnostic printed the expected standalone coordinates and the different result of the in-place conversion. The initial browser-derived regression table passed 42 of 44 cases.

**Fix**: Save chroma, calculate both Cartesian coordinates into scalar constants, then assign the completed coordinates to the vector. The unchanged 44-case contrast table passes, as do the 36 transfer-curve cases and 14 typed-color tests. Keep diagnostic printing in scratch files, outside production paths.

**Takeaway**: **Materialize dependent coordinates before assigning an aggregate into the storage they read.**

**Again (2026-11-12, lane editing5 b3)**: a struct, not a vector. insertHTML's caret walk climbed out of inline
elements with `point = .{ .node = parent_node, .offset = try common.indexOf(point.node) + 1 }`: the result location is
`point`, so `.node` was written first and `indexOf(point.node)` read the PARENT's index - the host's index in the body
(0) plus one. A paste at the end of `foo<b>bar</b>baz` went in after "foo". A native test whose host happened to be the
body's first child passed (`<b>abc[]</b>`: index 0 + 1 is right there); the clipboard test with three host children
caught it. Fix: `const index = try common.indexOf(point.node);` before the assignment.
