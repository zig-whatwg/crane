//! Implementation for TouchList interface (Touch Events, "TouchList
//! Interface"): an immutable list of Touch objects - a TouchEvent's
//! touches, targetTouches or changedTouches - fixed when it is made (its
//! construction argument `touches`).
//!
//! Lifetime, as FileList's: Blink's TouchList holds `HeapVector<Member<
//! Touch>> values_`, traced. Each Touch is kept by an edge from the list's
//! wrapper (engine.traceChild, one slot per index, "touch.<i>"); the pointer
//! kept beside it carries the touch's generation and realm (KeptInstance),
//! only the teardown net. The list never frees a Touch: a Touch's lifetime is
//! its wrapper's, or its native maker's.
//!
//! Spec: https://w3c.github.io/touch-events/#touchlist-interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const KeptInstance = dom.custom_elements.KeptInstance;
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const TouchList = interfaces.TouchList;

pub const State = TouchList.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
};

/// A list is made by its TouchEvent with its touches.
pub const construction_args = .{"touches"};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Each Touch, kept by the edge in slot "touch.<index>".
    touches: []KeptInstance,
};

/// The slot that keeps the touch at `index`.
fn touchSlot(buffer: []u8, index: usize) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "touch.{d}", .{index}) catch unreachable };
}

const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The construction chain's own steps: keep `args.touches` (each a Touch),
/// in order. A list made with no construction argument is empty.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const state = instance.stateAs(State) orelse return error.InvalidState;
    const source: []const *runtime.Instance = if (@hasField(@TypeOf(args), "touches")) args.touches else &.{};
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    const touches = try allocator.alloc(KeptInstance, source.len);
    for (source, touches) |touch, *kept| kept.* = KeptInstance.of(touch);
    internal.* = .{ .allocator = allocator, .touches = touches };
    state.own._internal = internal;
    for (source, 0..) |touch, index| {
        var buffer: [32]u8 = undefined;
        engine.traceChild(instance, touch, touchSlot(&buffer, index));
    }
}

/// The destruction chain's own part: the list's storage and the holds of an
/// unwrapped list (a collected one's edges went with its wrapper); never a
/// Touch.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.stateAs(State) orelse return;
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    for (0..internal.touches.len) |index| {
        var buffer: [32]u8 = undefined;
        engine.forgetTracedChild(instance, touchSlot(&buffer, index));
    }
    internal.allocator.free(internal.touches);
    internal.allocator.destroy(internal);
}

/// Getter for length: "the number of Touch objects in the list".
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return @intCast(internal.touches.len);
}

/// Operation: item - "the Touch at the specified index in the list or null
/// if the index is not less than the length of the list".
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    if (index >= internal.touches.len) return null;
    return internal.touches[index].get();
}
