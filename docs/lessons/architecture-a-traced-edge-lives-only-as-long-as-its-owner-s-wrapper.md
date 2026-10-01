# Architecture: A traced edge lives only as long as its owner's wrapper - and a Window's wrapper is its global object, not its WindowProxy

**Date**: 2026-10-01
**Lesson**: Replacing a strong root (`same_object.Pin`) with an edge the collector traces (`engine.traceChild`, a private property on the owner's wrapper) is only safe where the owner's wrapper lives exactly as long as the owner - and the edge must hang on the right object.

**Why**: A Pin keeps the child whatever becomes of the owner, which is why a removed frame's whole heap stayed alive while any child was held. An edge keeps the child only while the owner's WRAPPER is reachable. Three ways that goes wrong:
- An owner the host keeps while the collector may take its wrapper (an engine-owned instance: a document with a view, a node in a tree) loses its children with its wrapper. A document's wrapper is therefore itself traced from its window's global object.
- An owner script has never seen gets its wrapper made by `traceChild`, and from then on the collector frees it when nothing reaches the wrapper. Trace only from an owner script holds or an edge keeps.
- A private property set on a global PROXY is stored on whichever global object the proxy reaches now (V8 `LookupIterator::GetStoreTarget`). After a navigation hands the WindowProxy on (`.window_proxy_of`), an old Window's edge set through it lands on the NEW global and replaces the new Window's edge in the same slot - freeing the new Window's child. A Window's edges hang on its own global object (the hidden one behind the proxy, or `retired_global` once the proxy went on).

**What Happened**: The design (tmp/plans/frame-realm-tracing-design.md) said "a private property on the owner's wrapper", and a Window's wrapper in Crane is its WindowProxy (`bound_v8_global`). tests/v8 "a Window whose WindowProxy went on to a new realm traces from its own global object" pins the handover; the hazard was found by reading V8's lookup code before writing the implementation, not by a crash. Separately, edges must never be ended from teardown: an owner's deinit can run inside a first-pass weak callback, where no V8 call but a handle Reset is allowed - so `KeptChild.release` and `Selection`'s state deinit only drop pointers, and the edge goes with the wrapper.

**Fix**: `protocol_tracing.zig` resolves a Window owner through `protocol_realms.tracedEdgeHolderOfWindow`, never wraps a Window outside a realm made for it, and holds strong clones of both wrappers for the length of the call; a host draws its edge to the new shadow root BEFORE the shadow root draws its edge back to the host (until then nothing keeps the new wrapper). `KeptChild` traces once per child made.

**Takeaway**: **Before swapping a root for a traced edge, prove the owner's wrapper lives as long as the owner, hang a Window's edges on its global object, and never touch the engine from a teardown the collector can start.**
