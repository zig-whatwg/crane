# Debugging: A per-block heap finds the leaks a wholesale arena hid - read the lifecycle flags first

**Date**: 2026-11-23
**Lesson**: When an allocator that freed everything at its owner's end is replaced by one that frees block by block, a leak report at that end will list objects the old allocator dropped silently. These are real leaks: they grew over the owner's whole life. Before theorising about who should have freed them, read each live Instance's lifecycle flags. "Never wrapped" (all flags 0) names a path that made an object and lost it before any wrapper existed. A constructor's failure path is the usual culprit.

**Why**: The old state arena and slab dropped their blocks wholesale at the Browser's end, so `leaks --atExit` and the WPT runner's leak counters never saw an object nobody freed. They saw only the Browser's last allocation. Over a runner's life those objects kept their slots and States. One Browser held 6,860 TextDecoders after `encoding/`.

**What Happened**: Lane hard1's span engine frees per block and reports every block alive at the Browser's end, by type and by the live Instance's lifecycle flags. A full-worklist bug-finding sweep found two classes:
- Class A: nodes the final sweep had judged and left to the arena's wholesale free (a reviewed owner, now freed explicitly).
- Class B: TextDecoder 6,860, WebSocket 535, Headers 12, File 8 and ExtendableMessageEvent 1, all with flags 0b00000000.

The first guess, made from the counts growing over the runner's life, was that worker realms (or realm ends) did not free their objects. It was wrong. The flags said that none of these objects had ever been wrapped, which points to an object made and lost before it reached the binding. Each of the five constructors made `this` first, then threw a RangeError, SyntaxError or TypeError, and its `errdefer X.deinit(instance)` ran the destructor chain only. That is the same mistake as docs/lessons/architecture-an-interfaces-deinit-is-a-destructor-not-a-free.md, made at construction. A scan found the same shape in 370 of 450 impl constructors. Most of them fail after allocation only on OOM, which is still a leak; the worklist reaches five.

**Fix**:
1. Each constructor frees what it made with `errdefer runtime.gc.releaseOwned(instance)`, as lane v8state1 did for URL and Blob. Lane hard1 has one commit per type.
2. tests/v8/constructor_error_receiver_test.zig counts the platform objects across 64 failed constructions for each type. All five were red at 65 -> 129. ExtendableMessageEvent's case runs in a service worker realm, the only place it is exposed.
3. The class-wide fix is queued as a lint ratchet: a constructor's failure path frees what it made.

**Takeaway**: **A leak report that a wholesale-freeing allocator never allowed is a list of real leaks; sort it by lifecycle flags before guessing an owner. "Never wrapped" means something made the object and dropped it before any wrapper could exist: look at that type's constructor's failure path.**
