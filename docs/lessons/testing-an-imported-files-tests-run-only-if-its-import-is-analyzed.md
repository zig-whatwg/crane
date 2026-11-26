# Testing: An imported file's tests run only if its import is analyzed

**Date**: 2026-11-24
**Lesson**: Zig collects a file's test blocks only when something in the test executable's root module analyzes that file's import - so neither "the module is a test root" nor "the root reaches the file by relative import" proves a test runs; the executable's own test list does.

**Why**: A file's test declarations are registered when its namespace is scanned, which happens when an `@import` of it is semantically analyzed. A `pub const x = @import("x.zig")` in a sub-root nobody references is never analyzed, so x.zig's tests are dropped silently, even though the file is in a rooted module (the earlier lesson, [a test block in a module no step roots never runs](testing-a-test-block-in-a-module-no-step-roots-never-runs.md), is the module-level half of this).

**What Happened**: Lane core1 surveyed src/ for dead inline tests by walking every module root's relative imports. The walk found 742 test blocks in 182 files of modules no step rooted. Cross-checked against the launcher's real test lists, it also found 20 tests in 13 files of rooted modules (src-html's execcommand and web_locks, src-dom's style files, src-intl's cldr/types.zig, src-devtools' mcp tools) that the import walk said were reached but that never ran: their sub-roots were not referenced from any test block. Once wired, the never-run tests found real bugs: a mimesniff tag-terminating-byte bug that sniffed `<!DOCTYPE html>` as text/plain, a double free on four error paths of the structured-clone deserializer, leaks in the transfer walker, a union tag mismatch for resizable buffers, clock-seeded WebDriver session ids, and a test that did not compile. A first version of the ratchet also sorted a map's keys without its values, which paired every count with another file: its own test now pins that.

**Fix**:
1. To know which tests run, read the test executable, not the imports: `test_launcher <exe> --list`, or `zig build check-src-tests` for all of src/ (tools/src_test_reach.zig).
2. A sub-root that holds tested files names them in a test block (`test { _ = common; _ = whitespace; }`); `refAllDecls` only where the whole namespace may be analyzed (an engine-free executable must not reach the adapter's externs).
3. Triage before wiring: most never-run tests had rotted, asserted stale facts or duplicated WPT. Keep what pins something nothing else does, and delete the rest with the covering test named.

**Takeaway**: **A test runs only if the executable lists it. Check the list, and let `check-src-tests` keep it so.**
