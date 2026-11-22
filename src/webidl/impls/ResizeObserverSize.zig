//! Implementation for ResizeObserverSize interface
//!
//! Spec: https://drafts.csswg.org/resize-observer-1/#resizeobserversize
//!
//! A box size its ResizeObserverEntry made ("calculate box size"): two
//! numbers, given at construction and read-only.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const ResizeObserverSize = interfaces.ResizeObserverSize;

pub const State = ResizeObserverSize.State;

pub const ImplError = error{
    NotImplemented,
};

/// What a size is made with (`interfaces.ResizeObserverSize.initWith`).
pub const construction_args = .{ "inline_size", "block_size" };

pub const InternalState = struct {
    inline_size: f64 = 0,
    block_size: f64 = 0,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The size's own construction: its two lengths.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = .{ allocator, StateType };
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    const Args = @TypeOf(args);
    if (@hasField(Args, "inline_size")) internal.inline_size = args.inline_size;
    if (@hasField(Args, "block_size")) internal.block_size = args.block_size;
    instance.getState(State).own._internal = internal;
}

/// The size's own teardown.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    runtime.arenaOf(instance).destroy(InternalState, internal);
    state.own._internal = null;
}

/// Getter for inlineSize: the box's length in the inline axis.
pub fn get_inlineSize(instance: *runtime.Instance) anyerror!f64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.inline_size;
}

/// Getter for blockSize: the box's length in the block axis.
pub fn get_blockSize(instance: *runtime.Instance) anyerror!f64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.block_size;
}
