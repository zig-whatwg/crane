# Workflow: Verify Replayed Patch Bytes

**Date**: 2026-10-27
**Lesson**: Before withdrawing pending work, compare the replayed files with the saved source hashes; a successful patch command alone is insufficient.

**Why**: Git can filter patches by the current directory. Running `git apply --no-index` inside a scratch subdirectory of an existing worktree can skip repository-relative paths and still exit successfully.

**What Happened**: While preserving a pending CSSOM family, the scratch replay command returned success but left the scratch files unchanged. The required SHA256 comparison caught the mismatch before any source file was restored or new test moved. Repeating the check with `--verbose` explicitly printed `Skipped patch` for both paths. An adjacent shell command had prematurely appended a completion note after the failed assertion; that note was immediately corrected.

**Fix**: Preserve the exact diff and new files, populate scratch inputs from the intended HEAD, and apply using a command whose path semantics match that directory. In this case, `patch -p1 -F0 -d <scratch> -i <patch>` applied the saved diff. Compare every replayed output with its source hash. Restore or move the source files only after those checks pass, and append the completion record in the same success-dependent control flow.

**Takeaway**: **Exit zero is not proof that a patch changed its intended files. Verify the bytes before withdrawing work.**
