//! Implementation for IntersectionObserverEntry interface
//!
//! Spec: https://w3c.github.io/IntersectionObserver/#intersection-observer-entry
//!
//! IntersectionObserverEntry objects provide information about a single
//! intersection change, including the time of the change, the intersection
//! rectangle, the bounding client rect, and whether the target is intersecting.
//!
//! What its getters hand out it KEEPS (lane refcount8, item 0). rootBounds,
//! boundingClientRect and intersectionRect are DOMRectReadOnly objects made
//! for the entry - by its constructor, or by its observer - and target is the
//! observed Element. They were raw pointers with no edge and no hold: script
//! read a rect, dropped it, a collection freed it with its wrapper, and the
//! next read wrapped a freed slot (the intermittent SIGSEGV under
//! PropertyGetterCallback -> instanceToV8 -> getTemplateForIsolate in
//! single-process runs of intersection-observer/). Blink's
//! IntersectionObserverEntry::Trace visits all four.
//!
//! - A rect is kept from the entry's wrapper by an edge (same_object.Traced),
//!   drawn at its first read: until then nothing but the entry can reach it,
//!   and an object nothing wrapped is never collected. A rect never handed
//!   out is the entry's to free in its teardown.
//! - The target is held (node_holds.MemberHold: a counted hold plus the keep
//!   of its opaque root) from the entry's creation: an observer's queued
//!   entry names a target script may drop and the collector free before the
//!   entry is ever delivered.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const engine = @import("engine");
const node_holds = @import("dom").node_holds;
const same_object = @import("same_object.zig");
const IntersectionObserverEntry = interfaces.IntersectionObserverEntry;

pub const State = IntersectionObserverEntry.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// What an entry is made with (`interfaces.IntersectionObserverEntry.initWith`):
/// its observer's computed values, or its constructor's init dictionary.
/// The rects are the entry's from here; `target` is held.
pub const construction_args = .{ "time", "root_bounds", "bounding_client_rect", "intersection_rect", "is_intersecting", "is_visible", "intersection_ratio", "target" };

/// The three rects, in the order `InternalState.rects` keeps them.
const Rect = enum(u2) { root_bounds, bounding_client_rect, intersection_rect };

const target_slot: engine.TracedSlot = .{ .name = "target" };

/// One rect the entry hands out: the edge that keeps it from the entry's
/// wrapper once script has seen it, and its slab generation, for the free of
/// one script never saw.
const KeptRect = struct {
    edge: same_object.Traced,
    generation: u64 = 0,
};

/// Internal state for IntersectionObserverEntry
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    rects: [3]KeptRect = .{
        .{ .edge = .{ .slot = .{ .name = "rootBounds" } } },
        .{ .edge = .{ .slot = .{ .name = "boundingClientRect" } } },
        .{ .edge = .{ .slot = .{ .name = "intersectionRect" } } },
    },
    target: node_holds.MemberHold = .{},
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return instance.getState(State).own._internal;
}

/// The rect `which` names in `state`, if any.
fn rectField(state: *State, which: Rect) ?*runtime.Instance {
    return switch (which) {
        .root_bounds => state.own.rootBounds,
        .bounding_client_rect => state.own.boundingClientRect,
        .intersection_rect => state.own.intersectionRect,
    };
}

/// The entry's own construction: its values, its rects and its target's
/// hold (`construction_args`). An entry made without them (`init`) has
/// nothing to keep until it is given some.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .allocator = allocator };
    const state = instance.getState(State);
    state.own._internal = internal;
    const Args = @TypeOf(args);
    if (@hasField(Args, "time")) state.own.time = args.time;
    if (@hasField(Args, "is_intersecting")) state.own.isIntersecting = args.is_intersecting;
    if (@hasField(Args, "is_visible")) state.own.isVisible = args.is_visible;
    if (@hasField(Args, "intersection_ratio")) state.own.intersectionRatio = args.intersection_ratio;
    if (@hasField(Args, "root_bounds")) state.own.rootBounds = args.root_bounds;
    if (@hasField(Args, "bounding_client_rect")) state.own.boundingClientRect = args.bounding_client_rect;
    if (@hasField(Args, "intersection_rect")) state.own.intersectionRect = args.intersection_rect;
    inline for (@typeInfo(Rect).@"enum".field_values) |field_value| {
        const which: Rect = @enumFromInt(field_value);
        const present = switch (which) {
            .root_bounds => @hasField(Args, "root_bounds"),
            .bounding_client_rect => @hasField(Args, "bounding_client_rect"),
            .intersection_rect => @hasField(Args, "intersection_rect"),
        };
        if (present) if (rectField(state, which)) |rect| {
            internal.rects[field_value].generation = runtime.SlabAllocator.generationOf(rect);
        };
    }
    if (@hasField(Args, "target")) {
        state.own.target = args.target;
        internal.target.take(instance, args.target, target_slot);
    }
}

