# Architecture: Deleted IndexedDB handles outlive their schema entry

**Date**: 2026-10-03
**Lesson**: Deleting a schema entry invalidates its handles without destroying observable handle objects.

**Why**: Script may keep an IDBIndex after deleteIndex(), inspect its properties, or attempt a method that must throw InvalidStateError. Recreating the same name produces a different index and does not revive the old handle.

**What Happened**: The native object store destroyed a cached index when removing its name. A regression retained that handle and called count(); the test hung. Sampling the owned test process showed count() iterating through the freed index's entry list. The process was terminated after recording the stack, rather than leaving a shared build slot occupied.

**Fix**: Reserve a retirement slot before mutation, remove the schema and cache entries, mark the handle deleted, and keep it until its store is destroyed. Check deletion before accessing records. Retain index definition data separately so property getters still have valid storage.

**Takeaway**: **Schema membership and handle lifetime are separate: remove the entry, invalidate the handle, and keep its memory alive.**
