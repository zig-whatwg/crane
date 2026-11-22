# Architecture: An edge from another world's object pins the world

**Date**: 2026-11-21
**Lesson**: A per-world cache or reaction hung on an object of ANOTHER world (a private property on a page promise holding the world's promise for it, a reaction whose functions are the world's) keeps the world realm's context alive for as long as that object lives - long after the world realm has ended.

**Why**: V8 keeps a native context alive through any object or function made in it. A private property `source -> mirror` holds the mirror, whose creation context is the world's; a `then` reaction made in the world's context hangs the world's functions on the source. Neither edge is visible to the world realm's end steps, and a page promise routinely outlives a DevTools world (a navigation ends the world, not the page's pending `document.fonts.ready`).

**What Happened**: Lane cdpw's first cut of cross-world promises (protocol_worlds.mirrorPromise, Blink's ScriptPromiseProperty per world) cached the world's promise on the page's promise under a key per WORLD and reacted to the page's promise in the WORLD realm. The integrator caught it before any test ran: a world ended while a page promise was pending would stay in the heap.

**Fix**: Key the cache per world REALM and record each source by a weak handle on the realm (`WorldRealm.mirrored`); at the realm's end delete the private edge from every source still alive. React in the SOURCE realm, so the reaction's functions are the source world's, and keep the world's resolver in a host record the realm's end cuts (`Mirror.cut`). A test counts native contexts (`v8_Isolate_GetContextCounts`) before the world and after its end plus collections.

**Takeaway**: **Anything a world hangs on an object it does not own must be owned by the world realm and cut at its end; make reactions in the realm of the object they wait on, and prove it by counting native contexts after the end.**
