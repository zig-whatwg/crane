# Workflow: Detached Builds Need an Explicit Environment

**Date**: 2026-10-29
**Lesson**: Pass the build environment into a detached session and verify it inside the script that runs the build.

**Why**: The launcher and a tmux session are different execution environments. Finding a command in the launcher does not prove the detached shell will find the same command or select the same cache.

**What Happened**: A dialog regression launcher failed before testing because it could not find tmux. After adding Homebrew to the launcher's PATH, the detached test ran but its failed-command line showed `./.zig-cache`, rather than the pool job's designated per-mirror cache. The fallback was inside the correct mirror, but the intended cache environment had not reached the detached build. Neither outcome was a product defect; the native failures were reported separately from these launcher issues.

**Fix**: Preflight tmux in the launcher. Pass PATH and ZIG_LOCAL_CACHE_DIR explicitly to its child command, and establish the authorized tool paths and per-mirror cache again inside the script before invoking Zig. Establish the working directory separately, as described in `workflow-anchor-tmux-job-cwd.md`. Record the selected executable and cache next to the build timestamps and source seals, then check that record and the actual build command before accepting the result. Preserve unsuccessful attempts rather than overwriting their evidence.

**Takeaway**: **Verify the executable and cache inside the detached build; the launcher's environment is not proof of the child's.**
