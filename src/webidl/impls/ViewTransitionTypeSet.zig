//! CSS View Transitions 2 §9: `interface ViewTransitionTypeSet {
//! setlike<DOMString>; }` - a view transition's active types. The set
//! entries are this impl's (a webidl.setlike.Strings); their setlike members
//! are the binding's (WebIDL 3.7.12), which reaches them through the
//! generated `setlikeEntries`, as CustomStateSet's.
//!
//! Spec: https://drafts.csswg.org/css-view-transitions-2/#viewtransitiontypeset

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");

pub const State = interfaces.ViewTransitionTypeSet.State;

pub const InternalState = struct {
    /// The active types ("an ordered set of strings").
    values: webidl.setlike.Strings,
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .values = .init(allocator) };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    const allocator = internal.values.allocator;
    internal.values.deinit();
    allocator.destroy(internal);
}

/// The set entries (WebIDL 2.5.12), for the binding's setlike members; null
/// once the instance's state is gone.
pub fn setlikeEntries(instance: *runtime.Instance) ?*webidl.setlike.Strings {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return &internal.values;
}
