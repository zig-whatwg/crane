//! V8 Wrapper Identity Cache
//!
//! Per-context cache that maintains 1:1 mapping between Zig instances and V8 wrappers.
//! Solves the wrapper identity problem where multiple calls to querySelector
//! return different V8 wrappers for the same DOM element.
//!
//! ## Problem Solved
//!
//! **Before** (without cache):
//! ```javascript
//! const h1 = document.querySelector("header");
//! const h2 = document.querySelector("header");
//! console.log(h1 === h2); // false ❌ Different V8 wrappers!
//! ```
//!
//! **After** (with cache):
//! ```javascript
//! const h1 = document.querySelector("header");
//! const h2 = document.querySelector("header");
//! console.log(h1 === h2); // true ✅ Same V8 wrapper cached!
//! ```
//!
//! ## Architecture
//!
//! - **Key**: `*runtime.Instance` (Zig DOM instance pointer)
//! - **Value**: `*anyopaque` (V8 Global<Object>* handle - persistent across scopes)
//! - **Lifetime**: Weak callbacks automatically remove entries when V8 GC collects wrappers
//! - **Scope**: Per-context (each V8 Context has its own cache)
//!
//! ## Usage
//!
//! During V8 Context initialization:
//! ```zig
//! var cache = try WrapperCache.init(allocator, context);
//! defer cache.deinit();
//! ```
//!
//! When wrapping an instance (in template_registry.wrapInstanceAsV8Object):
//! ```zig
//! // Check cache first
//! if (cache.get(instance)) |cached_wrapper| {
//!     return cached_wrapper; // Return existing wrapper
//! }
//!
//! // Create new wrapper
//! const v8_obj = createNewWrapper(instance, template, context);
//!
//! // Cache it with weak callback for GC cleanup
//! try cache.set(instance, v8_obj, isolate);
//! ```
//!
//! ## GC Integration
//!
//! Weak callbacks automatically clean up cache entries when V8 garbage collects wrappers:
//! 1. V8 GC determines wrapper is no longer reachable
//! 2. Weak callback fires with CacheEntry pointer
//! 3. Callback removes entry from HashMap
//! 4. Callback frees Global<Object>* handle
//!
//! ## Thread Safety
//!
//! NOT thread-safe. Each V8 Context is single-threaded, so the cache is also single-threaded.
//! Multiple contexts can have separate caches on different threads.

const std = @import("std");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const realm_finalizers = @import("realm_finalizers.zig");

const log = std.log.scoped(.wrapper_cache);

/// Cache entry stored in the HashMap
///
/// Contains both the V8 wrapper handle and backpointer to the cache for cleanup.
const CacheEntry = struct {
    /// V8 Global<Object>* handle (persistent wrapper)
    wrapper: *anyopaque,

    /// Zig instance pointer (key for HashMap lookup during cleanup)
    instance: *runtime.Instance,

    /// Backpointer to cache (needed for removal during weak callback)
    cache: *WrapperCache,

    /// Set to true when the instance has been cleaned up externally
    /// (e.g., via Node.deinit). When true, deinit should NOT call
    /// onObjectFreed since the instance is already cleaned up.
    instance_already_cleaned: bool = false,

    /// True while the wrapper is held strongly (no weak arm): some reason in
    /// `shouldBeStrong` holds. Kept equal to it by `syncEntry`.
    strong: bool = false,

    /// Reasons to hold the wrapper that only a caller can state - see `Holds`.
    holds: Holds = .{},

    /// Kept by an edge from its realm's global object instead of a strong
    /// handle, since the realm's navigable was destroyed
    /// (`WrapperCache.detach`).
    retained: bool = false,

    /// Set to true when the cache is being destroyed. This allows pending
    /// weak callbacks to detect that they should skip cleanup because:
    /// 1. The cache is no longer valid
    /// 2. The instance pointer may have been reused by a new object
    /// When orphaned, callbacks should just dispose the wrapper and entry
    /// without calling onObjectFreed.
    is_orphaned: bool = false,

    /// VTable pointer captured when entry was created.
    /// Used to detect if instance address was reused for a different object.
    /// If the current instance's vtable differs from this, the address was
    /// reused and we should not call onObjectFreed.
    original_vtable: *const runtime.VTable,

    /// State pointer captured when entry was created.
    /// Used to detect if instance address was reused for the SAME type.
    /// Even if vtable matches, if state differs, it's a different instance.
    original_state: *anyopaque,

    /// Slab generation of `instance` when this entry was made. A stale entry -
    /// one whose instance was freed and its slot reissued before the weak
    /// callback ran - differs here even when vtable and state match.
    original_generation: u64,

    /// Collected: V8's first pass took the wrapper and `unlinkCollected` took
    /// the entry out of the cache. Its finalizer (`finalizeCollected`) runs in
    /// the second pass; until then it waits on the cache's pending list.
    collected: bool = false,

    /// The first pass found another entry under this instance, or none: this
    /// one was replaced or removed before its wrapper died, and owns nothing
    /// but its handle.
    stale: bool = false,

    /// The cache's list of collected entries awaiting their finalizer.
    pending_prev: ?*CacheEntry = null,
    pending_next: ?*CacheEntry = null,
};

/// Why a wrapper is held strongly, beyond what `engineOwns` reads off the
/// instance itself. Orthogonal reasons: each is set and cleared by its own
/// caller, and the wrapper is weak only when none remains (`shouldBeStrong`).
/// Blink keeps these apart the same way - a document is reachable from its
/// frame, while an ActiveScriptWrappable is kept by HasPendingActivity()
/// (platform/bindings/active_script_wrappable_base.h) - so ending one reason
/// never drops another.
const Holds = packed struct {
    /// A window's document (`holdStrong`): the window aliases the wrapper.
    document: bool = false,
    /// Pending activity (`holdForPendingActivity`): a running Worker, which
    /// must outlive whatever script holds of it until it is terminated.
    pending_activity: bool = false,
};

/// Whether `entry`'s wrapper must be held strongly: a caller's reason
/// (`Holds`), or the engine holding the wrapper itself (a window's document,
/// Location or History, a streams-graph object). The default - no reason - is
/// weak, and only then. A node in a tree is NOT a reason: its wrapper is kept
/// by edges from its parent's and its children's wrappers (node tracing, see
/// `drawTreeEdges`), so a tree lives exactly as long as script reaches any
/// wrapper in it - its root's included.
fn shouldBeStrong(entry: *const CacheEntry) bool {
    // A torn-down instance's wrapper is never what keeps anything.
    if (entry.instance_already_cleaned) return false;
    if (entry.holds.document or entry.holds.pending_activity) return true;
    return engineHoldsWrapper(entry.instance);
}

/// Dispose an entry's V8 handle, first dropping any alias to it.
///
/// `NodeBase.bound_v8_wrapper` (set by template_registry.wrapInstanceAsV8Object)
/// stores the SAME `Global<Object>*` handle that the cache entry owns, so that
/// DOM nodes keep JavaScript `===` identity across contexts. Disposing the
/// handle without clearing that alias leaves a dangling pointer which the next
/// wrapInstanceAsV8Object call would happily return.
///
/// The pointer-equality guard matters: instance addresses are recycled by the
/// SlabAllocator, so the NodeBase reachable from `entry.instance` may already
/// belong to a different object. Only an exact match is ours to clear.
/// The realm is ending and `entry`'s instance is freed (or already was, or
/// its slot went to another object): clear the wrapper's internal fields
/// first - what severWindow does for a Window's global, for every wrapper.
/// Script elsewhere - another realm, which is how a removed frame's objects
/// are usually held - can outlive this realm and keep the wrapper; the next
/// read through it then fails the binding's unwrap with a TypeError instead
/// of reaching an impl with a freed instance (23 impls unwrap `_internal`
/// unchecked; crane/fl-xhr-frame-removed-mid-request.html panicked in
/// XMLHttpRequest.getXHRState). Blink clears a wrapper's native pointer when
/// the object it names goes (V8DOMWrapper::ClearNativeInfo). Only a wrapper
/// whose instance goes: a node its tree owns, or an instance another realm
/// still wraps, keeps its fields.
fn severWrapper(entry: *CacheEntry) void {
    // A wrapper the collector already took has nothing to sever.
    if (v8.v8_Global_IsEmpty(@ptrCast(entry.wrapper))) return;
    const wrapper: *v8.Object = @ptrCast(@alignCast(entry.wrapper));
    // A legacy platform object's wrapper is a proxy whose target holds the
    // fields (the unwrap reads them through it): sever the target.
    if (v8.v8_Value_IsProxy(@ptrCast(wrapper))) {
        const target = v8.v8_Proxy_GetTarget(wrapper) orelse return;
        defer v8.v8_Value_Dispose(target);
        if (v8.v8_Value_IsObject(target)) clearFields(@ptrCast(target));
        return;
    }
    clearFields(wrapper);
}

fn clearFields(object: *v8.Object) void {
    const count = v8.v8_Object_InternalFieldCount(object);
    if (count < 1) return;
    v8.v8_Object_SetAlignedPointerInInternalField(object, 0, null);
    if (count >= 2) v8.v8_Object_SetAlignedPointerInInternalField(object, 1, null);
}

