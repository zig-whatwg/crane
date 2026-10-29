//! Fetch 5.6: the deferred fetch result's activated boolean.
//!
//! The result owns a hold on the fetch-group owner's activation cell. The
//! record and the result can end in either order; neither holds a realm or
//! a borrowed Request wrapper. The cell contract is dom.deferred_fetches.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const deferred = @import("dom").deferred_fetches;

pub const State = interfaces.FetchLaterResult.State;
/// The generated private-state pointer is the cell itself: no extra block.
pub const InternalState = deferred.Activated;

/// FetchLater step 17 gives the result step 14's activated cell. Consumes
/// the result's hold ONLY on successful construction. With no cell, the
/// result starts false; it has no pending deferred request.
pub const construction_args = .{"deferred_activation"};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const state = instance.getState(State);
    state.own.activated = false;
    state.own._internal = if (@hasField(@TypeOf(args), "deferred_activation")) args.deferred_activation else null;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |cell| cell.release();
    state.own._internal = null;
}

/// The getter returns the activated value shared with the deferred record.
pub fn get_activated(instance: *runtime.Instance) anyerror!bool {
    const cell = instance.getState(State).own._internal orelse return false;
    return cell.value;
}
