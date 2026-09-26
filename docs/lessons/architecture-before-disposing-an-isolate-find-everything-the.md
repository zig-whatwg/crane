# Architecture: Before disposing an isolate, find everything the process keeps for one isolate at a time

**Date**: 2026-09-25
**Lesson**: A worker's isolate can be disposed only after every process-wide holder of its handles has let go. The crash from a missed one lands in a LATER file.

**What Happened**: `v8_wrapper.cpp` caches one isolate's async iterator template, and resets it when another isolate asks for it. A worker that ran `for await` left its template cached. After its isolate was disposed, the page's next `for await` reset a dead handle: V8_Fatal in `NodeSpace::Release`, reported as `streams/readable-streams/patched-global.any.js` crashing only in a sweep. The other holders:
- `template_registry` (`clearForIsolate`)
- the isolate's data slots (template storage, allocator)
- a fetch's 0 ms settle timer holding a promise resolver, which is why the dispose runs one timer after the realm goes
- `detachedWeakData`, now scoped per isolate (7db007756)

**Takeaway**: **When a sweep-only crash follows a worker test, look for a process-wide cache that held the worker isolate's handle.**
