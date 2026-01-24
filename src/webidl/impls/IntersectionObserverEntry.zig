//! Implementation for IntersectionObserverEntry interface
//!
//! Spec: https://w3c.github.io/IntersectionObserver/#intersection-observer-entry
//!
//! IntersectionObserverEntry objects provide information about a single
//! intersection change, including the time of the change, the intersection
//! rectangle, the bounding client rect, and whether the target is intersecting.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const IntersectionObserverEntry = interfaces.IntersectionObserverEntry;

pub const State = IntersectionObserverEntry.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Internal state for IntersectionObserverEntry
/// Stores the entry data that doesn't fit in the flattened state
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        _ = self;
        // Entry data is stored in flattened state, no cleanup needed
    }
};

/// Helper to access internal state from instance
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) *InternalState {
    return Accessor.getCast(instance);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state using ArenaAllocator
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state in instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Creates an IntersectionObserverEntry from an IntersectionObserverEntryInit dictionary
///
/// Spec: https://w3c.github.io/IntersectionObserver/#dom-intersectionobserverentry-intersectionobserverentry
pub fn call_constructor(ctx: runtime.Context, intersectionObserverEntryInit: dictionaries.IntersectionObserverEntryInit) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &IntersectionObserverEntry.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Copy values from init dictionary to state
    state.own.time = intersectionObserverEntryInit.time;
    state.own.isIntersecting = intersectionObserverEntryInit.isIntersecting;
    state.own.isVisible = intersectionObserverEntryInit.isVisible;
    state.own.intersectionRatio = intersectionObserverEntryInit.intersectionRatio;
    state.own.target = intersectionObserverEntryInit.target;

    // Create DOMRectReadOnly instances for the rect properties
    // Note: Per IDL, rootBounds is "required DOMRectInit?" - required but nullable type
    // However our codegen doesn't handle nullable types in dictionaries correctly,
    // so we always create the rect. For actual null handling, use createEntry() directly.
    const root_bounds_init = intersectionObserverEntryInit.rootBounds;
    state.own.rootBounds = try interfaces.DOMRectReadOnly.call_constructor(
        ctx,
        webidl.Opt(f64).passed(root_bounds_init.x orelse 0),
        webidl.Opt(f64).passed(root_bounds_init.y orelse 0),
        webidl.Opt(f64).passed(root_bounds_init.width orelse 0),
        webidl.Opt(f64).passed(root_bounds_init.height orelse 0),
    );

    // boundingClientRect is required
    state.own.boundingClientRect = try interfaces.DOMRectReadOnly.call_constructor(
        ctx,
        webidl.Opt(f64).passed(intersectionObserverEntryInit.boundingClientRect.x orelse 0),
        webidl.Opt(f64).passed(intersectionObserverEntryInit.boundingClientRect.y orelse 0),
        webidl.Opt(f64).passed(intersectionObserverEntryInit.boundingClientRect.width orelse 0),
        webidl.Opt(f64).passed(intersectionObserverEntryInit.boundingClientRect.height orelse 0),
    );

    // intersectionRect is required
    state.own.intersectionRect = try interfaces.DOMRectReadOnly.call_constructor(
        ctx,
        webidl.Opt(f64).passed(intersectionObserverEntryInit.intersectionRect.x orelse 0),
        webidl.Opt(f64).passed(intersectionObserverEntryInit.intersectionRect.y orelse 0),
        webidl.Opt(f64).passed(intersectionObserverEntryInit.intersectionRect.width orelse 0),
        webidl.Opt(f64).passed(intersectionObserverEntryInit.intersectionRect.height orelse 0),
    );

    return instance;
}

/// Internal factory function for creating entries from Zig code
/// This avoids the dictionary overhead when creating entries programmatically
pub fn createEntry(
    ctx: runtime.Context,
    time: typedefs.DOMHighResTimeStamp,
    root_bounds: ?*runtime.Instance,
    bounding_client_rect: *runtime.Instance,
    intersection_rect: *runtime.Instance,
    is_intersecting: bool,
    is_visible: bool,
    intersection_ratio: f64,
    target: *runtime.Instance,
) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &IntersectionObserverEntry.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    state.own.time = time;
    state.own.rootBounds = root_bounds;
    state.own.boundingClientRect = bounding_client_rect;
    state.own.intersectionRect = intersection_rect;
    state.own.isIntersecting = is_intersecting;
    state.own.isVisible = is_visible;
    state.own.intersectionRatio = intersection_ratio;
    state.own.target = target;

    return instance;
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
    const state = instance.getState(State);
    return state.own.rootBounds;
}

/// Getter for boundingClientRect
/// Returns the target's bounding client rectangle
pub fn get_boundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    return state.own.boundingClientRect;
}

/// Getter for intersectionRect
/// Returns the intersection rectangle between target and root
pub fn get_intersectionRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    return state.own.intersectionRect;
}

/// Getter for isIntersecting
/// Returns true if the target is intersecting with the root
pub fn get_isIntersecting(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    std.log.debug("[IntersectionObserverEntry] get_isIntersecting called, value={}", .{state.own.isIntersecting});
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
/// Returns the observed Element
pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    return state.own.target;
}
