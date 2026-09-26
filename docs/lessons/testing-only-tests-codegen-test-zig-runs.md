# Testing: Only `tests/codegen/*_test.zig` runs

**Date**: 2026-09-23
**Lesson**: `addTestFilesFromDir` collects files ending in `_test.zig`. The 28
test blocks inside `src/webidl/codegen/writer.zig` and all of
`tests/codegen/codegen_integration.zig` have never run - the latter could not
even compile, since it imports `codegen/root.zig` by a path that does not
exist from there.

**Fix**: put codegen tests in `tests/codegen/<topic>_test.zig` and
`@import("codegen")`. `zig build test -Dspec=codegen` runs them, with the
lint, in about a minute.

**Takeaway**: **A red test you have never seen go red is not a test.** Run a
new one against the unfixed code first - that is what shows it is collected.