fn disposeEntryWrapper(entry: *CacheEntry) void {
    const instance_bridge = @import("dom").instance_bridge;

    if (instance_bridge.getNodeBase(@ptrCast(entry.instance))) |nodebase| {
        if (nodebase.bound_v8_wrapper == entry.wrapper) {
            nodebase.bound_v8_wrapper = null;
        }
    }

    v8.v8_Object_Dispose(@ptrCast(entry.wrapper));
}

/// True when the slab slot behind `entry.instance` no longer holds the
/// instance this entry was created for: freed (generation reads dead) or
/// reissued to a newcomer (a later generation). The vtable/state comparison
/// alone cannot see a same-type newcomer whose state block was recycled at
/// the same address - the case in which a stale callback's `Registry.remove`
/// evicted a live document's entry (AGENTS.md, "A stale weak callback's
/// `Registry.remove` evicts the LIVE entry at a recycled address").
fn slotReissued(entry: *const CacheEntry) bool {
    return entry.instance.vtable != entry.original_vtable or
        entry.instance.state != entry.original_state or
        runtime.SlabAllocator.generationOf(entry.instance) != entry.original_generation;
}

/// True while something other than V8 holds `instance`: a node with a parent
/// (its tree owns it) or a document with a default view (its browsing context
/// owns it). Read at callback time from the DOM's own parent pointer, which the
/// mutation algorithms keep current - and `slotReissued` has already
/// established that `instance` is the one this entry was made for. A stale
/// registry entry at a recycled address can only answer "owned" for something
/// that is not, which keeps an instance alive a little longer, never frees a
/// live one.
fn engineOwns(instance: *runtime.Instance) bool {
    return treeOwns(instance) or templateOwns(instance) or engineHoldsWrapper(instance);
}

/// True for a template's contents while its template is alive: the template
/// owns the fragment natively (HTML 4.12.3; WebKit's HTMLTemplateElement keeps
/// a RefPtr to it, Blink's traces content_), and only the template's teardown
/// frees it - or, when script still holds the fragment, hands it to its
/// wrapper by making it nobody's (`dom.template_contents.releaseHost`). The
/// edge between the two wrappers keeps only the content's wrapper, and goes
/// with either: owned through it, the fragment was freed under a template
/// whose wrapper had been replaced or collected (PR-M1). Like `treeOwns`, an
/// instance arm only - the content's wrapper stays weak. The default is false
/// (an ordinary fragment, a shadow root, anything not a node), pinned by
/// tests/v8/template_owns_predicate_test.zig.
pub fn templateOwns(instance: *runtime.Instance) bool {
    return @import("dom").template_contents.ownedByLiveTemplate(instance);
}

/// The part of `engineOwns` that holds the WRAPPER too, not only the
/// instance: a streams-graph object, a window's Location or History, a
/// document with a default view. (A node in a tree is the other part: its
/// instance is its tree's, its wrapper the edges' - `shouldBeStrong`.)
fn engineHoldsWrapper(instance: *runtime.Instance) bool {
    if (isStreamsGraphObject(instance.vtable.name)) return true;
    if (isWindowOwned(instance)) return true;
    const DocumentImpl = @import("impls").Document;
    if (DocumentImpl.getInternalState(instance)) |doc_internal| {
        if (doc_internal.default_view != null) return true;
    }
    return false;
}

/// A realm's Window: its realm's end frees it (protocol_realms).
fn isRealmWindow(instance: *runtime.Instance) bool {
    return std.mem.eql(u8, instance.vtable.name, "Window");
}

/// True for a node with a parent: its tree holds it - the parent's child list
/// points at it - and only the tree's teardown may free it (Node.deinit walks a
/// root's subtree). WebKit asserts the same in Node::~Node: a node is never
/// destroyed while it has a parent. Anything that is not a node, and a node
/// that is a root, answers false and is freed as before.
pub fn treeOwns(instance: *runtime.Instance) bool {
    const NodeImpl = @import("impls").Node;
    const node_internal = NodeImpl.getInternalState(instance) orelse return false;
    const node_base = node_internal.node_base orelse return false;
    return node_base.parent_node != null;
}

/// A window's Location and History: the Window holds each in its own state,
/// hands out that one instance on every `window.location` / `window.history`
/// ([SameObject]), and frees both in Window.deinit. Freeing one when its
/// wrapper was collected left the Window pointing at a freed slab slot, so
/// the next read returned whatever the slot held by then - an iframe's
/// `contentWindow.location.href` read undefined after a collection, and a
/// form submission navigating through it crashed. Blink keeps both alive
/// from the window: DOMWindow::Trace visits location_ and
/// LocalDOMWindow::Trace visits history_ (core/frame/dom_window.cc,
/// local_dom_window.cc).
fn isWindowOwned(instance: *runtime.Instance) bool {
    const impls = @import("impls");
    const name = instance.vtable.name;
    if (std.mem.eql(u8, name, "Location")) {
        const internal = impls.Location.getInternalState(instance) orelse return false;
        return internal.window != null;
    }
    if (std.mem.eql(u8, name, "History")) {
        const internal = impls.History.getInternal(instance) orelse return false;
        return internal.window != null;
    }
    return false;
}

/// Streams objects reach each other through Zig pointers V8 cannot see: a
/// stream's [[controller]] and [[writer]], a controller's [[stream]], and the
/// context of every pending promise reaction. Blink traces those slots
/// (third_party/blink/renderer/core/streams/, `Trace` on every class); with
/// Global handles there is nothing to trace, so collecting one wrapper frees
/// an instance another still points at. Their wrappers are held strongly and
/// the realm's teardown sweep frees them - memory for the realm's lifetime,
/// never a dangling [[controller]].
///
/// An allowlist, and only of the classes built on the `impls/streams_*.zig`
/// ownership rules: their teardown touches nothing but their own slots, so
/// the realm's sweep can free them in any order. The list itself is
/// runtime.streams_graph.streams_graph_classes.
pub fn isStreamsGraphObject(name: []const u8) bool {
    // One list, in the runtime tier: streams_js.Realm.wrap takes only these,
    // because only these are held here.
    return runtime.streams_graph.isStreamsGraphObject(name);
}

/// Which node wrappers V8 may collect, and when. WebKit keeps a node's
/// wrapper alive for as long as the node's tree is
/// (JSNodeOwner::isReachableFromOpaqueRoots: the tree's root is the opaque
/// root), and Blink traces it through the node (Node::Trace visits the
/// parent, the children and the wrapper), so in both `el.expando` and
/// `el === el` survive a collection while the node's tree lives - and a tree
/// lives while script reaches any node of it. With Global handles that is
/// node tracing (`drawTreeEdges`): every wrapped node's wrapper holds its
/// parent's, and every parent's wrapper holds its wrapped children's - edges,
/// never roots - so the wrapped part of a tree is one cycle the collector
/// keeps or takes whole. A wrapped node's parent is always wrapped (made if
/// script has not seen it), so the edges reach the tree's root. These hooks
/// keep the edges current: the mutation algorithms run the insertion and
/// removing steps for every node of a moved subtree, but only the subtree's
/// root gains or loses a parent, so each is read per node. Installed once,
/// at process start (initializeEngine).
///
/// Before node tracing, a node's wrapper was strong while it had a parent and
/// weak as a root: a root whose last use was done was collected while script
/// still held a node inside its tree, and the root's teardown freed that
/// node under its caller (gc_bench's host-in-dropped-parent; crane/r3-
/// detached-tree-child-keeps-root.html).
var tree_hooks_installed = false;

pub fn installTreeHooks() void {
    if (tree_hooks_installed) return;
    tree_hooks_installed = true;
    const mutation = @import("dom").mutation;
    mutation.registerInsertionStepsCallback(onNodeInserted) catch {};
    mutation.registerRemovingStepsCallback(onNodeRemoved) catch {};
    mutation.registerMovingStepsCallback(onNodeMoved) catch {};
}

fn onNodeInserted(node: *@import("dom").NodeBase) void {
    syncStrength(node);
    // A wrapped node that gained a parent: the edges between them (the
    // parent made for it if script has not seen it).
    const wrapper = nodeWrapper(node) orelse return;
    if (node.parent_node == null) return;
    drawTreeEdges(node, wrapper);
}

fn onNodeRemoved(node: *@import("dom").NodeBase, old_parent: ?*@import("dom").NodeBase) void {
    syncStrength(node);
    // Only the removed subtree's root lost a parent: the edges between them
    // go. The subtree keeps its own. (A descendant is visited with null - or,
    // on the fallback walk, with its own parent, which it still has.)
    const parent = old_parent orelse return;
    if (node.parent_node != null) return;
    const wrapper = nodeWrapper(node) orelse return;
    eraseTreeEdges(wrapper, parent);
}

/// The move algorithm (moveBefore) changes a node's parent without the
/// removing and insertion steps: its edges follow it - to the new parent,
/// away from `old_parent` (given for the moved node only).
fn onNodeMoved(node: *@import("dom").NodeBase, old_parent: ?*@import("dom").NodeBase) void {
    const parent = old_parent orelse return;
    const wrapper = nodeWrapper(node) orelse return;
    if (node.parent_node == parent) return;
    eraseTreeEdges(wrapper, parent);
    if (node.parent_node != null) drawTreeEdges(node, wrapper);
}

