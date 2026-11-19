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
//! wrapper is its realm's global object, and a Window's edges hang from what
//! that object keeps: the retained store its GlobalAnchor traces
//! (realm_global.retainedStore; V8 >= 14 gives no handle to the global object
//! itself, crbug.com/333672197) - never the WindowProxy: a navigation hands the
//! proxy to the next Window (createWindowRealm, `.window_proxy_of`), and a
//! private property set through it lands on whichever global object it
//! reaches now (LookupIterator::GetStoreTarget), where the old Window's edge
//! in a slot would replace the new Window's.
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
    /// A Window's retained store, or an ordinary owner's wrapper: a Global
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
/// replace it, edges and all. A Window's edges hang from its realm's retained
/// store, which lives with its global object.
fn holderOf(owner: *Instance) Holder {
    switch (protocol_realms.tracedEdgeHolderOfWindow(owner)) {
        .retained_store => |store| return .{ .object = store },
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

/// engine.traceChild: a private property on `owner`'s wrapper - its retained
/// store, for a Window - holding `child`'s wrapper, made in its relevant
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

/// engine.traceValue: a private property on `owner`'s wrapper - its retained
/// store, for a Window - holding `value` (a platform object as its wrapper
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

/// `values` as the borrowed handles v8_Object_SetPrivateValues reads: an
/// engine handle as it is, anything else - a platform object (its wrapper in
/// its relevant realm), a primitive - as a Global of this list's own,
/// released with it. A list of up to 16 needs no allocation.
const HandleList = struct {
    inline_handles: [16]?*ffi.Value = undefined,
    heap: ?[]?*ffi.Value = null,
    /// Which handles are this list's own (bit i: handles[i]); a list longer
    /// than 64 owns its handles through `heap_owned`.
    owned_bits: u64 = 0,
    heap_owned: ?[]bool = null,
    len: usize = 0,

    const allocator = std.heap.c_allocator;

    fn handles(self: *const HandleList) []const ?*ffi.Value {
        return if (self.heap) |all| all[0..self.len] else self.inline_handles[0..self.len];
    }

    fn of(self: *HandleList, entered: anytype, values: []const engine.JSValue) error{ OutOfMemory, OperationFailed }!void {
        const slots: []?*ffi.Value = if (values.len <= self.inline_handles.len)
            self.inline_handles[0..values.len]
        else blk: {
            const all = try allocator.alloc(?*ffi.Value, values.len);
            self.heap = all;
            if (values.len > 64) {
                const owned = allocator.alloc(bool, values.len) catch return error.OutOfMemory;
                @memset(owned, false);
                self.heap_owned = owned;
            }
            break :blk all;
        };
        for (values, slots, 0..) |value, *slot, i| {
            if (support.handleOf(value)) |handle| {
                slot.* = handle;
            } else {
                slot.* = support.ownGlobal(entered, value) catch {
                    self.len = i;
                    return error.OperationFailed;
                };
                self.markOwned(i);
            }
            self.len = i + 1;
        }
    }

    fn markOwned(self: *HandleList, i: usize) void {
        if (self.heap_owned) |owned| {
            owned[i] = true;
        } else self.owned_bits |= @as(u64, 1) << @intCast(i);
    }

    fn isOwned(self: *const HandleList, i: usize) bool {
        if (self.heap_owned) |owned| return owned[i];
        return self.owned_bits & (@as(u64, 1) << @intCast(i)) != 0;
    }

    fn release(self: *HandleList) void {
        for (self.handles(), 0..) |handle, i| {
            if (!self.isOwned(i)) continue;
            if (handle) |h| ffi.v8_Global_Dispose(h);
        }
        if (self.heap) |all| allocator.free(all);
        if (self.heap_owned) |owned| allocator.free(owned);
        self.* = .{};
    }
};

/// engine.traceValues: one private property on `owner`'s wrapper - its
/// retained store, for a Window - holding exactly `values`: the value, or an
/// Array of them (v8_Object_SetPrivateValues), in `traceChild`'s namespace.
/// An owner with no wrapper yet keeps them as ONE value strongly in its
/// realm's wrapper cache until it gets one (`deferEdge`, which draws the
/// same property then), as `traceValue` does; an empty set ends that waiting
/// edge. False where nothing can hang an edge: the owner's realm ended, its
/// cache is tearing down, a Window whose global is gone.
pub fn traceValues(owner: *Instance, values: []const engine.JSValue, slot: TracedSlot) bool {
    var buffer: [128]u8 = undefined;
    const key = keyOf(&buffer, slot) orelse return false;
    if (owner.ctx.engine_ctx == null) return false;
    const entered = support.enter(owner.ctx) catch return false;
    defer entered.leave();
    var list: HandleList = .{};
    defer list.release();
    list.of(entered, values) catch return false;
    const handles = list.handles();
    switch (holderOf(owner)) {
        .object => |holder| {
            defer ffi.v8_Global_Dispose(holder);
            return ffi.v8_Object_SetPrivateValues(@ptrCast(holder), key.ptr, @intCast(key.len), handles.ptr, handles.len);
        },
        .unwrapped => |cache| {
            if (handles.len == 0) {
                cache.forgetDeferredEdge(owner, key);
                return true;
            }
            const kept = ffi.v8_Values_GatherTraced(handles.ptr, handles.len) orelse return false;
            // The cache takes the Global over, on failure too.
            cache.deferEdge(owner, key, kept) catch return false;
            return true;
        },
        .none => return false,
    }
}

/// engine.holdWeakly: the hold's Global becomes a phantom handle V8 resets
/// when it collects the value (v8_Global_HoldWeakly). A hold that is no
/// engine handle (undefined) holds nothing to weaken.
pub fn holdWeakly(hold: engine.Owned) void {
    const handle = support.handleOf(hold.value) orelse return;
    ffi.v8_Global_HoldWeakly(handle);
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
