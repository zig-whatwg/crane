//! Implementation for CompositionEvent interface
//!
//! Spec: https://w3c.github.io/uievents/#interface-compositionevent
//!
//! ```idl
//! [Exposed=Window]
//! interface CompositionEvent : UIEvent {
//!   constructor(DOMString type, optional CompositionEventInit eventInitDict = {});
//!   readonly attribute USVString data;
//! };
//! dictionary CompositionEventInit : UIEventInit {
//!   DOMString data = "";
//! };
//! partial interface CompositionEvent {  // legacy
//!   undefined initCompositionEvent(DOMString typeArg, optional boolean bubblesArg = false,
//!       optional boolean cancelableArg = false, optional WindowProxy? viewArg = null,
//!       optional DOMString dataArg = "");
//! };
//! ```

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const EventImpl = @import("Event.zig");
const UIEventImpl = @import("UIEvent.zig");
const CompositionEvent = interfaces.CompositionEvent;

pub const State = CompositionEvent.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Owned.
    data: []u8 = &.{},

    fn setData(self: *InternalState, value: []const u8) !void {
        const copy = try self.allocator.dupe(u8, value);
        self.allocator.free(self.data);
        self.data = copy;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance: the UIEvent part, then CompositionEvent's own state.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try UIEventImpl.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its own state, then the UIEvent part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.allocator.free(internal.data);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    UIEventImpl.deinit(instance);
}

/// Constructor: inner event creation steps, UIEventInit's members, then data.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.CompositionEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &CompositionEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.CompositionEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{ .base = .{} } };
    try EventImpl.innerEventCreationSteps(instance, @"type", dict.base.base);
    UIEventImpl.initializeMembers(instance, dict.base);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.setData(if (dict.data) |d| d.asSlice() else "");
    return instance;
}

/// Getter for data. A copy: the binding frees what a USVString getter
/// returns.
pub fn get_data(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return "";
    if (internal.data.len == 0) return "";
    return instance.ctx.allocator.dupe(u8, internal.data);
}

/// Operation: initCompositionEvent (legacy)
/// Spec: https://w3c.github.io/uievents/#dom-compositionevent-initcompositionevent
///
/// "If this's dispatch flag is set, return; initialize this with typeArg,
/// bubblesArg and cancelableArg; set view to viewArg and data to dataArg."
pub fn call_initCompositionEvent(instance: *runtime.Instance, typeArg: runtime.DOMString, bubblesArg: webidl.Opt(bool), cancelableArg: webidl.Opt(bool), viewArg: webidl.Opt(?typedefs.WindowProxy), dataArg: webidl.Opt(runtime.DOMString)) anyerror!void {
    if (EventImpl.getDispatchFlag(instance)) return;
    try UIEventImpl.call_initUIEvent(instance, typeArg, bubblesArg, cancelableArg, if (viewArg.was_passed) webidl.Opt(?*runtime.Instance).passed(viewArg.value) else webidl.Opt(?*runtime.Instance).notPassed(), webidl.Opt(i32).notPassed());
    const internal = getInternal(instance) orelse return;
    try internal.setData(if (dataArg.was_passed) dataArg.value.asSlice() else "");
}