// ============================================================================
// Node tracing
// ============================================================================

/// The private keys of a node wrapper's edges: to its parent's wrapper, and
/// (a JS Set) to its wrapped children's.
const tree_parent_key = "crane:tree:parent";
const tree_children_key = "crane:tree:children";

/// The wrapper of `node` - a node has one, whatever realm reads it
/// (`NodeBase.bound_v8_wrapper`) - BORROWED; null for a node script has not
/// seen, or whose wrapper was collected (the first pass clears the alias).
fn nodeWrapper(node: *@import("dom").NodeBase) ?*v8.Value {
    return @ptrCast(@alignCast(node.bound_v8_wrapper orelse return null));
}

/// Draw the edges between `child` - wrapped: `child_wrapper` - and its
/// parent: the child's wrapper holds the parent's, the parent's holds the
/// child's. A parent script has not seen is wrapped first, in its relevant
/// realm, and so is every unwrapped ancestor above it, from the top down: the
/// edges must reach the tree's root, and wrapping top-down keeps each wrap's
/// own edges one level deep (no recursion along a deep tree). The ancestors'
/// wrappers are held until every edge is drawn: a new wrapper nothing reaches
/// yet would be the collector's, and a root collected now would free the tree
/// under `child`. Needs no context entered.
fn drawTreeEdges(child: *@import("dom").NodeBase, child_wrapper: *v8.Value) void {
    const parent = child.parent_node orelse return;
    const isolate = v8.v8_Isolate_GetCurrent() orelse return;
    const support = @import("protocol_support.zig");

    // The unwrapped ancestors, nearest first.
    var unwrapped: std.ArrayListUnmanaged(*@import("dom").NodeBase) = .empty;
    defer unwrapped.deinit(std.heap.c_allocator);
    var ancestor: ?*@import("dom").NodeBase = parent;
    while (ancestor) |a| : (ancestor = a.parent_node) {
        if (a.bound_v8_wrapper != null) break;
        unwrapped.append(std.heap.c_allocator, a) catch return;
    }
    // Wrapped from the top down; each wrap draws its own edges to the
    // ancestor above it (WrapperCache.set). Held until the end.
    var held: std.ArrayListUnmanaged(*v8.Value) = .empty;
    defer {
        for (held.items) |h| v8.v8_Global_Dispose(h);
        held.deinit(std.heap.c_allocator);
    }
    var i = unwrapped.items.len;
    while (i > 0) {
        i -= 1;
        const instance = instanceOfNode(unwrapped.items[i]) orelse return;
        const wrapper = support.relevantWrapper(isolate, instance) catch return;
        held.append(std.heap.c_allocator, wrapper) catch {
            v8.v8_Global_Dispose(wrapper);
            return;
        };
    }
    const parent_wrapper = nodeWrapper(parent) orelse return;
    v8.v8_Object_PrivateRefUpdate(child_wrapper, tree_parent_key.ptr, tree_parent_key.len, parent_wrapper);
    v8.v8_Object_PrivateSetUpdate(parent_wrapper, tree_children_key.ptr, tree_children_key.len, child_wrapper, true);
}

/// End the edges between a removed subtree's root (`child_wrapper`) and its
/// old parent. A parent whose wrapper is gone has no edge left to end.
fn eraseTreeEdges(child_wrapper: *v8.Value, old_parent: *@import("dom").NodeBase) void {
    if (v8.v8_Isolate_GetCurrent() == null) return;
    v8.v8_Object_PrivateRefUpdate(child_wrapper, tree_parent_key.ptr, tree_parent_key.len, null);
    const parent_wrapper = nodeWrapper(old_parent) orelse return;
    v8.v8_Object_PrivateSetUpdate(parent_wrapper, tree_children_key.ptr, tree_children_key.len, child_wrapper, false);
}

fn syncStrength(node: *@import("dom").NodeBase) void {
    const entry = entryOf(instanceOfNode(node) orelse return) orelse return;
    syncEntry(entry);
}

fn instanceOfNode(node: *@import("dom").NodeBase) ?*runtime.Instance {
    const instance_bridge = @import("dom").instance_bridge;
    const raw = instance_bridge.getInstance(node) orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// A document becomes a window's document after it may already have been
/// wrapped (an iframe's document is handed out as contentDocument before its
/// context exists). From that moment the window aliases the wrapper - WebKit's
/// `document` is a strong reference - so it must be held, not just kept: a
/// document whose wrapper was collected under the window died in
/// LookupIterator::GetRootForNonJSReceiver on the next `document` access
/// (custom-elements/connected-callbacks.html, SIGTRAP).
pub fn holdStrong(instance: *runtime.Instance) void {
    const entry = entryOf(instance) orelse return;
    entry.holds.document = true;
    syncEntry(entry);
}

/// Blink's ActiveScriptWrappable: hold `instance`'s wrapper while it has
/// pending activity - a running Worker, a timeout signal whose timer is
/// pending - whatever script holds of it. Ended by `releasePendingActivity`.
/// The activity can begin before script has seen the instance (a signal is
/// made, and its timer armed, before the binding wraps it): the hold is then
/// recorded against the instance and taken by its wrapper when it is made.
pub fn holdForPendingActivity(instance: *runtime.Instance) void {
    const cache = cacheOf(instance) orelse return;
    if (cache.cache.get(instance)) |entry| {
        entry.holds.pending_activity = true;
        syncEntry(entry);
        return;
    }
    cache.pending_before_wrap.put(cache.allocator, instance, runtime.SlabAllocator.generationOf(instance)) catch {};
}

/// `instance` has no pending activity any more (HasPendingActivity() turned
/// false): its wrapper is collectable again, unless another reason holds it.
/// Idempotent; a no-op for an instance never held this way.
pub fn releasePendingActivity(instance: *runtime.Instance) void {
    const cache = cacheOf(instance) orelse return;
    _ = cache.pending_before_wrap.remove(instance);
    const entry = cache.cache.get(instance) orelse return;
    if (!entry.holds.pending_activity) return;
    entry.holds.pending_activity = false;
    syncEntry(entry);
}

/// `instance`'s realm's cache, or null when it has none or it is being torn
/// down.
fn cacheOf(instance: *runtime.Instance) ?*WrapperCache {
    const cache_storage = instance.ctx.getV8WrapperCacheStorage() orelse return null;
    const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));
    if (cache.is_tearing_down) return null;
    return cache;
}

/// `instance`'s entry in its realm's cache, or null when it has no wrapper
/// there or the cache is being torn down.
fn entryOf(instance: *runtime.Instance) ?*CacheEntry {
    const cache = cacheOf(instance) orelse return null;
    return cache.cache.get(instance);
}

/// Arm or disarm `entry`'s weak callback to match `shouldBeStrong` - the one
/// path by which a wrapper's strength changes after it is made.
///
/// In a detached cache (`WrapperCache.detach`) no wrapper is strong: one that
/// should be is kept by an edge from the realm's global object instead,
/// drawn once and never withdrawn - the realm is going, and what it kept goes
/// with it.
fn syncEntry(entry: *CacheEntry) void {
    if (entry.cache.detached_holder) |holder| {
        if (shouldBeStrong(entry) and !entry.retained) {
            retainOnGlobal(holder, @ptrCast(entry.wrapper));
            entry.retained = true;
        }
        if (entry.strong) {
            armWeak(entry);
            entry.strong = false;
        }
        return;
    }
    const strong = shouldBeStrong(entry);
    if (entry.strong == strong) return;
    if (strong) {
        v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));
    } else {
        armWeak(entry);
    }
    entry.strong = strong;
}

/// The private key of the array on a detached realm's global object that
/// keeps what its cache would otherwise hold strongly.
const retained_key = "crane:retained";

/// Keep `value` by an edge from `holder`, a detached realm's global object
/// (the hidden one, never its proxy). A no-op once the global is collected.
fn retainOnGlobal(holder: *v8.Value, value: *v8.Value) void {
    v8.v8_Object_RetainInPrivateArray(holder, retained_key.ptr, retained_key.len, value);
}

/// The weak arm of `WrapperCache.detached_holder`: nothing to do when the
/// global object is collected - the handle reads empty, and every retain
/// through it is a no-op from then on.
fn detachedHolderCollected(_: ?*anyopaque, _: usize) callconv(.c) void {}

/// A deferred edge's child, made weak at a realm's detach once it is kept
/// from the global object: nothing to do when it is collected.
fn deferredChildCollected(_: ?*anyopaque, _: usize) callconv(.c) void {}

/// Every live WrapperCache on this thread - one per realm. A node has one
/// wrapper whatever realm reads it (its bound wrapper), but any other platform
/// object gets a wrapper in each realm's cache that wraps it: a span's
/// DOMStringMap read by its frame and by the frame's parent has two. The
/// instance must outlive all of them - Blink traces it from every world's
/// wrapper - so a cache frees an instance only when no other live cache still
/// wraps it. Freeing it on the first wrapper's death left the other realm's
/// wrapper, and the element's [SameObject] cache, on freed memory.
threadlocal var live_caches: std.ArrayListUnmanaged(*WrapperCache) = .empty;

