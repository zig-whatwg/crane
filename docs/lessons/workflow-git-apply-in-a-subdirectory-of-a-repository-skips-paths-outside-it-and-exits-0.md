# Workflow: `git apply` run in a subdirectory of a repository skips every path outside that directory, and exits 0

**Date**: 2026-11-15
**Lesson**: A scratch copy of a few source files under the checkout's `tmp/` is still inside the repository. `git apply <patch>` run there applies only the patch's paths that fall under the current directory - for a patch written against the repository root, none - prints nothing and succeeds.

**Why**: Inside a work tree `git apply` resolves the patch's paths against the repository root and, by design, ignores the ones outside the directory it was started in (git-apply(1): "when running from a subdirectory in a repository, patched paths outside the directory are ignored"). A pool mirror is not a repository, so the same command applies everything there: the scripts that build diagnosis consoles (`git apply "$PATCH"` in the mirror) are right, and the same line tried by hand in `tmp/scratch/<lane>/copy/` on the Mac does nothing.

**What Happened**: Lane dm3 needed one patch that was "lane wrap1's limit-trace patch plus one more hunk" for a diagnosis console. It copied the four files the trace patch touches into `tmp/scratch/dm3/rcpatch/a` and `b`, ran `git apply` of the trace patch in `b`, edited `b`, and diffed. The diff held 2 hunks where 8 were expected: the trace patch had never been applied to `b`, the result was only the extra hunk, and a console built from it would have printed no trace - found by counting `^@@` in the result and `DIAGNOSIS ONLY` markers (3 where 11 were due), not by any error. A second try with `patch -p1` then failed loudly on the one hunk that overlapped, which is the behaviour wanted.

**Fix**:
1. In a scratch tree under the checkout use `patch -p1 < file.patch` (it knows nothing of the repository), or `git apply --unsafe-paths --directory=<dir>` from the root; or make the scratch tree outside any repository.
2. Count what a patch step produced before using it: `grep -c '^@@'` of the result against the sum of its inputs, or one marker string per hunk.
3. `git apply --check` succeeding says nothing here either: the skipped paths pass the check.

**Takeaway**: **Under a checkout, `git apply` silently means "apply what is below this directory". Use `patch -p1` in scratch copies, and count hunks before trusting a combined patch.**
