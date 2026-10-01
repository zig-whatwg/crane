# Workflow: A long sweep runs from its own copy, not a shared frozen baseline

**Date**: 2026-10-01
**Lesson**: `~/crane-frozen/main-<sha>/` lives only until the next main gate replaces it. A sweep that runs for hours from it loses everything queued after the deletion, and the loss does not look like a failure.

**Why**: The gate script deletes the superseded frozen directory: its runner, its snapshot and its `tests/wpt` link. `crane-measure.sh sweep` starts each chunk with `cd` already done, so later chunks run `./zig-out/bin/wpt_runner` from a directory that no longer has one. Each chunk then records exit 127, and the sweep still "finishes", writes `sweep.done` and reports a record count.

**What Happened**: The 31,158-file full-corpus sweep ran from `main-21edba80f` for 9 hours. That directory was deleted at 10:49:58, when main-ed3433c37 was gated. The chunk in flight (adf) turned 266 of its 300 files into ERROR with 0 ms and no message, because the test files vanished under it. The remaining 20 chunks each recorded `127` in `<chunk>.done`. `sweep.done` read "25200 records", 6,000 short, with nothing else saying so.

**Fix**: For anything longer than one gate interval, copy the runner and its snapshot to a directory you own (`~/crane-work/<lane>-bins/<sha>/zig-out/bin/`, plus a `tests/wpt` link) and sweep from that. After a sweep, check every `<chunk>.done` exit code (`cat chunks/*.done | awk '{print $1}' | sort | uniq -c`) and compare the record count with the list length. To recover, delete the bad chunks and their `.done` files and re-run the sweep command, which resumes.

**Takeaway**: **A sweep's `sweep.done` says only that it stopped. Read the per-chunk exit codes, and never sweep for hours from a directory someone else's gate deletes.**
