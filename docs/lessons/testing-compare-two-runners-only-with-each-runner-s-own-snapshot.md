# Testing: Compare two runners only with each runner's own snapshot

**Date**: 2026-09-27
**Lesson**: The WPT runner loads `zig-out/bin/whatwg_snapshot.bin` relative to its working directory, whatever binary it is. A runner copied aside for an A/B still loads whatever snapshot the last build wrote.

**Why**: Browser.zig's snapshot paths are relative (`zig-out/bin/whatwg_snapshot.bin` first). The snapshot's stamp checks only the external-reference count, so a snapshot from another build is accepted whenever the counts match. That leaves a lane's runner running on main's templates and callbacks.

**What Happened**: The reflection lane's final A/B built its runner, then main's. The lane runner then ran with main's snapshot, and 24 files that open an iframe or a window (custom-elements/reactions, webstorage events) went OK -> TIMEOUT. They looked like a regression from the lane's eager-accessor or DOMTokenList commits. Rerun with the lane's own snapshot in place, all 24 were back to main's status.

**Fix**: Save each build's snapshot beside its runner (`cp zig-out/bin/whatwg_snapshot.bin tmp/snap_<side>.bin`), and before each side runs, `rm` then `cp` its own snapshot into `zig-out/bin/`.

**Takeaway**: **A runner and its snapshot are one artifact. Freeze them together, and put the right snapshot in place before every run.**
