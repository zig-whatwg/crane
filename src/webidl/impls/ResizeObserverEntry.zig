//! Implementation for ResizeObserverEntry interface
//!
//! Spec: https://drafts.csswg.org/resize-observer-1/#resize-observer-entry-interface
//!
//! An entry is made by its observer ("create and populate a
//! ResizeObserverEntry", ResizeObserver.zig) with its target, its content
//! rect and the three box sizes as the observer calculated them. What its
//! getters hand out it KEEPS, as IntersectionObserverEntry does (lane
//! refcount8's rules):
//!
//! - The target is held (node_holds.MemberHold) from the entry's creation.
//! - contentRect is a DOMRectReadOnly made for the entry, kept from the
//!   entry's wrapper by an edge drawn at its first read; one never read is
//!   the entry's to free.
//! - Each FrozenArray<ResizeObserverSize> is made at its first read, in the
//!   entry's realm, and kept from the entry's wrapper (engine.traceValue), so
//!   every read returns the same array.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const node_holds = @import("dom").node_holds;
const same_object = @import("dom").same_object;
const ResizeObserverEntry = interfaces.ResizeObserverEntry;

pub const State = ResizeObserverEntry.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// A box size: "calculate box size"'s inline and block lengths.
const Size = @import("dom").resize_observations.Size;

/// The three sizes an entry reports, in the order `InternalState.sizes`
/// keeps them.
pub const Box = enum(u2) { border_box, content_box, device_pixel_content_box };

/// What an entry is made with (`interfaces.ResizeObserverEntry.initWith`):
/// its target (held from here), its content rect (the entry's from here) and
/// its sizes.
pub const construction_args = .{ "target", "content_rect", "border_box", "content_box", "device_pixel_content_box" };

const target_slot: engine.TracedSlot = .{ .name = "target" };
const array_slots = [3]engine.TracedSlot{
    .{ .name = "borderBoxSize" },
    .{ .name = "contentBoxSize" },
    .{ .name = "devicePixelContentBoxSize" },
};

pub const InternalState = struct {
    target: node_holds.MemberHold = .{},
    rect: ?*runtime.Instance = null,
    rect_generation: u64 = 0,
    rect_edge: same_object.Traced = .{ .slot = .{ .name = "contentRect" } },
    sizes: [3]Size = .{ .{}, .{}, .{} },
    /// Each size array was made (and is kept in its slot).
    arrays_made: [3]bool = .{ false, false, false },

    /// runtime.VTable.trace_held_nodes: the target, in the collector's atomic
    /// pause (Blink's ResizeObserverEntry::Trace visits target_). A queued
    /// entry, unwrapped, is traced from its observer.
    pub fn traceHeldNodes(instance: *runtime.Instance, tracer: *engine.Tracer) void {
        const self = getInternal(instance) orelse return;
        self.target.trace(tracer);
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The entry's own construction (`construction_args`).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = .{ allocator, StateType };
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    instance.getState(State).own._internal = internal;
    const Args = @TypeOf(args);
    if (@hasField(Args, "border_box")) internal.sizes[@backingInt(Box.border_box)] = args.border_box;
    if (@hasField(Args, "content_box")) internal.sizes[@backingInt(Box.content_box)] = args.content_box;
    if (@hasField(Args, "device_pixel_content_box")) internal.sizes[@backingInt(Box.device_pixel_content_box)] = args.device_pixel_content_box;
    if (@hasField(Args, "content_rect")) {
        internal.rect = args.content_rect;
        internal.rect_generation = runtime.SlabAllocator.generationOf(args.content_rect);
    }
    if (@hasField(Args, "target")) internal.target.take(instance, args.target, target_slot);
}

/// The entry's own teardown: the target's hold goes; a rect script has seen
/// is its wrapper's (the edge goes), one it never saw goes with the entry;
/// the size arrays' slots are forgotten.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.target.release(instance, target_slot);
    if (internal.rect_edge.drawn) {
        internal.rect_edge.release(instance);
    } else if (internal.rect) |rect| {
        rect.releaseIfUnwrapped(internal.rect_generation);
    }
    for (internal.arrays_made, 0..) |made, i| {
        if (made) engine.forgetTracedChild(instance, array_slots[i]);
    }
    runtime.arenaOf(instance).destroy(InternalState, internal);
    state.own._internal = null;
}

/// Getter for target: the observed Element, which the entry holds. A target
/// freed under it (its realm's teardown) reads as an error, never as the
/// freed slot.
pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.target.get() orelse error.InvalidStateError;
}

/// Getter for contentRect: the target's content rect when the callback was
/// invoked, kept from the entry's wrapper from its first read.
pub fn get_contentRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const rect = internal.rect orelse return error.InvalidStateError;
    if (!internal.rect_edge.drawn) internal.rect_edge.hold(instance, rect);
    return rect;
}

/// The FrozenArray<ResizeObserverSize> of `which`: one ResizeObserverSize
/// (the spec's single fragment), made at the first read and kept.
fn sizeArray(instance: *runtime.Instance, which: Box) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const index = @backingInt(which);
    if (internal.arrays_made[index]) {
        if (engine.tracedValue(instance, array_slots[index])) |array| return array.take();
    }
    const size = internal.sizes[index];
    const object = try interfaces.ResizeObserverSize.initWith(instance.ctx.allocator, instance.ctx, .{
        .inline_size = size.inline_size,
        .block_size = size.block_size,
    });
    const generation = runtime.SlabAllocator.generationOf(object);
    const array = engine.createFrozenArray(instance.ctx, &.{runtime.JSValue{ .instance = object }}) catch |err| {
        object.releaseIfUnwrapped(generation);
        return err;
    };
    engine.traceValue(instance, array.value, array_slots[index]);
    internal.arrays_made[index] = true;
    return array.take();
}

/// Getter for borderBoxSize.
pub fn get_borderBoxSize(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return sizeArray(instance, .border_box);
}

/// Getter for contentBoxSize.
pub fn get_contentBoxSize(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return sizeArray(instance, .content_box);
}

/// Getter for devicePixelContentBoxSize.
pub fn get_devicePixelContentBoxSize(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return sizeArray(instance, .device_pixel_content_box);
}
