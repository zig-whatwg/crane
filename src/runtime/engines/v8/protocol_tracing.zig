//! The engine protocol's traced edges (design 4.12, "Platform objects"), as
//! V8 draws them: `traceChild` and `forgetTracedChild`.
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

const std = @import("std");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const support = @import("protocol_support.zig");
const protocol_realms = @import("protocol_realms.zig");
const v8_engine = @import("engine.zig");

const Instance = engine.Instance;
const TracedSlot = engine.TracedSlot;

/// The private key of `slot`: one namespace, apart from the binding's
/// "crane:SameObject:" edges. Null when the name does not fit (no edge rather
/// than a truncated key two slots could share).
fn keyOf(buffer: []u8, slot: TracedSlot) ?[]const u8 {
    return std.fmt.bufPrint(buffer, "crane:traced:{s}", .{slot.name}) catch null;
}

/// What a Window's edges hang from, or an ordinary owner's wrapper: an
/// object, as a Global the caller releases (v8_Global_Dispose); null when
/// there is none to hang an edge from. `make`: whether an owner script has
/// not seen yet gets its wrapper now (traceChild) or answers null
/// (forgetTracedChild, which never makes one).
fn holderOf(isolate: *ffi.Isolate, owner: *Instance, comptime make: bool) ?*ffi.Value {
    switch (protocol_realms.tracedEdgeHolderOfWindow(owner)) {
        .global_object => |global| return global,
        .gone => return null,
        .not_a_realm_window => {},
    }
    const wrapper: *ffi.Value = if (make)
        support.relevantWrapper(isolate, owner) catch return null
    else blk: {
        // The wrapper the owner's realm already has: the cache's handle,
        // BORROWED, so cloned for the caller to release like the others.
        const cache = owner.ctx.getV8WrapperCacheStorage() orelse return null;
        const cached = v8_engine.v8GetWrapperForInstance(cache, cache, owner) orelse return null;
        break :blk ffi.v8_Global_Clone(@ptrCast(@alignCast(cached))) orelse return null;
    };
    if (!ffi.v8_Value_IsObject(wrapper)) {
        ffi.v8_Global_Dispose(wrapper);
        return null;
    }
    return wrapper;
}

/// engine.traceChild: a private property on `owner`'s wrapper - its global
/// object, for a Window - holding `child`'s wrapper. Each wrapper is made, if
/// script has not seen it, in its own relevant realm.
pub fn traceChild(owner: *Instance, child: *Instance, slot: TracedSlot) void {
    var buffer: [128]u8 = undefined;
    const key = keyOf(&buffer, slot) orelse return;
    // An owner whose realm ended has no wrapper left to hang an edge from.
    if (owner.ctx.engine_ctx == null) return;
    // The owner's realm, entered: SetPrivate needs a context, and the edge is
    // the owner's.
    const entered = support.enter(owner.ctx) catch return;
    defer entered.leave();
    const holder = holderOf(entered.isolate, owner, true) orelse return;
    defer ffi.v8_Global_Dispose(holder);
    const child_wrapper = support.relevantWrapper(entered.isolate, child) catch return;
    defer ffi.v8_Global_Dispose(child_wrapper);
    if (!ffi.v8_Value_IsObject(child_wrapper)) return;
    ffi.v8_Object_SetPrivateRef(@ptrCast(holder), key.ptr, @intCast(key.len), child_wrapper);
}

/// engine.forgetTracedChild: delete the private property `traceChild` set in
/// `slot`. Never makes a wrapper: an owner script has not seen has no edges.
pub fn forgetTracedChild(owner: *Instance, slot: TracedSlot) void {
    var buffer: [128]u8 = undefined;
    const key = keyOf(&buffer, slot) orelse return;
    if (owner.ctx.engine_ctx == null) return;
    const entered = support.enter(owner.ctx) catch return;
    defer entered.leave();
    const holder = holderOf(entered.isolate, owner, false) orelse return;
    defer ffi.v8_Global_Dispose(holder);
    ffi.v8_Object_DeletePrivateRef(@ptrCast(holder), key.ptr, @intCast(key.len));
}
