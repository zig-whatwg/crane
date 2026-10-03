//! The engine protocol's traced edges (design 4.12, "Platform objects"), as
//! V8 draws them: `traceChild`, `traceValue`, `tracedValue` and
//! `forgetTracedChild`.
//!
//! Blink keeps a platform object's children alive by TRACING them from the
//! owner (LocalDOMWindow::Trace visits navigator_, TreeScope::Trace visits
//! selection_); a child is then reachable exactly while its owner is, and an
//! owner and child that refer to each other still die together. V8 offers the
//! same edge to an embedder without a C++ heap: a private property on the
//! owner's wrapper holding the child's wrapper. Script cannot see a private
//! property, the collector traces it like any other, and it is no root - the
//! difference from the strong Global a `same_object.Pin` holds, which keeps
//! the child (and through its map, its realm) alive whatever becomes of the
//! owner. The binding already draws this edge for the generated [SameObject]
//! caches (interface.zig, `recordSameObjectEdge`).
//!
//! The edge needs the owner's wrapper to live as long as the owner. A Window's
//! wrapper is its realm's global object - and that is where a Window's edges
//! hang, never on its WindowProxy: a navigation hands the proxy to the next
//! Window (createWindowRealm, `.window_proxy_of`), and a private property set
//! through it lands on whichever global object it reaches now
//! (LookupIterator::GetStoreTarget), where the old Window's edge in a slot
//! would replace the new Window's.
//!
//! An owner script has not seen yet gets no wrapper here (`holderOf`): its
//! edges wait, the child held strongly, in its realm's wrapper cache, which
//! draws them on the wrapper when the binding makes it - a constructor's
//! `this` or a dispatched event's first wrap.

const std = @import("std");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const support = @import("protocol_support.zig");
const protocol_realms = @import("protocol_realms.zig");
const WrapperCache = @import("wrapper_cache.zig").WrapperCache;

const Instance = engine.Instance;
const TracedSlot = engine.TracedSlot;

/// The private key of `slot`: one namespace, apart from the binding's
/// "crane:SameObject:" edges. Null when the name does not fit (no edge rather
/// than a truncated key two slots could share).
fn keyOf(buffer: []u8, slot: TracedSlot) ?[]const u8 {
    return std.fmt.bufPrint(buffer, "crane:traced:{s}", .{slot.name}) catch null;
}

/// What an owner's edges hang from.
const Holder = union(enum) {
    /// A Window's global object, or an ordinary owner's wrapper: a Global
    /// the caller releases (v8_Global_Dispose).
    object: *ffi.Value,
    /// An owner script has not seen yet (no wrapper in its realm): its edges
    /// wait in its realm's wrapper cache for the wrapper (`deferEdge`).
    unwrapped: *WrapperCache,
    /// Nothing to hang an edge from (a Window whose global is gone, an owner
    /// whose realm has no cache).
    none,
};

/// Where `owner`'s edges hang. Never makes a wrapper: an owner's wrapper
/// made here, before script has seen the owner, is what the collector would
/// then free the owner with - a Zig-made event before its dispatch - and a
/// constructor's `this`, cached only once the constructor returns, would
/// replace it, edges and all. A Window's wrapper is its global object, which
/// lives with its realm.
fn holderOf(owner: *Instance) Holder {
    switch (protocol_realms.tracedEdgeHolderOfWindow(owner)) {
        .global_object => |global| return .{ .object = global },
        .gone => return .none,
        .not_a_realm_window => {},
    }
    const storage = owner.ctx.getV8WrapperCacheStorage() orelse return .none;
    const cache: *WrapperCache = @ptrCast(@alignCast(storage));
    if (cache.is_tearing_down) return .none;
    // The wrapper the owner's realm already has: the cache's handle,
    // BORROWED, so cloned for the caller to release like the others.
    const cached = cache.get(owner) orelse return .{ .unwrapped = cache };
    const wrapper = ffi.v8_Global_Clone(@ptrCast(cached)) orelse return .none;
    if (!ffi.v8_Value_IsObject(wrapper)) {
        ffi.v8_Global_Dispose(wrapper);
        return .none;
    }
    return .{ .object = wrapper };
}

