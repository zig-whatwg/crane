# Architecture: A queued permission value is not delivered state

**Date**: 2026-10-19
**Lesson**: A subscription cannot suppress a repeated update merely because it queued the same value earlier.

**Why**: PermissionStatus update steps stop when a Window's document is not fully active. Posting a task therefore does not prove that the target changed state. A task may also be dropped when its sink closes.

**What Happened**: BrowserStore initially cached each subscription's last queued state. The native regression in `tests/html/pm2_permission_delivery_test.zig` skipped an earlier update, then repeated the same override. The cache suppressed the second task: the target saw one delivery instead of the expected two.

**Fix**: Queue each matching override and let PermissionStatus compare the value with its actual state on its own thread. Its activity check runs before that comparison and update. An unchanged active status still fires no event, while a status that missed an earlier update can receive a later one. The store needs no acknowledgement protocol or cross-thread reads of status internals.

**Takeaway**: Keep queued intent separate from applied state. Suppress duplicates only where successful application is known.
