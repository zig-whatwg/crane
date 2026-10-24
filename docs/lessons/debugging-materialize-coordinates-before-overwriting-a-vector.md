# Debugging: Materialize coordinates before overwriting a vector

**Date**: 2026-10-23
**Lesson**: Compute every new coordinate from saved scalar inputs before assigning an aggregate back to its input vector.

**Why**: Zig's aggregate result location can be the destination itself. Reading a component later in the initializer can therefore observe an earlier component write.

**What Happened**: The CSS contrast adapter converted LCH with `v = .{ v[0], v[1] * @cos(angle), v[1] * @sin(angle) }`. On Zig 0.16, the second coordinate overwrote chroma before the third coordinate read it. Infinite chroma at 90 and 200 degrees then selected the opposite contrast color from the browser majority. A scratch native diagnostic printed the expected standalone coordinates and the different result of the in-place conversion. The initial browser-derived regression table passed 42 of 44 cases.

**Fix**: Save chroma, calculate both Cartesian coordinates into scalar constants, then assign the completed coordinates to the vector. The unchanged 44-case contrast table passes, as do the 36 transfer-curve cases and 14 typed-color tests. Keep diagnostic printing in scratch files, outside production paths.

**Takeaway**: **Materialize dependent coordinates before assigning an aggregate into the storage they read.**