/// engine.traceChild: a private property on `owner`'s wrapper - its global
/// object, for a Window - holding `child`'s wrapper, made in its relevant
/// realm if script has not seen it. An owner with no wrapper yet keeps the
/// child strongly in its realm's wrapper cache until it gets one.
pub fn traceChild(owner: *Instance, child: *Instance, slot: TracedSlot) void {
    var buffer: [128]u8 = undefined;
    const key = keyOf(&buffer, slot) orelse return;
    // An owner whose realm ended has no wrapper left to hang an edge from.
    if (owner.ctx.engine_ctx == null) return;
    // The owner's realm, entered: SetPrivate needs a context, and the edge is
    // the owner's.
    const entered = support.enter(owner.ctx) catch return;
    defer entered.leave();
    // Both wrappers are held for the length of the call: the child's first,
    // so nothing made below can collect it.
    const child_wrapper = support.relevantWrapper(entered.isolate, child) catch return;
    if (!ffi.v8_Value_IsObject(child_wrapper)) {
        ffi.v8_Global_Dispose(child_wrapper);
        return;
    }
    switch (holderOf(owner)) {
        .object => |holder| {
            defer ffi.v8_Global_Dispose(holder);
            defer ffi.v8_Global_Dispose(child_wrapper);
            ffi.v8_Object_SetPrivateRef(@ptrCast(holder), key.ptr, @intCast(key.len), child_wrapper);
        },
        // The cache takes the child's Global over, on failure too.
        .unwrapped => |cache| cache.deferEdge(owner, key, child_wrapper) catch {},
        .none => ffi.v8_Global_Dispose(child_wrapper),
    }
}

/// engine.traceValue: a private property on `owner`'s wrapper - its global
/// object, for a Window - holding `value` (a platform object as its wrapper
/// in its relevant realm), in `traceChild`'s namespace. An owner with no
/// wrapper yet keeps the value strongly in its realm's wrapper cache until it
/// gets one, as `traceChild` does - and `tracedValue` reads it there.
pub fn traceValue(owner: *Instance, value: engine.JSValue, slot: TracedSlot) void {
    var buffer: [128]u8 = undefined;
    const key = keyOf(&buffer, slot) orelse return;
    if (owner.ctx.engine_ctx == null) return;
    const entered = support.enter(owner.ctx) catch return;
    defer entered.leave();
    // Held for the length of the call, so nothing made below collects it.
    const held = support.ownGlobal(entered, value) catch return;
    switch (holderOf(owner)) {
        .object => |holder| {
            defer ffi.v8_Global_Dispose(holder);
            defer ffi.v8_Global_Dispose(held);
            ffi.v8_Object_SetPrivateRef(@ptrCast(holder), key.ptr, @intCast(key.len), held);
        },
        // The cache takes the Global over, on failure too.
        .unwrapped => |cache| cache.deferEdge(owner, key, held) catch {},
        .none => ffi.v8_Global_Dispose(held),
    }
}

/// engine.tracedValue: the private property `traceValue` set on `owner`'s
/// wrapper, or the value waiting in its realm's wrapper cache for that
/// wrapper; null when there is neither. Never makes a wrapper.
pub fn tracedValue(owner: *Instance, slot: TracedSlot) ?engine.Owned {
    var buffer: [128]u8 = undefined;
    const key = keyOf(&buffer, slot) orelse return null;
    if (owner.ctx.engine_ctx == null) return null;
    const entered = support.enter(owner.ctx) catch return null;
    defer entered.leave();
    switch (holderOf(owner)) {
        .object => |holder| {
            defer ffi.v8_Global_Dispose(holder);
            const value = ffi.v8_Object_GetPrivateRef(@ptrCast(holder), key.ptr, @intCast(key.len)) orelse return null;
            return support.owned(value);
        },
        .unwrapped => |cache| {
            const waiting = cache.deferredEdge(owner, key) orelse return null;
            return support.owned(ffi.v8_Global_Clone(waiting) orelse return null);
        },
        .none => return null,
    }
}

/// engine.forgetTracedChild: the edge waiting for `owner`'s wrapper, if any,
/// is dropped - no engine call, only a handle released - and then, for an
/// owner that has a wrapper, the private property `traceChild` set in `slot`
/// is deleted. Never makes a wrapper.
///
/// An owner that may be freed unwrapped calls this from its teardown. That
/// teardown can run while the collector does (the owner's own wrapper was
/// collected); the wrapper cache removed the owner's entry before freeing it,
/// so the owner reads as unwrapped then, and nothing past the first step runs.
pub fn forgetTracedChild(owner: *Instance, slot: TracedSlot) void {
    var buffer: [128]u8 = undefined;
    const key = keyOf(&buffer, slot) orelse return;
    const storage = owner.ctx.getV8WrapperCacheStorage() orelse return;
    const cache: *WrapperCache = @ptrCast(@alignCast(storage));
    if (cache.is_tearing_down) return;
    cache.forgetDeferredEdge(owner, key);
    // An owner with no wrapper has no edge on one.
    if (cache.get(owner) == null) return;
    if (owner.ctx.engine_ctx == null) return;
    const entered = support.enter(owner.ctx) catch return;
    defer entered.leave();
    switch (holderOf(owner)) {
        .object => |holder| {
            defer ffi.v8_Global_Dispose(holder);
            ffi.v8_Object_DeletePrivateRef(@ptrCast(holder), key.ptr, @intCast(key.len));
        },
        .unwrapped, .none => {},
    }
}
