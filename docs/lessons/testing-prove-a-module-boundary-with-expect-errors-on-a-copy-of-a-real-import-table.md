# Testing: Prove a module boundary with expect_errors on a copy of a real import table

**Date**: 2026-11-17
**Lesson**: A boundary held by the module graph is tested by compiling a one-line file in a module whose import table is a COPY of a real module's (`module.import_table = like.import_table.clone(arena)`), with `Step.Compile.expect_errors = .{ .contains = "<the compiler's message>" }`: the step passes only when the compiler refuses the line. Each case costs about half a second and 230 MB (it analyses only the line), and it fails - red - the day someone gives the real module the forbidden import back.

**Why**: A configure-time walk of the module graph says which edges exist; it does not show that the compiler refuses what the walk forbids, and a hand-built fixture module with a made-up table tests nothing about the real one. A copy of the real table, taken after build() has added its last import, is the real module's view minus its own files.

**What Happened**: Lane impls9 (check-impls-boundary) first wrote the cases where the lint step is wired, early in build(); they would have copied the tables before later `addImport` calls and tested a smaller module. They moved to the end of build(), beside the walk. Red at the commit before the cut: all eight cases compiled ("should contain ... but not found" with an empty error list); green after it. The messages, from a probe on the pinned Zig 0.17: "no module named 'impls' available within module 'root'" (a compile step's root module is named `root`), "'impl' is not marked 'pub'", "file exists in modules 'Node' and 'Attr'", "import of file outside module path". `contains` matches a line's END, so the expected text is the message's tail, module name included.

**Fix**: `addImplsBoundaryCase` in build.zig: `b.addWriteFiles()` for the one-line source (no file in the tree, so no lint sees an `@import("impls")`), `b.addObject` with `expect_errors`, the step a dependency of `test`. Walk and cases read no file: the configure cache is untouched.

**Takeaway**: **Pin a module boundary with expect_errors cases built from copies of the real modules' final import tables, and record the compiler's exact message from a probe first.**
