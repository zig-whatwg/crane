# Debugging: A fault in Allocator.free's memset is a double free, and the allocator said so first

**Date**: 2026-09-30
**Lesson**: A SIGSEGV inside `mem.Allocator.free` (its `@memset(bytes, undefined)`) at an address with the same page offset every run is a slice freed twice whose page the DebugAllocator had already returned - and the DebugAllocator printed "Double free detected" for the earlier frees of the same kind, a few lines above the crash in the run log.

**Why**: `Allocator.free` poisons the bytes BEFORE handing them to the allocator, so a second free of a small allocation writes 0xAA into a slot that may belong to someone else by then (the "foreign value in a live block" that free-list detectors never see), and a second free into an unmapped bucket page faults on the memset. Bucket slots sit at fixed offsets, so the same allocation sequence faults at the same page offset (0x...b20, 0x...c20).

**What Happened**: `websockets/Create-http-urls.any.js` crashed in 1-of-6 to 5-of-9 sweeps, always in `WebSocket.InternalState.deinit` freeing `url_string` under a realm's teardown. Two hypotheses (a pump-token use-after-free, a stale Selection) were real defects but not this one, and arena free-list detectors saw nothing. A trace build that printed every WebSocket's make and deinit showed the order in the crashing child: socket B's deinit, then `error(DebugAllocator): Double free detected`, then socket A's deinit faulting. The test reads `ws.url`; `WebSocket.get_url` returned the socket's own `url_string`, and the binding frees what a getter returns ([Interface getters clone and hand you the memory](architecture-interface-getters-clone-and-hand-you-the-memory.md)). Every read freed the url; deinit freed it again. The 330-file repro list logged 74-117 "Double free detected" lines per 9 runs on every runner, crashing or not.

**Fix**: `get_url` returns `instance.ctx.allocator.dupe(u8, state.own.url)`. Red: crane/c2-websocket-url-getter.html, 0/2 with three double frees on main -> 2/2, none.

**Takeaway**: **Before tracing a fault in free, grep the run log for the allocator's own reports above it. A constant page offset means a fixed slot in a returned page: the pointer was freed before, not overwritten.**
