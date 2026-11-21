# Workflow: A compile check analyses only what a host calls - force a new operation in, and prove the check bites

**Date**: 2026-11-21
**Lesson**: `zig build crane-check` analyses only code reachable from crane's main, so a new engine protocol operation (or a new browser module) that no host calls yet is never compiled - the protocol's comptime conformance check reads each adapter function's TYPE, not its body.

**Why**: Zig compiles what is referenced. `engine_protocol.zig`'s `conforms` compares parameter and return types of each adapter function; the body is analysed only when something calls the operation. A lane that adds operations ahead of their caller (the CDP lanes in the "implement now, test later" phase of 2026-11-21, where another lane wires the caller) gets a green `crane-check` for code that may not compile at all.

**What Happened**: Lane cdpw added eight isolated-world operations and `src/browser/isolated_worlds.zig`; the first `crane-check` on server1 passed in about a minute. The world operations reached by existing paths (conversions, the wrapper cache, realm ends) were compiled; `createWorldRealm`, `worldRealmsOf`, `installWorldObserver` and the browser module were not referenced by anything yet.

**Fix**: For the milestone's compile check only, add a temporary function that calls every new operation and reference it from a container crane imports (`comptime { _ = &isolated_worlds.tmpWorldsCompileCheck; }` in src/browser/root.zig), run the check, then delete both before committing. Prove the check bites once: a deliberate type error in one of the forced functions must fail `crane-check` with its file and line (it did: `protocol_worlds.zig:292: expected type 'u32'`, "referenced by: ... tmpWorldsCompileCheck"). Read the verdict from `Build Summary` and the shell's `PIPESTATUS[0]`, not from a piped `tail`'s exit code.

**Takeaway**: **A green compile of code no one calls proves nothing: force every new operation into analysis for the check (and prove the check fails on a planted error), then remove the forcing before you commit - the tests that call it compile it for good.**
