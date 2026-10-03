# Workflow: A zig cache in /tmp is pruned by macOS, and zig still trusts it

**Date**: 2026-10-02
**Lesson**: Never keep a zig cache in `/tmp` on macOS: the OS deletes files there that are three days old, and
zig keeps treating the half-emptied entries as cache hits.

**Why**: macOS (14 and later) runs `com.apple.tmp_cleaner` (`/usr/libexec/tmp_cleaner`) every night at 00:00. It
deletes `/tmp` files whose access, modification and change times are all more than three days old. A zig cache
manifest records its inputs, not the full contents of its output directory, so a cache hit never re-checks the
output: an include tree with most of its headers deleted is still a "hit" and is passed to the compiler as is.

**What Happened**: The integrator's iOS check (`zig build lib-full -Dtarget=aarch64-ios -j2 --cache-dir
/tmp/crane-z16-cache`) failed compiling curl with `'mbedtls/version.h' file not found`. The same failure at an
older main seemed to prove a long-standing build.zig regression, and it was queued as one. The deps lane read the
failing command: its `-I /tmp/crane-z16-cache/o/35f2c7e6.../` (curl's mbedTLS include tree) held 22 of
mbedTLS's 74 headers; that directory's mtime, and 310 others', was exactly Oct 2 00:00:00 - the cleaner's run.
The surviving headers were the ones compiled within the last three days. Both "old" and "new" builds read the same
damaged cache, which is why the older main failed identically.

**Fix**: Local builds use `--cache-dir ~/Library/Caches/crane-z16-cache` (AGENTS.md "Before every commit"). The
damaged cache was deleted. chat's caches were already outside /tmp (`~/crane-caches/<mirror>`), and
`tmp/remote/crane-remote.sh` strips the local cache path from commands it forwards so chat never creates one.

**Takeaway**: **A failure that reproduces on an older commit is not proof the code is old - check that the two
runs did not share a damaged input. A cache in /tmp on macOS is a cache with an expiry date nobody checks.**