/// The entry's own teardown. A rect script has seen is its wrapper's: the
/// edge goes (only the hold an unwrapped entry had is let go - the collector
/// may have freed the rect first, so it is not touched). A rect script never
/// saw had nothing but this entry, and goes with it. The target's hold goes.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.target.release(instance, target_slot);
    inline for (@typeInfo(Rect).@"enum".field_values) |field_value| {
        const kept = &internal.rects[field_value];
        if (kept.edge.drawn) {
            kept.edge.release(instance);
        } else if (kept.generation != 0) {
            if (rectField(state, @enumFromInt(field_value))) |rect| rect.releaseIfUnwrapped(kept.generation);
        }
    }
    runtime.arenaOf(instance).destroy(InternalState, internal);
    state.own._internal = null;
}

/// A rect, as its getter hands it out: kept from the entry's wrapper from its
/// first read.
fn handOut(instance: *runtime.Instance, which: Rect) ?*runtime.Instance {
    const state = instance.getState(State);
    const rect = rectField(state, which) orelse return null;
    if (getInternal(instance)) |internal| {
        const kept = &internal.rects[@intFromEnum(which)];
        if (!kept.edge.drawn) kept.edge.hold(instance, rect);
    }
    return rect;
}

/// A DOMRectReadOnly made from `init` in `ctx`, the constructor's way.
fn rectFrom(ctx: runtime.Context, init: dictionaries.DOMRectInit) !*runtime.Instance {
    return interfaces.DOMRectReadOnly.call_constructor(
        ctx,
        webidl.Opt(f64).passed(init.x orelse 0),
        webidl.Opt(f64).passed(init.y orelse 0),
        webidl.Opt(f64).passed(init.width orelse 0),
        webidl.Opt(f64).passed(init.height orelse 0),
    );
}

/// Constructor implementation
/// Creates an IntersectionObserverEntry from an IntersectionObserverEntryInit dictionary
///
/// Spec: https://w3c.github.io/IntersectionObserver/#dom-intersectionobserverentry-intersectionobserverentry
pub fn call_constructor(ctx: runtime.Context, intersectionObserverEntryInit: dictionaries.IntersectionObserverEntryInit) !*runtime.Instance {
    const init = intersectionObserverEntryInit;
    // Note: Per IDL, rootBounds is "required DOMRectInit?" - required but nullable type
    // However our codegen doesn't handle nullable types in dictionaries correctly,
    // so we always create the rect.
    const root_bounds = try rectFrom(ctx, init.rootBounds);
    const root_generation = runtime.SlabAllocator.generationOf(root_bounds);
    errdefer root_bounds.releaseIfUnwrapped(root_generation);
    const bounding_client_rect = try rectFrom(ctx, init.boundingClientRect);
    const bounding_generation = runtime.SlabAllocator.generationOf(bounding_client_rect);
    errdefer bounding_client_rect.releaseIfUnwrapped(bounding_generation);
    const intersection_rect = try rectFrom(ctx, init.intersectionRect);
    const intersection_generation = runtime.SlabAllocator.generationOf(intersection_rect);
    errdefer intersection_rect.releaseIfUnwrapped(intersection_generation);
    return IntersectionObserverEntry.initWith(ctx.allocator, ctx, .{
        .time = init.time,
        .root_bounds = @as(?*runtime.Instance, root_bounds),
        .bounding_client_rect = bounding_client_rect,
        .intersection_rect = intersection_rect,
        .is_intersecting = init.isIntersecting,
        .is_visible = init.isVisible,
        .intersection_ratio = init.intersectionRatio,
        .target = init.target,
    });
}

/// Getter for time
/// Returns the time at which the intersection change occurred
pub fn get_time(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    const state = instance.getState(State);
    return state.own.time;
}

/// Getter for rootBounds
/// Returns the root intersection rectangle, or null if the root is implicit and cross-origin
pub fn get_rootBounds(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return handOut(instance, .root_bounds);
}

/// Getter for boundingClientRect
/// Returns the target's bounding client rectangle
pub fn get_boundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return handOut(instance, .bounding_client_rect) orelse error.InvalidStateError;
}

/// Getter for intersectionRect
/// Returns the intersection rectangle between target and root
pub fn get_intersectionRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return handOut(instance, .intersection_rect) orelse error.InvalidStateError;
}

/// Getter for isIntersecting
/// Returns true if the target is intersecting with the root
pub fn get_isIntersecting(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.isIntersecting;
}

/// Getter for isVisible
/// Returns true if the target is visible (only meaningful when trackVisibility is enabled)
pub fn get_isVisible(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.isVisible;
}

/// Getter for intersectionRatio
/// Returns the ratio of intersectionRect area to boundingClientRect area
pub fn get_intersectionRatio(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.intersectionRatio;
}

/// Getter for target
/// Returns the observed Element, which the entry holds. Read through the
/// hold: a target freed under it (its realm's teardown) reads as an error,
/// never as the freed slot.
pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.target.get() orelse error.InvalidStateError;
}