/// The wrappers every live cache on this thread holds - every realm's - for
/// the diagnostics tier (protocol.zig diagnosticCounters,
/// `wrapper_cache_entries`).
pub fn liveEntryCount() usize {
    var total: usize = 0;
    for (live_caches.items) |cache| total += cache.size();
    return total;
}

/// The edges every live cache on this thread holds for owners script has
/// not seen yet (`WrapperCache.deferEdge`), for tests and diagnostics.
pub fn liveDeferredEdgeCount() usize {
    var total: usize = 0;
    for (live_caches.items) |cache| total += cache.deferredEdgeCount();
    return total;
}

/// Whether a live cache other than `except` holds a wrapper for this very
/// instance - same slot, same generation.
fn wrappedElsewhere(instance: *runtime.Instance, except: *const WrapperCache) bool {
    const generation = runtime.SlabAllocator.generationOf(instance);
    for (live_caches.items) |other| {
        if (other == except) continue;
        const entry = other.cache.get(instance) orelse continue;
        if (entry.original_generation == generation and entry.original_vtable == instance.vtable) return true;
    }
    return false;
}

/// Arm `entry`'s wrapper weak: the collector takes the entry out of the cache
/// in its first pass and its instance is torn down after the collection.
fn armWeak(entry: *CacheEntry) void {
    v8.v8_Global_SetWeakFinalizer(@ptrCast(entry.wrapper), @ptrCast(entry), unlinkCollected, finalizeCollected);
}

/// V8's FIRST pass: `entry`'s wrapper was collected and its handle Reset. No
/// V8 API may be called here (v8-weak-callback-info.h) - other wrappers of
/// this collection may still hold the 0xCA11 zap value - so this only makes
/// the entry unreachable, as Blink's firstWeakCallback reset the object's
/// wrapper: out of the cache's map, off a node's bound wrapper, onto the
/// cache's pending list. A wrap from here on makes a new wrapper. The
/// instance's teardown is the finalizer's, after the collection.
fn unlinkCollected(data: ?*anyopaque, _: usize) callconv(.c) void {
    const entry: *CacheEntry = @ptrCast(@alignCast(data orelse return));
    entry.collected = true;
    // A destroyed cache's entry: nothing to unlink from (the finalizer
    // frees it).
    if (entry.is_orphaned) return;

    const instance_bridge = @import("dom").instance_bridge;
    if (instance_bridge.getNodeBase(@ptrCast(entry.instance))) |nodebase| {
        if (nodebase.bound_v8_wrapper == entry.wrapper) nodebase.bound_v8_wrapper = null;
    }

    // Due to memory reuse (SlabAllocator/ArenaAllocator), the same instance
    // address can be used for different objects over time: remove by key
    // only this entry, and put back one that replaced it.
    if (entry.cache.cache.fetchRemove(entry.instance)) |kv| {
        if (kv.value != entry) {
            log.debug("[unlinkCollected] STALE ENTRY: instance={*} - entry replaced, restoring new entry", .{entry.instance});
            // The slot it came from is free again: no allocation.
            entry.cache.cache.putAssumeCapacity(entry.instance, kv.value);
            entry.stale = true;
        }
    } else {
        log.debug("[unlinkCollected] NOT FOUND: instance={*}", .{entry.instance});
        entry.stale = true;
    }
    entry.cache.linkPending(entry);
}

/// V8's SECOND pass for a collected wrapper (`unlinkCollected` ran): the
/// collection is over and engine calls are allowed again, so the instance's
/// teardown runs here - never while the engine is collecting.
fn finalizeCollected(data: ?*anyopaque, _: usize) callconv(.c) void {
    const entry: *CacheEntry = @ptrCast(@alignCast(data orelse return));
    finalizeEntry(entry);
}

/// The teardown of a collected entry: free its instance unless something
/// still owns it, then its handle and the entry. Run by the second pass, or
/// by the cache's end for one whose second pass has not come yet.
fn finalizeEntry(entry: *CacheEntry) void {
    // An orphaned entry means the cache was destroyed (via
    // deinitWithoutCallbacks): the instance pointer may have been reused for
    // a new object - just clean up the entry itself. The cache allocator
    // outlives its caches' entries.
    if (entry.is_orphaned) {
        log.debug("[finalizeEntry] ORPHANED: instance={*} - cache was destroyed, skipping cleanup", .{entry.instance});
        disposeEntryWrapper(entry);
        entry.cache.allocator.destroy(entry);
        return;
    }
    entry.cache.unlinkPending(entry);

    // Replaced or removed before it was collected: nothing of the instance
    // is this entry's.
    if (entry.stale) {
        disposeEntryWrapper(entry);
        entry.cache.allocator.destroy(entry);
        return;
    }

    // The SlabAllocator can reuse instance addresses: an instance freed
    // since (its tree's teardown, or the realm's end) and its slot reissued is
    // not this entry's to free.
    log.debug("[finalizeEntry] VTABLE_CHECK: instance={*} orig_vtable={*} curr_vtable={*} orig_state={*} curr_state={*}", .{ entry.instance, entry.original_vtable, entry.instance.vtable, entry.original_state, entry.instance.state });
    if (slotReissued(entry)) {
        log.debug("[finalizeEntry] INSTANCE REUSED: instance={*} - vtable/state/generation mismatch, skipping cleanup", .{entry.instance});
        disposeEntryWrapper(entry);
        entry.cache.allocator.destroy(entry);
        return;
    }

    // Wrapped again since the collection - script reached the instance
    // through something the host holds, and a new wrapper was made: that
    // wrapper owns it now. Blink's second pass dropped only the collected
    // wrapper's reference for the same reason.
    if (entry.cache.cache.get(entry.instance)) |current| {
        if (current.original_generation == entry.original_generation and current.original_vtable == entry.original_vtable) {
            disposeEntryWrapper(entry);
            entry.cache.allocator.destroy(entry);
            return;
        }
    }

    // If the CleanupCoordinator is handling teardown, type-specific cleanup
    // must still happen for an instance nothing has cleaned up yet - unless
    // another realm still wraps it.
    //
    // Except a node still in a tree: its tree's teardown frees it. Node
    // tracing lets a whole detached tree's wrappers die in one collection, so
    // the realm's end can find a parented node's entry pending beside its
    // root's - freed here first, the root's teardown then walked into it
    // (gc_bench's host-in-dropped-parent body, a segfault in Node.deinit at the
    // page's end).
    if (runtime.cleanup_coordinator.isContextTearingDown()) {
        if (!runtime.instance_lifecycle.isCleanupStarted(entry.instance) and
            !wrappedElsewhere(entry.instance, entry.cache) and
            !treeOwns(entry.instance))
        {
            runtime.gc.onObjectFreed(entry.instance);
        }
        disposeEntryWrapper(entry);
        entry.cache.allocator.destroy(entry);
        return;
    }

    // Already being cleaned up (Node.deinit ran): free the storage a
    // completed cleanup left.
    if (runtime.instance_lifecycle.isCleanupStarted(entry.instance)) {
        if (runtime.instance_lifecycle.isCleanedUp(entry.instance)) runtime.gc.releaseStorage(entry.instance);
        disposeEntryWrapper(entry);
        entry.cache.allocator.destroy(entry);
        return;
    }

    // An instance the ENGINE still owns is not freed when JS drops its
    // wrapper: a node in a tree is reachable from its parent, a window's
    // document from its browsing context, and neither pointer is visible to
    // V8. Only the wrapper goes; a later wrap makes a fresh one. A realm's
    // Window is freed by its realm's end, never by its wrapper's death.
    //
    // And a streams object of a detached realm is not kept: its graph was
    // held for the realm's life by the global object, which is gone now with
    // every wrapper of the graph, and the realm's end no longer finds this
    // entry to free it (the teardown of these classes touches only their own
    // slots, so any order is safe).
    const detached_streams = entry.cache.detached_holder != null and isStreamsGraphObject(entry.instance.vtable.name);
    if (isRealmWindow(entry.instance) or (engineOwns(entry.instance) and !detached_streams)) {
        log.debug("[finalizeEntry] ENGINE-OWNED: instance={*} - wrapper released, instance kept", .{entry.instance});
        disposeEntryWrapper(entry);
        entry.cache.allocator.destroy(entry);
        return;
    }

    // Another realm's cache still wraps this instance: only this realm's
    // wrapper goes. See `live_caches`.
    if (wrappedElsewhere(entry.instance, entry.cache)) {
        disposeEntryWrapper(entry);
        entry.cache.allocator.destroy(entry);
        return;
    }

    // The type's deinit (e.g., Response.deinit frees headers, body, URL
    // list), which returns the Instance to the SlabAllocator - engine calls
    // allowed: it may release the values it holds.
    runtime.gc.onObjectFreed(entry.instance);
    disposeEntryWrapper(entry);
    entry.cache.allocator.destroy(entry);
}

