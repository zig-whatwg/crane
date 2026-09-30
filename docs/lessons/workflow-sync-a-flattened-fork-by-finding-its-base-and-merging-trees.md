# Workflow: Sync a flattened WPT fork by finding its base and merging trees

**Date**: 2026-09-30
**Lesson**: The zig-whatwg/wpt fork began as "Initial commit: WPT snapshot" with no record of its upstream commit; the base can be found by tree distance, and the sync done as a three-way `git merge-tree` against it, without importing upstream's history.

**Why**: wpt.fyi compares runs at one upstream revision, so Crane's snapshot has to be a known upstream commit plus Crane's own files. A merge commit with upstream as a parent would have needed upstream's whole history in the fork (2.8 GB; the fork is not a GitHub fork, GitHub refuses pushes over 2 GB and pushes from a shallow clone).

**What Happened**: diffing the snapshot's tree against upstream first-parent commits around its date found fae291ef5 (2025-12-23) at 7 differing files: crane/, `.wpt_serve.lock`, and a wptrunner `browsers/crane.py` product that no one had listed among the fork's patches. `git merge-tree --write-tree --merge-base=fae291ef5 <fork main> afe89a5df4` then carried crane/ and five tool patches onto the new upstream, with two small conflicts (upstream had moved wptrunner's product list into products.py). The commit's only parent is fork main, so main fast-forwards; `CRANE-UPSTREAM.md` and `.crane-upstream-revision` record the base for the next sync. Two traps on the way: a clone of the main checkout's WPT module inherits its shallow boundary, and an upstream fetch into it stops there.

**Fix**: see `CRANE-UPSTREAM.md` at the fork root for the recipe; pick the revision of wpt.fyi's latest aligned stable runs (`/api/runs?aligned&label=master&label=stable`).

**Takeaway**: **A snapshot with no recorded base is still a known commit: find it by tree distance, then sync by merging trees against it. Record the base where the next sync will look for it.**
