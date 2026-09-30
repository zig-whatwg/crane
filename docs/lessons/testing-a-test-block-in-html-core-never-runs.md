# Testing: A test block in html_core never runs

**Date**: 2026-09-30
**Lesson**: `zig test` collects test blocks from the root module's files only. `zig build test` roots no test binary at html_core (`src/html/root.zig`), so every `test` block in `src/html/**` - navigation's fetch integration, the joint history, the parser modules - is compiled by nobody and passes by never running.

**Why**: build.zig roots the HTML tests at `html_mod` (`src/html/full.zig`), which imports html_core as a separate module, and says so in the comment above the step: "a dep module's tests do not run (verified)". The rest of html_core's tests live in `tests/html/`, which `addTestFilesFromDir` roots one binary per file.

**What Happened**: The navigation lane added `test` blocks to `src/html/navigation/fetch_integration.zig` (the redirect-origin flag, a request's referrer) and nearly counted them as the red-then-green evidence the brief asked for. They would have been green with any implementation.

**Fix**: The tests moved to `tests/html/navigation/fetch_integration_test.zig`, reaching the module through `@import("html_core").navigation.fetch_integration`; `InternalResponse` is re-exported there for the test's responses, since `tests/html` does not import `fetch`.

**Takeaway**: **A test in `src/html/**` does not run: put html_core tests under `tests/html/`, and prove a new test is live by seeing it fail once.**
