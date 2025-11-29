//! Implementation for DOMRectList interface
//!
//! CSSOM View Module - DOMRectList
//! Spec: https://drafts.csswg.org/cssom-view/#domrectlist
//!
//! A list of DOMRect objects returned by methods like getClientRects().

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DOMRectList = interfaces.DOMRectList;

pub const State = DOMRectList.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Internal state storing list of DOMRect instances
pub const InternalState = struct {
    rects: std.ArrayListUnmanaged(*runtime.Instance),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .rects = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Note: We don't own the rect instances, just references to them
        self.rects.deinit(self.allocator);
    }
};

/// Get state from instance
fn getState(instance: *runtime.Instance) *State {
    return instance.getState(State);
}

/// Get internal state from state
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = getState(instance);
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Initialize an empty DOMRectList
pub fn initEmpty(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try init(allocator, State, &DOMRectList.vtable, ctx);
    errdefer deinit(instance);

    // Allocate and initialize internal state
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state in State
    const state = getState(instance);
    state.own._internal = internal;
    state.own.length = 0;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.deinit();
    }
    runtime.Instance.deinit(instance);
}

/// Getter for length
/// Spec: https://drafts.csswg.org/cssom-view/#dom-domrectlist-length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const state = getState(instance);
    return state.own.length;
}

/// Operation: item
/// Spec: https://drafts.csswg.org/cssom-view/#dom-domrectlist-item
/// Returns the DOMRect at the given index, or null if out of bounds
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.NotImplemented;

    if (index >= internal.rects.items.len) {
        // Out of bounds - return null (NotImplemented represents null)
        return error.NotImplemented;
    }

    return internal.rects.items[index];
}

/// Add a rect to the list (internal helper)
pub fn addRect(instance: *runtime.Instance, rect: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.OutOfMemory;
    try internal.rects.append(internal.allocator, rect);

    // Update length in state
    const state = getState(instance);
    state.own.length = @intCast(internal.rects.items.len);
}
