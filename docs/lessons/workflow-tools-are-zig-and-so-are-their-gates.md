# Workflow: Tools are Zig, and so are their gates

**Date**: 2026-09-23
**Lesson**: The first version of that ratchet was a Python script meant to run inside `zig build test`.

**Why**: It was quick to write, and `tools/` already held Python - which is how the existing exceptions got there too.

**What Happened**: a Python gate adds an interpreter to the build of a Zig project, and it could not be tested the way this repo tests code. Its count-only rule also missed a swap (one reference traded for another at an equal total) - the case a `std.testing` test in the Zig port pinned first.

**Fix**: `tools/lint_impls_boundary.zig`, built for the host by `build.zig`, its rules pinned by `std.testing` tests that `zig build test` runs; the rule is written up under "Tools are Zig".

**Takeaway**: **Write the tool in the language the repo builds with, tests first. The existing WPT tools are the one sanctioned exception; any other .py file in `tools/` is debt, not precedent.**
