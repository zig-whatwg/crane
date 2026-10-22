# Testing: Zig warning steps print failed-command footers

**Date**: 2026-10-20
**Lesson**: A `failed command:` footer alone does not establish that a Zig 0.16 build step failed.

**Why**: Zig's build runner calls `printErrorMessages` whenever a step has stderr, regardless of its result. That function prints `result_failed_command` when present. `printStepFailure` labels a step with only stderr as `w`.

**What Happened**: Crane's codegen tests printed expected rejected-input diagnostics, and fetch tests printed socket warnings. Both appeared with a `failed command:` footer and a `w` label, without a failed-test diagnostic. Treating the footer as a test result would have prompted unnecessary reruns.

**Fix**: Inspect the final `Build Summary` and named failed or terminated test entries. Read the pinned Zig's `lib/compiler/build_runner.zig`, particularly `makeStep`, `printStepFailure`, and `printErrorMessages`, when the footer and summary appear inconsistent. Preserve piped logs so warning output and actual results remain available.

**Takeaway**: **Use the build summary and named test diagnostics to determine success; a command footer is context, not a result.**
