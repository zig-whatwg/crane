# Workflow: A queued crane-remote job syncs the worktree when it is placed, not when it is queued

**Date**: 2026-11-18
**Lesson**: `crane-remote.sh` copies the worktree to the mirror when the job gets a build slot; a job that waits in the queue builds whatever the worktree holds at that moment, so keep every edit made while it waits complete and compilable - or use the wait to land more work in the same build.

**Why**: With every pool host closed or full, a lane's first build waited 32 minutes for a chat2 slot. The job line ("queued") is printed at launch, but the sync - and with it the tree the build sees - happens only at placement ("placed on ... waited 1937s").

**What Happened**: Lane dom1 queued a codegen + runner freeze at 4:26 PM ET and kept working. Seven more commits landed before the job was placed at 4:56 PM ET; the build compiled all of them. That was the intent here, but a half-applied multi-file edit at the placement instant would have been compiled too (and an uncommitted file, the ShadowRoot impl, was synced as it stood).

**Fix**:
1. While a job is queued, edit in whole units: one script that rewrites a set of files at once, then commit.
2. Read the placement line (`placed on <host> ... waited <s>`) to know which commit the build has - `git log` at that time, not at the launch.
3. If a change must NOT be in the build, wait for the placement line before making it.

**Takeaway**: **The tree a queued job builds is the worktree at placement: until the "placed" line, every edit you make is in the build.**
