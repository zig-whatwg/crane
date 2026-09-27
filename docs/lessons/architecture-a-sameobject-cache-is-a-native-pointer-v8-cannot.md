# Architecture: A [SameObject] cache is a native pointer V8 cannot see

Three rounds of the same defect, merged. The binding-level fix (the private-property edge) is the current design; `same_object.Pin` covers owners that are not wrappers.

## A `[SameObject]` attribute cached as a bare pointer dangles after GC

**Date**: 2026-09-22
**Lesson**: The generated `get_upload` keeps the upload object in `cached_upload`
as a raw `*Instance`; nothing keeps its wrapper alive, so a collection frees it
while the XHR still points at it (`send-timeout-events.htm` builds a 1 MB
string, collects, and `send()` fires `upload.loadstart` into freed memory).

**Takeaway**: **A native pointer to a GC-managed object is a reference V8 cannot
see. Every `cached_*` field needs an owner that keeps the wrapper alive.**

## A [SameObject] cache is a pointer V8 cannot see

**Date**: 2026-09-22
**Lesson**: A generated `cached_*` field holds a bare `*runtime.Instance`, which keeps the child neither alive nor valid.

**What Happened**: `xhr.upload.onloadend = f` leaves nothing in JS holding `xhr.upload`; a GC between that line and `send()` freed it, and `send()` fired `upload.loadstart` into freed memory (`send-timeout-events.htm`). The same shape in reverse: a caching getter such as `form.elements` hands a Zig caller the element's OWN object, and freeing it (as `form.submit()` once did) broke `form.elements` for script too.

**Fix**: `impls/same_object.zig`: `Pin.hold` takes a strong Global to the child's wrapper on first hand-out and the owner's deinit releases it (Blink traces the same edge: `XMLHttpRequest::Trace` visits `upload_`). A Window's Location and History count as engine-owned for the same reason (`DOMWindow::Trace` visits `location_`).

**Takeaway**: **Every native pointer to a GC-managed object needs an owner that keeps its wrapper alive, and nothing a caching getter returned is yours to free.**

## A [SameObject] child lives as long as its owner's wrapper

**Date**: 2026-09-23
**Lesson**: The generated `[SameObject]` getter caches the child as a bare `*runtime.Instance`. Nothing kept the child's wrapper alive, so a GC freed `node.childNodes` under the cache, and the next read wrapped whatever the slab had put there: `length` read `undefined`, `Range-*` files SEGVed in teardown.

**Fix**: the binding records a private-property edge from the owner's wrapper to the child's (`v8_Object_SetPrivateRef`) whenever it returns an attribute whose state has a `cached_<name>` field. That is the edge Blink draws by tracing. It covers every generated `[SameObject]` attribute at once. `same_object.zig`'s `Pin` remains for owners that are not wrappers.

**Takeaway**: **Any native pointer from one GC-managed object to another needs an edge V8 can see. A private property on the owner's wrapper is the cheapest one.**

## A hand-written cache in an impl gets no edge from the binding

**Date**: 2026-09-27
**Lesson**: The binding's edge covers only generated `cached_<name>` state. Window's `get_sessionStorage`, `get_localStorage` and `get_customElements` cache their object in the impl's own `InternalState`, and nothing held those wrappers: a collection during a frame's navigation freed the parent's Storage, its vtable name read as garbage, the wrap failed, and `sessionStorage` was `undefined` (`crane/nav-session-storage.html`).

**Fix**: each takes a `same_object.Pin` when first made, released in the Window's deinit (dd792cb0f), as `navigator` already did - Blink's `DOMWindowStorage::Trace` and `LocalDOMWindow::Trace` visit the same members. `crane/window-storage-survives-gc.html` checks it: a `WeakRef` to each survives `TestUtils.gc()`.

**Takeaway**: **A getter that caches a child in an impl's own state must pin it; only the generated caches get the binding's edge.** (Open: `window.crypto`, a generated `cached_crypto` attribute, also reads `undefined` in the parent after that frame navigation. Not yet diagnosed - if it is the same free, the edge does not hold on a Window's global.)
