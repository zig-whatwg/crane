# Workflow: leaks --atExit sees only the process it launched - run the WPT runner without --parallel

**Date**: 2026-10-17
**Lesson**: `leaks --atExit -- ./zig-out/bin/wpt_runner --parallel=1 <file>` reported "0 leaks" for every file, with the same "856 nodes malloced for 350 KB" each time: the process leaks inspected was not the one that ran the tests. Without `--parallel` the runner runs the file in its own process, and leaks sees it (2,176+ nodes, and the real leaks).

**Why**: `leaks --atExit` examines the process it launched, when that process exits. With `--parallel=N` the runner hands the files to shard workers, so the launched process only discovered and dispatched them; whatever a worker leaked died with the worker, unexamined. A constant node count across very different files is the tell. Separately, macOS 27's leaks prints "Process ... is not debuggable ... can only show or save contents of readonly memory" for the runner (no get-task-allow entitlement); a copy re-signed with it (`codesign -s - -f --entitlements <plist with com.apple.security.get-task-allow>`) is fully debuggable. Never re-sign a shared frozen runner in place - copy it.

**What Happened**: Lane binding4 needed the "before" count for binding3's per-call argument leaks. The first runs said 0 everywhere, which proved nothing; a positive control is what showed the method was wrong: the same probe under main 2f09d08336's runner (before leaks2) reported 100 leaks for 100 `createNodeIterator(root)` calls once `--parallel` was dropped, and main's runner 0 - leaks2 had fixed it. The 853-file run then found the one leak left (LockManager.request's argument handles on its rejectOnThrow path).

**Fix**: One in-process runner per file, no `--parallel`, several at once with xargs (each file its own process); the runner copied and re-signed debuggable; a positive control (an older runner, or a known leak) before trusting a zero.

**Takeaway**: **A leak count of zero means nothing until the same method has found a leak: run a positive control, and make sure the inspected process is the one that ran the code.**