/// V8 Wrapper Identity Cache
///
/// Per-context cache maintaining 1:1 mapping between Zig instances and V8 wrappers.
pub const WrapperCache = struct {
    /// HashMap: *runtime.Instance → CacheEntry
    cache: std.AutoHashMap(*runtime.Instance, *CacheEntry),

    /// Allocator for cache entries
    allocator: std.mem.Allocator,

    /// Flag indicating the cache is being torn down.
    /// When true, markAsCleanedUp becomes a no-op to prevent
    /// re-entrant access during deinit iteration.
    is_tearing_down: bool = false,

    /// V8 Context (unused currently, kept for future extensions)
    context: *v8.Context,

    /// Whether this cache is in `live_caches`.
    registered: bool = false,

    /// Pending-activity holds placed before the instance was wrapped
    /// (`holdForPendingActivity`), by slab generation so a reissued address
    /// does not inherit one. `set` moves a hold onto the new wrapper's entry.
    pending_before_wrap: std.AutoHashMapUnmanaged(*runtime.Instance, u64) = .empty,

    /// Edges `traceChild` drew from an owner script had not seen yet
    /// (protocol_tracing.zig): each child's wrapper held strongly here until
    /// the owner's wrapper is made - `set` draws the edges on it - or this
    /// realm ends. By slab generation, so an owner freed unwrapped and its
    /// address reissued leaves nothing to a newcomer.
    edges_before_wrap: std.AutoHashMapUnmanaged(*runtime.Instance, DeferredEdges) = .empty,

    /// Past `small_deferred_map` owners, `deferEdge` prunes dead owners'
    /// edges only once the map has grown to this many - then to twice what
    /// the prune left. Pruning on every call walked the whole map each time: a
    /// page whose owners stay unwrapped and alive - every testharness Test
    /// keeps an AbortController whose signal script never reads, and aborts it
    /// at cleanup, keeping the reason (traceValue) - paid O(n) per edge, and
    /// 8,000 test() calls took 1.5 s instead of 0.3 s.
    prune_watermark: usize = small_deferred_map,

    /// Its realm is detached (`detach`): the realm's global object - the
    /// hidden one behind the global proxy - as a WEAK handle the cache owns,
    /// empty once collected. Every wrapper that would be held strongly is
    /// kept by an edge from it instead (`syncEntry`).
    detached_holder: ?*v8.Value = null,

    /// Entries whose wrapper was collected and whose finalizer has not run
    /// (`unlinkCollected` -> `finalizeCollected`), most recent first. The
    /// cache's end finalizes what is still here: V8 drops a second pass its
    /// isolate never ran.
    pending_head: ?*CacheEntry = null,

    /// What this realm's end finalizes that no wrapper owns: its promise
    /// reactions that have not run and its asynchronous iterators still
    /// alive (realm_finalizers.zig). The realm's end drains it before the
    /// realm's objects are torn down (context_manager.removeContextByKey);
    /// the cache's own end drains what is left.
    finalizers: realm_finalizers.List = .{},

    const Self = @This();

    fn linkPending(self: *Self, entry: *CacheEntry) void {
        entry.pending_prev = null;
        entry.pending_next = self.pending_head;
        if (self.pending_head) |head| head.pending_prev = entry;
        self.pending_head = entry;
    }

    fn unlinkPending(self: *Self, entry: *CacheEntry) void {
        if (entry.pending_prev) |prev| prev.pending_next = entry.pending_next else if (self.pending_head == entry) self.pending_head = entry.pending_next;
        if (entry.pending_next) |next| next.pending_prev = entry.pending_prev;
        entry.pending_prev = null;
        entry.pending_next = null;
    }

    /// Tests: put `entry` - taken out of the map by hand - where the first
    /// pass puts a collected one, to stand in for the window between V8's two
    /// passes.
    pub fn linkPendingForTest(self: *Self, entry: *CacheEntry) void {
        self.linkPending(entry);
    }

    /// Tests: run the finalizers waiting for V8's second pass now.
    pub fn finalizePendingForTest(self: *Self) void {
        self.finalizePending();
    }

    /// Entries collected and not finalized yet (tests, diagnostics).
    pub fn pendingFinalizerCount(self: *const Self) usize {
        var count: usize = 0;
        var at = self.pending_head;
        while (at) |entry| : (at = entry.pending_next) count += 1;
        return count;
    }

    /// The cache is ending: run every finalizer still waiting for its second
    /// pass now - outside any collection - and cancel that pass (disposing
    /// the entry's handle does). Each runs as the second pass would have.
    fn finalizePending(self: *Self) void {
        while (self.pending_head) |entry| finalizeEntry(entry);
    }

    /// The cache is being destroyed without running teardowns
    /// (`deinitWithoutCallbacks`): each pending entry's handle and storage go
    /// now, its instance with the batch free.
    fn orphanPending(self: *Self) void {
        while (self.pending_head) |entry| {
            self.unlinkPending(entry);
            disposeEntryWrapper(entry);
            self.allocator.destroy(entry);
        }
    }

    /// The realm is detached - its navigable was destroyed, or a navigation
    /// replaced its document - and lives on only for as long as script
    /// reaches anything of it (protocol_realms, HTML "destroy a child
    /// navigable", "destroy a document"). A strong handle here would keep it
    /// forever, so each wrapper held strongly - a node in a tree, a window's
    /// Location, a streams object, pending activity - is kept from the
    /// realm's global object instead, and so is each child waiting for its
    /// owner's wrapper (`edges_before_wrap`). `global` is that global object
    /// - the hidden one, never the proxy a navigation hands on - BORROWED:
    /// the cache keeps a weak clone of it for the entries synced later.
    pub fn detach(self: *Self, global: *v8.Value) void {
        if (self.detached_holder != null) return;
        const holder = v8.v8_Global_Clone(global) orelse return;
        v8.v8_Global_SetWeak(@ptrCast(holder), null, detachedHolderCollected);
        self.detached_holder = holder;
        var iter = self.cache.valueIterator();
        while (iter.next()) |entry_ptr| syncEntry(entry_ptr.*);
        var deferred_iter = self.edges_before_wrap.valueIterator();
        while (deferred_iter.next()) |deferred| {
            for (deferred.edges.items) |edge| {
                retainOnGlobal(holder, edge.child);
                v8.v8_Global_SetWeak(@ptrCast(edge.child), null, deferredChildCollected);
            }
        }
    }

    /// One owner's edges waiting for its wrapper.
    pub const DeferredEdges = struct {
        generation: u64,
        edges: std.ArrayListUnmanaged(DeferredEdge) = .empty,

        fn dispose(self: *DeferredEdges, allocator: std.mem.Allocator) void {
            for (self.edges.items) |edge| edge.dispose(allocator);
            self.edges.deinit(allocator);
        }
    };

    /// A private key (owned) and the child's wrapper, a strong Global
    /// (owned): what `v8_Object_SetPrivateRef` will set on the owner.
    pub const DeferredEdge = struct {
        key: []u8,
        child: *v8.Value,

        fn dispose(self: DeferredEdge, allocator: std.mem.Allocator) void {
            v8.v8_Global_Dispose(self.child);
            allocator.free(self.key);
        }
    };

    /// Hold `child` - a Global the cache takes over, on failure too - for
    /// `owner`, whose wrapper is not made yet, under `key`; until then the
    /// hold is strong. Replaces an edge in the same key.
    pub fn deferEdge(self: *Self, owner: *runtime.Instance, key: []const u8, child: *v8.Value) error{OutOfMemory}!void {
        errdefer v8.v8_Global_Dispose(child);
        const owners = self.edges_before_wrap.count();
        if (owners < small_deferred_map or owners >= self.prune_watermark) {
            self.pruneDeferredEdges();
            self.prune_watermark = @max(small_deferred_map, 2 * self.edges_before_wrap.count());
        }
        const generation = runtime.SlabAllocator.generationOf(owner);
        const gop = try self.edges_before_wrap.getOrPut(self.allocator, owner);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{ .generation = generation };
        } else if (gop.value_ptr.generation != generation) {
            // A dead owner's edges at a reissued address: not the newcomer's.
            gop.value_ptr.dispose(self.allocator);
            gop.value_ptr.* = .{ .generation = generation };
        }
        for (gop.value_ptr.edges.items) |*edge| {
            if (!std.mem.eql(u8, edge.key, key)) continue;
            v8.v8_Global_Dispose(edge.child);
            edge.child = child;
            return;
        }
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        try gop.value_ptr.edges.append(self.allocator, .{ .key = owned_key, .child = child });
    }

    /// End a deferred edge (engine.forgetTracedChild on an owner script has
    /// not seen). A no-op when there is none.
    pub fn forgetDeferredEdge(self: *Self, owner: *runtime.Instance, key: []const u8) void {
        const deferred = self.edges_before_wrap.getPtr(owner) orelse return;
        for (deferred.edges.items, 0..) |edge, i| {
            if (!std.mem.eql(u8, edge.key, key)) continue;
            edge.dispose(self.allocator);
            _ = deferred.edges.swapRemove(i);
            return;
        }
    }

    /// What `owner` keeps under `key` while it waits for its wrapper - a
    /// child's wrapper or a traced value - BORROWED; null when nothing waits
    /// (or what waits is a dead owner's at a reissued address, or a value a
    /// detached realm let go weak and the collector took).
    pub fn deferredEdge(self: *Self, owner: *runtime.Instance, key: []const u8) ?*v8.Value {
        const deferred = self.edges_before_wrap.getPtr(owner) orelse return null;
        if (deferred.generation != runtime.SlabAllocator.generationOf(owner)) return null;
        for (deferred.edges.items) |edge| {
            if (!std.mem.eql(u8, edge.key, key)) continue;
            if (v8.v8_Global_IsEmpty(edge.child)) return null;
            return edge.child;
        }
        return null;
    }

    /// The owner's wrapper is made: draw the edges waiting for it, and let
    /// the strong holds go. Needs a current context, which every wrap has.
    fn drawDeferredEdges(self: *Self, instance: *runtime.Instance, generation: u64, wrapper: *v8.Object) void {
        var kv = self.edges_before_wrap.fetchRemove(instance) orelse return;
        defer kv.value.dispose(self.allocator);
        if (kv.value.generation != generation) return;
        for (kv.value.edges.items) |edge| {
            // A child a detached realm let go weak may be gone.
            if (v8.v8_Global_IsEmpty(edge.child)) continue;
            v8.v8_Object_SetPrivateRef(wrapper, edge.key.ptr, @intCast(edge.key.len), edge.child);
        }
    }

    /// Drop the edges of owners freed unwrapped whose teardown did not end
    /// them (their slot's generation moved on): a backstop - an owner that
    /// can be freed unwrapped ends its edges in its teardown
    /// (engine.forgetTracedChild).
    fn pruneDeferredEdges(self: *Self) void {
        var iter = self.edges_before_wrap.iterator();
        while (iter.next()) |kv| {
            if (runtime.SlabAllocator.generationOf(kv.key_ptr.*) == kv.value_ptr.generation) continue;
            kv.value_ptr.dispose(self.allocator);
            // Removing during iteration: the map's own tombstone removal
            // leaves the iterator valid.
            self.edges_before_wrap.removeByPtr(kv.key_ptr);
        }
    }

    /// A map of fewer owners than this is pruned on every `deferEdge` - a walk
    /// that cheap costs less than the edges it lets go; past it, pruning is
    /// amortized (`prune_watermark`).
    const small_deferred_map = 64;

    /// The edges waiting for their owners' wrappers, in this cache.
    pub fn deferredEdgeCount(self: *const Self) usize {
        var total: usize = 0;
        var iter = self.edges_before_wrap.valueIterator();
        while (iter.next()) |deferred| total += deferred.edges.items.len;
        return total;
    }

    /// Every deferred edge's hold, at the realm's end.
    /// The weak handle `detach` kept, at the cache's end.
    fn disposeDetachedHolder(self: *Self) void {
        const holder = self.detached_holder orelse return;
        self.detached_holder = null;
        v8.v8_Global_Dispose(holder);
    }

    fn disposeDeferredEdges(self: *Self) void {
        var iter = self.edges_before_wrap.valueIterator();
        while (iter.next()) |deferred| deferred.dispose(self.allocator);
        self.edges_before_wrap.deinit(self.allocator);
        self.edges_before_wrap = .empty;
    }

    /// Initialize a new wrapper cache
    ///
    /// Creates an empty HashMap ready to cache wrappers.
    ///
    /// ## Parameters
    /// - allocator: Memory allocator for cache entries
    /// - context: V8 Context this cache belongs to
    ///
    /// ## Returns
    /// Initialized WrapperCache
    pub fn init(allocator: std.mem.Allocator, context: *v8.Context) !Self {
        return .{
            .cache = std.AutoHashMap(*runtime.Instance, *CacheEntry).init(allocator),
            .allocator = allocator,
            .context = context,
        };
    }

    /// Clean up cache resources
    ///
    /// Disposes all cached Global handles and frees the HashMap.
    /// Should be called when the V8 Context is destroyed.
    /// This also calls gc.onObjectFreed for each instance to ensure
    /// type-specific deinit is called (since weak callbacks may not fire
    /// during shutdown).
    pub fn deinit(self: *Self) void {
        // Mark as tearing down to prevent re-entrant access during cleanup.
        // When Node.deinit calls markInstanceCleanedUp, it will be a no-op.
        self.is_tearing_down = true;

        // The realm's records no wrapper owns - its end drained them
        // already, unless it ended some other way.
        self.finalizers.drain();

        // PHASE 0: wrappers already collected whose finalizer has not run -
        // it would find this cache gone. Run them now.
        self.finalizePending();

        // PHASE 1: Clear ALL weak callbacks first to prevent any from firing
        // during cleanup. This must happen before any cleanup to avoid races
        // where a weak callback tries to free an already-freed entry.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));
            }
        }

        // PHASE 2: Now safe to clean up all entries (no weak callbacks can fire)
        log.debug("[wrapper_cache.deinit] cache={*} PHASE 2: Processing {} entries", .{ self, self.cache.count() });

        // Debug: dump all entries at deinit time
        {
            var debug_iter = self.cache.iterator();
            while (debug_iter.next()) |kv| {
                const inst = kv.key_ptr.*;
                const ent = kv.value_ptr.*;
                const NodeImpl = @import("impls").Node;
                var is_iframe_str: []const u8 = "no";
                var local_name_str: []const u8 = "null";
                if (NodeImpl.getInternalState(inst)) |node_internal| {
                    if (node_internal.local_name) |ln| {
                        local_name_str = ln.asSlice();
                        if (std.mem.eql(u8, ln.asSlice(), "iframe")) {
                            is_iframe_str = "YES";
                        }
                    }
                } else {
                    local_name_str = "no_internal";
                }
                log.debug("[wrapper_cache.deinit] ENTRY: instance={*} entry={*} local_name={s} is_iframe={s} vtable={*} state={*}", .{ inst, ent, local_name_str, is_iframe_str, inst.vtable, inst.state });
            }
        }
        var iter = self.cache.valueIterator();
        var processed: usize = 0;
        var skipped_cleaned: usize = 0;
        var skipped_started: usize = 0;
        var iframe_count: usize = 0;
        while (iter.next()) |entry_ptr| {
            const entry = entry_ptr.*;
            processed += 1;

            // Count iframes in cache
            const NodeImpl = @import("impls").Node;
            var is_iframe = false;
            if (NodeImpl.getInternalState(entry.instance)) |node_internal| {
                if (node_internal.local_name) |ln| {
                    if (std.mem.eql(u8, ln.asSlice(), "iframe")) {
                        iframe_count += 1;
                        is_iframe = true;
                    }
                }
            }

            // Only call deinit if not already cleaned up externally
            // Check both:
            // 1. instance_already_cleaned flag (set by markAsCleanedUp during tree walk)
            // 2. isCleanupStarted flag (set at start of Node.deinit)
            // The second check catches cases where markAsCleanedUp couldn't set the flag
            // (e.g., if is_tearing_down was already true or entry wasn't found)
            //
            // CRITICAL: Also check if the instance has been reused (vtable/state changed).
            // The SlabAllocator can reuse memory addresses multiple times. If the instance
            // at this address is different from what we cached, we must NOT call onObjectFreed
            // as it would deinit the wrong object.
            const is_started = runtime.instance_lifecycle.isCleanupStarted(entry.instance);
            const is_reused = slotReissued(entry);
            if (entry.instance_already_cleaned) {
                severWrapper(entry);
                skipped_cleaned += 1;
                if (is_iframe) {
                    log.debug("[wrapper_cache.deinit] SKIP_CLEANED iframe instance={*}", .{entry.instance});
                }
            } else if (is_started) {
                skipped_started += 1;
                if (is_iframe) {
                    log.debug("[wrapper_cache.deinit] SKIP_STARTED iframe instance={*}", .{entry.instance});
                }
                // Its tree tore it down and left the storage: free that, and
                // only that - deinit has run.
                if (!is_reused and runtime.instance_lifecycle.isCleanedUp(entry.instance)) {
                    severWrapper(entry);
                    runtime.gc.releaseStorage(entry.instance);
                }
            } else if (is_reused) {
                // Its slot holds another object now: the wrapper must not
                // reach it.
                severWrapper(entry);
                // Instance was reused for a different object - don't call onObjectFreed
                // This can happen when:
                // 1. Old instance X was cached
                // 2. Old X was GC'd and deinit'd via weakCallback
                // 3. New instance Y was allocated at same address
                // 4. Y was also GC'd and deinit'd via weakCallback
                // 5. Yet another instance Z was allocated at same address
                // 6. Cache deinit runs, entry.instance points to Z, not Y
                log.debug("[wrapper_cache.deinit] SKIP_REUSED instance={*} orig_vtable={*} curr_vtable={*}", .{ entry.instance, entry.original_vtable, entry.instance.vtable });
            } else if (treeOwns(entry.instance)) {
                // A node still in a tree is the tree's to free, whatever
                // realm's cache wrapped it. Freed here, in hash order, a child
                // went before its detached root and the root's teardown walk
                // read the freed child; and a parent document's node wrapped
                // in a frame's realm went while the parent's tree still held
                // it. Only the wrapper goes: the root's teardown frees the
                // node - this cache's, if the root is wrapped here.
                //
                // The other order was already safe: a root freed first frees
                // its children in Node.deinit, which marks each one's cleanup
                // started, so a child's entry reached after its root is
                // skipped above as `is_started`.
            } else if (wrappedElsewhere(entry.instance, self)) {
                // Another realm's cache still wraps it; that one frees it.
            } else {
                if (is_iframe) {
                    log.debug("[wrapper_cache.deinit] DEINIT iframe instance={*}", .{entry.instance});
                }
                // The wrapper may outlive this realm (script elsewhere holds
                // it): it must not reach the instance freed next.
                severWrapper(entry);
                // Call GC integration to invoke type-specific deinit
                // This is essential for cleanup since weak callbacks may not fire during shutdown
                runtime.gc.onObjectFreed(entry.instance);
            }

            // Dispose the Global<Object>* handle
            disposeEntryWrapper(entry);

            // Free the CacheEntry
            self.allocator.destroy(entry);
        }

        log.debug("[wrapper_cache.deinit] Summary: processed={}, iframes={}, skipped_cleaned={}, skipped_started={}", .{ processed, iframe_count, skipped_cleaned, skipped_started });
        self.unregister();
        self.cache.deinit();
        self.pending_before_wrap.deinit(self.allocator);
        self.disposeDeferredEdges();
        self.disposeDetachedHolder();
    }

    /// Clean up cache without calling onObjectFreed callbacks.
    /// Used during context manager teardown to avoid use-after-free
    /// when cleaning up cross-context references (e.g., iframe Windows).
    ///
    /// During normal operation, onObjectFreed is called to trigger
    /// type-specific cleanup. During teardown, all instances will be
    /// batch-freed anyway, so calling individual deinit functions
    /// can cause crashes if they reference already-freed memory.
    ///
    /// CRITICAL: This function marks entries as "orphaned" before cleanup.
    /// If V8's GC has already queued a weak callback that fires after this
    /// function returns, the callback will see the orphaned flag and skip
    /// calling onObjectFreed. This prevents a critical bug where a callback
    /// for an old instance at address X incorrectly deinits a NEW instance
    /// that reused address X.
    pub fn deinitWithoutCallbacks(self: *Self) void {
        // Mark as tearing down to prevent re-entrant access
        self.is_tearing_down = true;

        // The realm's records no wrapper owns: each is disarmed and its host
        // data freed, exactly once, as at any realm end.
        self.finalizers.drain();

        // Collected entries waiting for their finalizer: nothing of theirs
        // runs now either; their handles and storage go.
        self.orphanPending();

        // PHASE 1: Mark all entries as orphaned FIRST.
        // This must happen before ClearWeak because if a callback fires
        // after ClearWeak but before we destroy entries, it needs to see
        // the orphaned flag to skip onObjectFreed.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                entry.is_orphaned = true;
            }
        }

        // PHASE 2: Try to clear weak callbacks.
        // This may not stop callbacks that V8 already queued.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));
            }
        }

        // PHASE 3: Dispose V8 handles and destroy entries.
        // Since we've cleared weak callbacks, they should not fire.
        // The orphaned flag serves as a safety net - if a callback somehow
        // fires after this point (race with V8 GC), it will see is_orphaned=true.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                // Dispose the Global<Object>* handle
                disposeEntryWrapper(entry);
                // Free the CacheEntry
                self.allocator.destroy(entry);
            }
        }

        self.unregister();
        self.cache.deinit();
        self.pending_before_wrap.deinit(self.allocator);
        self.disposeDeferredEdges();
        self.disposeDetachedHolder();
    }

    /// Join `live_caches` - on first use, when this cache's address is
    /// final (callers copy `init`'s result into place).
    fn register(self: *Self) void {
        if (self.registered) return;
        live_caches.append(std.heap.page_allocator, self) catch return;
        self.registered = true;
    }

    fn unregister(self: *Self) void {
        if (!self.registered) return;
        for (live_caches.items, 0..) |c, i| {
            if (c == self) {
                _ = live_caches.swapRemove(i);
                break;
            }
        }
        // The list's memory goes with its last cache: a worker thread's
        // caches all go before it ends, and what a threadlocal still holds
        // when its thread exits is never freed.
        if (live_caches.items.len == 0) live_caches.clearAndFree(std.heap.page_allocator);
        self.registered = false;
    }

    /// The wrapper `instance` already has, BORROWED - a node's one wrapper
    /// whatever realm made it (its alias), else this cache's live entry -
    /// or null when script has not seen it. What a constructor whose
    /// instance was wrapped while it was made returns, instead of binding
    /// the object V8 made for NewTarget (which `set` refuses).
    pub fn existingWrapper(self: *Self, instance: *runtime.Instance) ?*v8.Object {
        if (@import("dom").instance_bridge.getNodeBase(@ptrCast(instance))) |node| {
            if (node.bound_v8_wrapper) |bound| return @ptrCast(@alignCast(bound));
        }
        const entry = self.cache.get(instance) orelse return null;
        if (entry.instance_already_cleaned or slotReissued(entry)) return null;
        return @ptrCast(entry.wrapper);
    }

    /// Get cached wrapper for an instance
    ///
    /// ## Parameters
    /// - instance: The Zig instance to look up
    ///
    /// ## Returns
    /// V8 Object wrapper if cached, null otherwise
    pub fn get(self: *Self, instance: *runtime.Instance) ?*v8.Object {
        if (self.cache.get(instance)) |entry| {
            return @ptrCast(entry.wrapper);
        }
        return null;
    }

    /// Cache a wrapper for an instance with weak callback
    ///
    /// Stores the wrapper in the cache and sets up a weak callback for GC cleanup.
    ///
    /// ## Parameters
    /// - instance: The Zig instance (cache key)
    /// - wrapper: The V8 Object wrapper (Global<Object>* handle)
    /// - isolate: V8 isolate (for setting weak callback)
    ///
    /// ## Errors
    /// - OutOfMemory: If allocation fails
    pub fn set(
        self: *Self,
        instance: *runtime.Instance,
        wrapper: *v8.Object,
        isolate: *v8.Isolate,
    ) !void {
        _ = isolate; // Will be used for weak callback in next commit
        self.register();

        // An instance has ONE wrapper in a realm. One that is live already
        // is never replaced: every edge drawn on it - a traced child, a
        // [SameObject] value, its tree edges - would go with it (a template's
        // content was freed this way when a constructor bound the template to
        // NewTarget's object, PR-M1). A constructor whose instance was
        // wrapped while it was made returns that wrapper instead
        // (interface.zig, `adoptExistingWrapper`). Only an entry left by a
        // dead instance at a reissued address, or by a torn-down one, gives
        // way below - and a realm's Window, whose wrapper is its realm's
        // global object, bound here when the realm is made: none of its edges
        // hang on a cached wrapper (protocol_tracing.zig holderOf hangs them
        // on the global object).
        if (self.cache.get(instance)) |existing| {
            if (!existing.instance_already_cleaned and !slotReissued(existing) and !isRealmWindow(instance))
                return error.AlreadyWrapped;
        }

        // Allocate CacheEntry
        const entry = try self.allocator.create(CacheEntry);
        errdefer self.allocator.destroy(entry);

        entry.* = .{
            .wrapper = @ptrCast(wrapper),
            .instance = instance,
            .cache = self,
            .original_vtable = instance.vtable,
            .original_state = instance.state,
            .original_generation = runtime.SlabAllocator.generationOf(instance),
        };

        // Store in HashMap.
        //
        // An existing entry here is a dead or torn-down instance's (a live
        // one was refused above). Replacing the value without releasing the
        // old entry would leak its CacheEntry and its Global<Object>* handle,
        // and leave that handle's weak callback armed pointing at memory we
        // are about to orphan. Release it the same way remove() does before
        // taking over the key.
        if (self.cache.fetchRemove(instance)) |kv| {
            const old_entry = kv.value;
            log.debug(
                "[set] replacing existing wrapper for instance={*} old_entry={*} new_entry={*}",
                .{ instance, old_entry, entry },
            );
            v8.v8_Global_ClearWeak(@ptrCast(old_entry.wrapper));
            disposeEntryWrapper(old_entry);
            self.allocator.destroy(old_entry);
        }
        try self.cache.put(instance, entry);

        // Set weak callback for GC cleanup
        // The wrapper of a node in a tree - or of a window's document - is
        // held strongly, so its identity and its expandos survive a collection
        // the way they do in WebKit and Blink. It goes weak when the node
        // becomes a root (installTreeHooks), and the teardown sweep frees it
        // otherwise.
        // A pending-activity hold placed before the wrapper existed.
        if (self.pending_before_wrap.fetchRemove(instance)) |held| {
            if (held.value == entry.original_generation) entry.holds.pending_activity = true;
        }
        // Edges traced from the instance before script saw it.
        self.drawDeferredEdges(instance, entry.original_generation, wrapper);
        // A node: this is its one wrapper, whatever realm reads it - the
        // alias node tracing finds it by (`nodeWrapper`), and every later
        // wrap returns. Set here, for every wrapper the cache takes: one a
        // constructor made used to have none, so the insertion steps drew no
        // edges for it and `f.appendChild(new Text())` left the text's
        // wrapper - its expandos, a custom element's class - to the next
        // collection. Then the edges between its wrapper and its parent's,
        // drawn while this wrapper is still held strongly - its parent's
        // wrapper made first if script has not seen it (node tracing).
        if (@import("dom").instance_bridge.getNodeBase(@ptrCast(instance))) |node| {
            if (node.bound_v8_wrapper == null) node.bound_v8_wrapper = @ptrCast(wrapper);
            if (node.parent_node != null and !self.is_tearing_down) drawTreeEdges(node, @ptrCast(wrapper));
        }
        if (shouldBeStrong(entry) and self.detached_holder == null) {
            entry.strong = true;
        } else {
            armWeak(entry);
            if (self.detached_holder != null) syncEntry(entry);
        }
    }

    /// Clear the entire cache
    ///
    /// Disposes all cached wrappers and clears the HashMap.
    /// Useful for testing or explicit cache invalidation.
    /// Uses two-phase cleanup like deinit() to prevent use-after-free
    /// from weak callbacks firing during cleanup.
    pub fn clear(self: *Self) void {
        // Collected entries waiting for their finalizer run it now.
        self.finalizePending();

        // PHASE 1: Clear ALL weak callbacks first to prevent any from firing
        // during cleanup. This must happen before any cleanup to avoid races
        // where a weak callback tries to free an already-freed entry.
        {
            var iter = self.cache.valueIterator();
            while (iter.next()) |entry_ptr| {
                const entry = entry_ptr.*;
                v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));
            }
        }

        // PHASE 2: Now safe to clean up all entries (no weak callbacks can fire)
        var iter = self.cache.valueIterator();
        while (iter.next()) |entry_ptr| {
            const entry = entry_ptr.*;

            // Call GC integration to invoke type-specific deinit
            // This is essential for cleanup since weak callbacks were disabled
            if (!wrappedElsewhere(entry.instance, self)) runtime.gc.onObjectFreed(entry.instance);

            // Dispose the Global<Object>* handle
            disposeEntryWrapper(entry);

            // Free the CacheEntry
            self.allocator.destroy(entry);
        }

        self.cache.clearRetainingCapacity();
        self.disposeDeferredEdges();
    }

    /// Mark an entry as already cleaned (instance deinit already called)
    ///
    /// This is used when the instance is being cleaned up by other means
    /// (e.g., Node.deinit cleaning up DOM tree). We mark it so that
    /// wrapper_cache.deinit() won't call onObjectFreed again (double-free).
    ///
    /// Also sets lifecycle tracking flags for coordinated cleanup (RC2 fix).
    ///
    /// We don't dispose the V8 handle here because we might still be in
    /// JavaScript execution context. The handle will be disposed during
    /// wrapper_cache.deinit().
    ///
    /// ## Parameters
    /// - instance: The Zig instance that has been cleaned up
    ///
    /// ## Returns
    /// true if entry was found and marked, false if not in cache
    pub fn markAsCleanedUp(self: *Self, instance: *runtime.Instance) bool {
        // CRITICAL: Skip during teardown to avoid HashMap access corruption.
        // During wrapper_cache.deinit, we're iterating and destroying entries.
        // Accessing the HashMap via get() during this phase can cause alignment
        // errors because entries are being deallocated.
        //
        // Instead, callers should use runtime.instance_lifecycle.markCleanupStarted()
        // which uses a SEPARATE tracking data structure that's safe to access
        // during teardown. The wrapper_cache.deinit loop already checks
        // isCleanupStarted() before calling gc.onObjectFreed.
        if (self.is_tearing_down) {
            return false;
        }

        if (self.cache.get(instance)) |entry| {
            // Mark as already cleaned - deinit will skip onObjectFreed
            entry.instance_already_cleaned = true;
            // The instance is gone, its wrapper not: script may still hold
            // it. Weak from here, whatever held it before (a node's tree did,
            // while it had a parent) - its weak callback, which skips an
            // instance whose cleanup started, frees the storage the teardown
            // left (releaseStorage). It used to be held strongly until the
            // page ended, a wrapper and an instance a torn-down node, and with
            // it everything it reaches: gc_bench retained both for every
            // `void div.attachShadow().appendChild(span)`, and a removed
            // frame whose torn-down nodes' wrappers were held could never be
            // collected.
            if (entry.strong) {
                armWeak(entry);
                entry.strong = false;
            }
            return true;
        }
        return false;
    }

    /// Remove a specific entry from the cache
    ///
    /// Removes the entry completely, disposing the V8 handle.
    /// Use markAsCleanedUp() instead if still in JS execution context.
    ///
    /// ## Parameters
    /// - instance: The Zig instance to remove from cache
    ///
    /// ## Returns
    /// true if entry was found and removed, false if not in cache
    pub fn remove(self: *Self, instance: *runtime.Instance) bool {
        if (self.cache.fetchRemove(instance)) |kv| {
            const entry = kv.value;

            // Clear weak callback first to prevent it from firing
            v8.v8_Global_ClearWeak(@ptrCast(entry.wrapper));

            // Dispose the Global<Object>* handle
            disposeEntryWrapper(entry);

            // Free the CacheEntry
            self.allocator.destroy(entry);

            return true;
        }
        return false;
    }

    /// Get cache statistics
    ///
    /// Returns the number of cached wrappers.
    /// Useful for debugging and monitoring.
    pub fn size(self: *const Self) usize {
        return self.cache.count();
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "WrapperCache - init and deinit" {
    // Mock V8 Context (just a dummy pointer for testing)
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    try testing.expectEqual(@as(usize, 0), cache.size());
}

test "WrapperCache - get returns null when empty" {
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    // Mock instance
    var dummy_instance: runtime.Instance = undefined;

    const result = cache.get(&dummy_instance);
    try testing.expectEqual(@as(?*v8.Object, null), result);
}

test "WrapperCache - set and get basic operation" {
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    // Mock instance and wrapper
    var dummy_instance: runtime.Instance = undefined;
    var dummy_wrapper: u64 = 0xDEADBEEF;
    const wrapper: *v8.Object = @ptrCast(&dummy_wrapper);

    // Mock isolate
    var dummy_isolate: u32 = 99;
    const isolate: *v8.Isolate = @ptrCast(&dummy_isolate);

    // NOTE: This test will fail when run with actual V8 because v8_Global_SetWeak
    // expects a real Global handle. This is a structural test only.
    // Actual integration testing requires V8 runtime.

    // Set wrapper in cache
    try cache.set(&dummy_instance, wrapper, isolate);

    // Get wrapper from cache
    const cached = cache.get(&dummy_instance);
    try testing.expect(cached != null);
    try testing.expectEqual(wrapper, cached.?);

    try testing.expectEqual(@as(usize, 1), cache.size());
}

test "WrapperCache - clear removes all entries" {
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    // Mock instances and wrappers
    var instance1: runtime.Instance = undefined;
    var instance2: runtime.Instance = undefined;
    var wrapper1: u64 = 0xDEAD;
    var wrapper2: u64 = 0xBEEF;
    var dummy_isolate: u32 = 99;
    const isolate: *v8.Isolate = @ptrCast(&dummy_isolate);

    try cache.set(&instance1, @ptrCast(&wrapper1), isolate);
    try cache.set(&instance2, @ptrCast(&wrapper2), isolate);

    try testing.expectEqual(@as(usize, 2), cache.size());

    // Clear cache
    cache.clear();

    try testing.expectEqual(@as(usize, 0), cache.size());
    try testing.expectEqual(@as(?*v8.Object, null), cache.get(&instance1));
    try testing.expectEqual(@as(?*v8.Object, null), cache.get(&instance2));
}

test "WrapperCache - no memory leaks" {
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    // Allocate multiple entries
    var instances: [10]runtime.Instance = undefined;
    var wrappers: [10]u64 = undefined;
    var dummy_isolate: u32 = 99;
    const isolate: *v8.Isolate = @ptrCast(&dummy_isolate);

    for (&instances, &wrappers) |*inst, *wrap| {
        wrap.* = 0xDEADBEEF;
        try cache.set(inst, @ptrCast(wrap), isolate);
    }

    try testing.expectEqual(@as(usize, 10), cache.size());

    // deinit() should clean up all entries without leaking
}

test "WrapperCache - remove specific entry" {
    var dummy_context: u32 = 42;
    const context: *v8.Context = @ptrCast(&dummy_context);

    var cache = try WrapperCache.init(testing.allocator, context);
    defer cache.deinit();

    // Mock instances and wrappers
    var instance1: runtime.Instance = undefined;
    var instance2: runtime.Instance = undefined;
    var instance3: runtime.Instance = undefined;
    var wrapper1: u64 = 0xDEAD;
    var wrapper2: u64 = 0xBEEF;
    var wrapper3: u64 = 0xCAFE;
    var dummy_isolate: u32 = 99;
    const isolate: *v8.Isolate = @ptrCast(&dummy_isolate);

    try cache.set(&instance1, @ptrCast(&wrapper1), isolate);
    try cache.set(&instance2, @ptrCast(&wrapper2), isolate);
    try cache.set(&instance3, @ptrCast(&wrapper3), isolate);

    try testing.expectEqual(@as(usize, 3), cache.size());

    // Remove middle entry
    const removed = cache.remove(&instance2);
    try testing.expect(removed);
    try testing.expectEqual(@as(usize, 2), cache.size());

    // Verify correct entries remain
    try testing.expect(cache.get(&instance1) != null);
    try testing.expectEqual(@as(?*v8.Object, null), cache.get(&instance2)); // Removed
    try testing.expect(cache.get(&instance3) != null);

    // Remove non-existent entry
    const removed_again = cache.remove(&instance2);
    try testing.expect(!removed_again);
    try testing.expectEqual(@as(usize, 2), cache.size());
}
