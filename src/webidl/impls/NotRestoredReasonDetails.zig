//! Implementation for NotRestoredReasonDetails interface
//!
//! HTML 7.2.8: one reason a document was not restored from the back/forward
//! cache. Its backing struct, a "not restored reason details", is a reason
//! string; the object copies the reason it is made with ("create a
//! NotRestoredReasonDetails object", NotRestoredReasons' reasons array).
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#notrestoredreasondetails

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const NotRestoredReasonDetails = interfaces.NotRestoredReasonDetails;
const Reason = @import("html_core").navigation.not_restored_reasons.Reason;

pub const State = NotRestoredReasonDetails.State;

pub const ImplError = error{
    NotImplemented,
};

/// The backing struct's reason, given at construction.
pub const construction_args = .{"reason"};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    reason: Reason,
};

/// "Create a NotRestoredReasonDetails object" steps 1-2: its backing struct
/// is the reason it is made with (a NotRestoredReasonDetails no backing
/// struct gave is "masked", the generic reason).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const reason: Reason = if (@hasField(@TypeOf(args), "reason")) args.reason else .masked;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .reason = reason };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

fn reasonOf(instance: *runtime.Instance) !Reason {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    const internal = state.own._internal orelse return error.InvalidStateError;
    return internal.reason;
}

/// Getter for reason: "this's backing struct's reason".
pub fn get_reason(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try reasonOf(instance)).name());
}

/// Operation: toJSON ([Default]): its reason.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.NotRestoredReasonDetails.NotRestoredReasonDetailsToJSON {
    return .{ .reason = runtime.DOMString.initInterned((try reasonOf(instance)).name()) };
}
