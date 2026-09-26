# Spec Compliance: A relative iframe `src` never loaded, and three bugs hid behind it

**Date**: 2026-09-23
**Lesson**: `<iframe src="resources/x.html">` - most of WPT's iframes - silently never loaded: the raw attribute value went to the navigation fetch, which cannot fetch a relative URL. Absolute URLs worked, which is why every hand-written probe passed.

**What Happened**: the 52 `moving-between-documents/` files kept timing out after window.postMessage was fixed. One probe comparing an absolute, a root-relative and a path-relative `src` named it: only the absolute one loaded. Fixing it exposed, one at a time:
1. `Node.baseURI` was a stub returning `""` - and was also `undefined` in script, because the lazy getter converter had no `USVString` branch.
2. `parseOriginFromURL` kept `:8000` in the host and hard-coded port 80, so no frame on a non-default port was same origin with its container; `contentDocument` answered null.
3. The frame origin's `host` BORROWED the URL buffer navigateToSrc was called with, which every caller frees.

**Fix**: parse `src` against `node.baseURI` through the URL interface (HTML's shared attribute processing steps), implement `baseURI` per HTML's document base URL, take host and port from the authority, and let the integration own the host bytes. moving-between-documents: 52 TIMEOUT -> 52 OK, 260/260 subtests.

**Takeaway**: **Test a feature with the URL shapes the corpus actually uses. A probe written with an absolute URL passes against an engine that cannot resolve a relative one - and `Origin`-style structs that borrow their strings need an owner as much as any pointer does.**
