# Spec Compliance: A decomposition must recompose to its own matrix

**Date**: 2026-11-07
**Lesson**: Before trusting a decompose/interpolate/recompose pipeline, test that decomposing a matrix and recomposing it at p = 0 gives the same matrix - the pseudo-code in CSS Transforms 1 11.2 and Transforms 2 13.1 is not internally consistent if read literally.

**Why**: Transforms 2 13.1.3 lists `rotationMatrix[0][1] = 2 * (x * y - z * w)` in the same `[column][row]` notation the rest of the section uses, but that is the transpose of the rotation 13.1.1's quaternion came from: a rotation about z by θ decomposes to q.z = +sin(θ/2) and recomposes to -sin θ where the matrix had +sin θ. Chromium's ComposeTransform builds the same matrix with `set_rc(row, column)`, the reading that round-trips. The 2D recomposition (Transforms 1 11.2.3) likewise multiplies the translation by the 2x2 residual, which Gecko (MatrixDecomposed2D sets m41/m42 directly) and Chrome do not, and which WPT's matrix(1, 0.36, 0, 1, 200, 200) cases reject.

**What Happened**: Lane anim1 batch 4 implemented transform list interpolation from the spec text. The first animation-wide probe gained 8,732 subtests but lost 159; among them `rotate3d(1, 1, 0, 90deg)` at p = 0 came back with m13's sign flipped, and the 2D matrix cases came back with a translation of (240.79, 207.12) instead of (200, 200) - at p = 0, where every value must equal V_A.

**Fix**: Read the rotation listing as (row, column) and keep the 2D translation as decomposed, each with a comment naming the engine and the WPT file that pin it; check decompose∘recompose at p = 0 in a native test for a 3D rotation, a skewed 2D matrix and a perspective.

**Takeaway**: **When a spec gives a decomposition and a recomposition, test their composition at p = 0 before testing interpolation: the endpoints must come back exactly, and the engines' code is where the transposes are already fixed.**
