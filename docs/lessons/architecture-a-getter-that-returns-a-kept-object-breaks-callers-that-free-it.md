# Architecture: A getter that starts returning a kept object breaks the callers that free what it returns

**Date**: 2026-11-06
**Lesson**: Before a method returns the same object again, find every native caller that owns its result: each one that frees it would free an object another caller still holds.

**Why**: Crane's platform objects are not reference counted outside the DOM tree: whoever is handed a fresh collection owns it, and a native caller frees it with `runtime.Instance.deinit` once it is done reading. Script never frees, because its wrapper owns the object. A weak identity cache, such as Blink's NodeListsNodeData, hands one object to every caller. The wrapper keeps owning it, but a native caller still frees what it gets, so it can free an object a script wrapper holds.

**What Happened**: Lane perf2 made getElementsByClassName, getElementsByTagName(NS) and getElementsByName return the same live list for the same root and argument (DOM 4.2.6's "the same HTMLCollection object may be returned"). A grep of the `call_getElementsBy*` callers outside the impls found three native callers:
- `Context.initializeIframeBrowsingContexts` called `interfaces.Document.call_getElementsByTagName(document, "iframe")` and then `runtime.Instance.deinit`. If script had already taken `document.getElementsByTagName('iframe')`, that call would have freed script's object.
- `HTMLDataListElement.get_options` and `HTMLMapElement.get_areas` built their [SameObject] collections through getElementsByTagNameNS. Freeing was not the problem here: the wrapper owned the object either way. The problem was identity: `datalist.options === datalist.getElementsByTagNameNS(HTML, 'option')` would have become true. A probe gave false in Chrome 156 and Firefox 159, and Blink's code agrees: these are collection types of their own.

**Fix**: Two constructors in `dom.live_collections`:
- `collectionFor(root, query)` returns the kept list. The script-facing impls call it, and the caller never frees what it gets.
- `newCollection(root, query)` returns a list the caller owns. The native steps and the [SameObject] attributes with HTML-defined filters call it.

The Context hunk is its own commit, because lane loadpath1 deletes that function. tests/dom/perf2_collection_identity_test.zig pins that a natively made list is distinct from the kept one, and that freeing the native list leaves the kept one working.

**Takeaway**: **A cache that hands out a shared object changes who owns every result: grep the native callers that free what they get, and give them a constructor of their own before the cache lands.**
