//! Implementation for IntersectionObserver interface
//!
//! Spec: https://w3c.github.io/IntersectionObserver/#intersection-observer-interface
//!
//! IntersectionObserver provides a way to asynchronously observe changes in the
//! intersection of a target element with an ancestor element or with a top-level
//! document's viewport.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const v8_engine = @import("v8");
const IntersectionObserver = interfaces.IntersectionObserver;
const IntersectionObserverEntryImpl = @import("IntersectionObserverEntry.zig");
const clock = @import("clock");

pub const State = IntersectionObserver.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
    TypeError,
    SyntaxError,
};

/// Observation state for a single target
const Observation = struct {
    target: *runtime.Instance,
    /// Previous threshold index (for detecting threshold crossings)
    previous_threshold_index: i32 = -1,
    /// Previous isIntersecting state
    previous_is_intersecting: bool = false,
};

/// Internal state for IntersectionObserver
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Callback invoked when intersections change
    /// Uses V8 Global handle to persist across HandleScope boundaries
    callback: v8_engine.OptionalGlobalHandle = null,

    /// V8 isolate for Global handle operations
    isolate: ?*v8_engine.ffi.Isolate = null,

    /// List of observed targets with their state
    observations: std.ArrayListUnmanaged(Observation),

    /// Queue of pending IntersectionObserverEntry instances
    queued_entries: std.ArrayListUnmanaged(*runtime.Instance),

    /// Parsed threshold values (sorted)
    thresholds: std.ArrayListUnmanaged(f64),

    /// Root margin values [top, right, bottom, left] in pixels
    root_margin: [4]f64 = .{ 0, 0, 0, 0 },

    /// Scroll margin values [top, right, bottom, left] in pixels
    scroll_margin: [4]f64 = .{ 0, 0, 0, 0 },

    /// Minimum delay between notifications in milliseconds
    delay: i32 = 0,

    /// Whether to compute visibility
    track_visibility: bool = false,

    /// Root element or document (null for implicit viewport root)
    root: ?*runtime.Instance = null,

    /// The observer instance (for callback invocation)
    self_instance: ?*runtime.Instance = null,

    /// Context for creating entries
    ctx: runtime.Context = undefined,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .observations = .empty,
            .queued_entries = .empty,
            .thresholds = .empty,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Dispose Global handle for callback
        v8_engine.disposeOptionalGlobalHandle(&self.callback);

        // Clear observations (don't free targets, we don't own them)
        self.observations.deinit(self.allocator);

        // Free queued entries we own
        for (self.queued_entries.items) |entry| {
            runtime.Instance.deinit(entry);
        }
        self.queued_entries.deinit(self.allocator);

        // Free thresholds
        self.thresholds.deinit(self.allocator);
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
    internal.ctx = ctx;

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
        // Return the block itself, not just what it points to. The comment this
        // replaces said the arena manages it; the arena had no way to, so the
        // struct stayed allocated for the life of the process.
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Creates an IntersectionObserver with the given callback and options
///
/// Spec: https://w3c.github.io/IntersectionObserver/#dom-intersectionobserver-intersectionobserver
pub fn call_constructor(ctx: runtime.Context, callback: callbacks.IntersectionObserverCallback, options: webidl.Opt(dictionaries.IntersectionObserverInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &IntersectionObserver.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance);
    internal.self_instance = instance;

    // Get the current isolate for Global handle creation
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent();
    internal.isolate = isolate;

    // Extract Global handle from the callback
    // The callback comes from V8 conversion which creates a Global handle and tags the pointer
    const callback_ptr: ?*const anyopaque = @ptrCast(callback);
    if (callback_ptr) |ptr| {
        const untagged = v8_engine.pointer_tag.untagPointer(ptr);
        if (untagged.tag == .global_handle or untagged.tag == .untagged) {
            internal.callback = v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
        }
    }

    // Parse options
    const opts = if (options.was_passed) options.value else dictionaries.IntersectionObserverInit{};

    // Parse thresholds
    // Default threshold is [0]
    if (opts.threshold) |threshold_value| {
        // threshold can be a single number or sequence
        // For now, handle it as a JSValue that could be either
        _ = threshold_value;
        // Default to [0] for simplicity
        try internal.thresholds.append(internal.allocator, 0.0);
    } else {
        // Default threshold is 0
        try internal.thresholds.append(internal.allocator, 0.0);
    }

    // Store configuration in state
    const state = instance.getState(State);
    state.own.delay = opts.delay orelse 0;
    state.own.trackVisibility = opts.trackVisibility orelse false;

    // Parse rootMargin (default "0px")
    if (opts.rootMargin) |margin_str| {
        _ = margin_str; // TODO: Parse margin string
    }
    state.own.rootMargin = runtime.DOMString.initEmpty();

    // Parse scrollMargin (default "0px")
    if (opts.scrollMargin) |margin_str| {
        _ = margin_str; // TODO: Parse margin string
    }
    state.own.scrollMargin = runtime.DOMString.initEmpty();

    // Store delay and trackVisibility
    internal.delay = opts.delay orelse 0;
    internal.track_visibility = opts.trackVisibility orelse false;

    // If trackVisibility is true and delay < 100, set delay to 100
    if (internal.track_visibility and internal.delay < 100) {
        internal.delay = 100;
        state.own.delay = 100;
    }

    return instance;
}

/// Getter for root
/// Returns the root Element or Document, or null for implicit viewport root
pub fn get_root(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    const internal = getInternal(instance);
    if (internal.root) |root| {
        // Convert instance to JSValue
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent();
        if (isolate) |iso| {
            const v8_val = v8_engine.conversions.instanceToV8(iso, root);
            return runtime.JSValue.fromHandle(@ptrCast(v8_val));
        }
    }
    return null;
}

/// Getter for rootMargin
/// Returns the root margin as a string (e.g., "0px 0px 0px 0px")
pub fn get_rootMargin(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance);
    // Format: "Tpx Rpx Bpx Lpx"
    var buf: [128]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{d}px {d}px {d}px {d}px", .{
        internal.root_margin[0],
        internal.root_margin[1],
        internal.root_margin[2],
        internal.root_margin[3],
    }) catch return runtime.DOMString.initEmpty();

    return runtime.DOMString.initDupe(instance.ctx.allocator, result) catch return runtime.DOMString.initEmpty();
}

/// Getter for scrollMargin
/// Returns the scroll margin as a string
pub fn get_scrollMargin(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance);
    var buf: [128]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{d}px {d}px {d}px {d}px", .{
        internal.scroll_margin[0],
        internal.scroll_margin[1],
        internal.scroll_margin[2],
        internal.scroll_margin[3],
    }) catch return runtime.DOMString.initEmpty();

    return runtime.DOMString.initDupe(instance.ctx.allocator, result) catch return runtime.DOMString.initEmpty();
}

/// Getter for thresholds
/// Returns the list of thresholds as a frozen array
pub fn get_thresholds(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance);
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return runtime.JSValue.jsUndefined;
    const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return runtime.JSValue.jsUndefined;
    defer v8_engine.ffi.v8_Context_Dispose(context);

    // Create a V8 array with the thresholds
    const array = v8_engine.ffi.v8_Array_New(isolate, @intCast(internal.thresholds.items.len));

    for (internal.thresholds.items, 0..) |threshold, i| {
        const num = v8_engine.ffi.v8_Number_New(isolate, threshold);
        _ = v8_engine.ffi.v8_Array_Set(array, context, @intCast(i), @ptrCast(num));
    }

    // TODO: Freeze the array per spec
    return runtime.JSValue.fromHandle(@ptrCast(array));
}

/// Getter for delay
pub fn get_delay(instance: *runtime.Instance) anyerror!i32 {
    const internal = getInternal(instance);
    return internal.delay;
}

/// Getter for trackVisibility
pub fn get_trackVisibility(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance);
    return internal.track_visibility;
}

/// Operation: observe
/// Starts observing the specified target element
///
/// Spec: https://w3c.github.io/IntersectionObserver/#dom-intersectionobserver-observe
pub fn call_observe(instance: *runtime.Instance, target: *runtime.Instance) anyerror!void {
    std.log.debug("[IntersectionObserver] observe called, target={*}", .{target});
    const internal = getInternal(instance);

    // Check if already observing this target
    for (internal.observations.items) |obs| {
        if (obs.target == target) {
            // Already observing, do nothing
            std.log.debug("[IntersectionObserver] Already observing target", .{});
            return;
        }
    }

    // Add to observations
    try internal.observations.append(internal.allocator, .{
        .target = target,
        .previous_threshold_index = -1,
        .previous_is_intersecting = false,
    });
    std.log.debug("[IntersectionObserver] Added target to observations, count={}", .{internal.observations.items.len});

    // Schedule intersection computation via microtask
    std.log.debug("[IntersectionObserver] Scheduling intersection update", .{});
    try scheduleIntersectionUpdate(internal);
}

/// Operation: unobserve
/// Stops observing the specified target element
///
/// Spec: https://w3c.github.io/IntersectionObserver/#dom-intersectionobserver-unobserve
pub fn call_unobserve(instance: *runtime.Instance, target: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance);

    // Find and remove the observation
    var i: usize = 0;
    while (i < internal.observations.items.len) {
        if (internal.observations.items[i].target == target) {
            _ = internal.observations.orderedRemove(i);
            return;
        }
        i += 1;
    }
}

/// Operation: disconnect
/// Stops observing all target elements
///
/// Spec: https://w3c.github.io/IntersectionObserver/#dom-intersectionobserver-disconnect
pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance);

    // Clear all observations
    internal.observations.clearRetainingCapacity();

    // Clear queued entries
    for (internal.queued_entries.items) |entry| {
        runtime.Instance.deinit(entry);
    }
    internal.queued_entries.clearRetainingCapacity();
}

/// Operation: takeRecords
/// Returns the list of queued IntersectionObserverEntry objects and clears the queue
///
/// Spec: https://w3c.github.io/IntersectionObserver/#dom-intersectionobserver-takerecords
pub fn call_takeRecords(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance);
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return runtime.JSValue.jsUndefined;
    const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return runtime.JSValue.jsUndefined;
    defer v8_engine.ffi.v8_Context_Dispose(context);

    // Create a V8 array with the entries
    const entries = internal.queued_entries.toOwnedSlice(internal.allocator) catch return runtime.JSValue.jsUndefined;
    defer internal.allocator.free(entries);

    const array = v8_engine.ffi.v8_Array_New(isolate, @intCast(entries.len));

    for (entries, 0..) |entry, i| {
        const wrapped = v8_engine.conversions.instanceToV8(isolate, entry);
        _ = v8_engine.ffi.v8_Array_Set(array, context, @intCast(i), wrapped);
    }

    return runtime.JSValue.fromHandle(@ptrCast(array));
}

// ============================================================================
// Internal methods
// ============================================================================

/// Context for the intersection observer microtask callback
const IntersectionMicrotaskContext = struct {
    internal: *InternalState,
};

/// Microtask trampoline callback that computes intersections
fn intersectionMicrotaskCallback(data: ?*anyopaque) callconv(.c) void {
    std.log.debug("[IntersectionObserver] Microtask callback invoked", .{});
    const ctx: *IntersectionMicrotaskContext = @ptrCast(@alignCast(data orelse {
        std.log.err("[IntersectionObserver] Microtask callback: null data!", .{});
        return;
    }));
    const internal = ctx.internal;
    const allocator = internal.allocator;

    // Free the context
    allocator.destroy(ctx);

    std.log.debug("[IntersectionObserver] Computing intersections for {} targets", .{internal.observations.items.len});

    // Compute intersections for all observed targets
    computeIntersections(internal) catch |err| {
        std.log.err("IntersectionObserver: computeIntersections failed: {}", .{err});
        return;
    };

    std.log.debug("[IntersectionObserver] Computed intersections, {} queued entries", .{internal.queued_entries.items.len});

    // If there are queued entries, invoke the callback
    if (internal.queued_entries.items.len > 0) {
        std.log.debug("[IntersectionObserver] Invoking callback with {} entries", .{internal.queued_entries.items.len});
        invokeCallback(internal) catch |err| {
            std.log.err("IntersectionObserver: invokeCallback failed: {}", .{err});
        };
    }
}

/// Schedule an intersection update via microtask
fn scheduleIntersectionUpdate(internal: *InternalState) !void {
    std.log.debug("[IntersectionObserver] scheduleIntersectionUpdate called", .{});
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse {
        std.log.debug("[IntersectionObserver] No V8 isolate, computing synchronously", .{});
        // No V8 isolate - compute synchronously
        try computeIntersections(internal);
        if (internal.queued_entries.items.len > 0) {
            try invokeCallback(internal);
        }
        return;
    };

    std.log.debug("[IntersectionObserver] Got V8 isolate, enqueueing microtask", .{});

    // Allocate context for the microtask
    const ctx = try internal.allocator.create(IntersectionMicrotaskContext);
    ctx.* = .{ .internal = internal };

    // Queue the microtask with V8
    const callback_fn: ?*const anyopaque = @ptrCast(&intersectionMicrotaskCallback);
    v8_engine.ffi.v8_Isolate_EnqueueMicrotask(isolate, callback_fn, ctx);
    std.log.debug("[IntersectionObserver] Microtask enqueued", .{});
}

/// Compute intersections for all observed targets
fn computeIntersections(internal: *InternalState) !void {
    std.log.debug("[IntersectionObserver] computeIntersections: {} observations", .{internal.observations.items.len});
    const time: typedefs.DOMHighResTimeStamp = @as(f64, @floatFromInt(clock.monotonicMillis()));

    for (internal.observations.items, 0..) |*obs, idx| {
        std.log.debug("[IntersectionObserver] Processing observation {}", .{idx});
        const target = obs.target;

        // Get target's bounding rect
        std.log.debug("[IntersectionObserver] Getting bounding rect for target", .{});
        const bounding_rect = try interfaces.Element.call_getBoundingClientRect(target);

        // Get the bounding rect values
        const rect_state = bounding_rect.getState(interfaces.DOMRectReadOnly.State);
        const target_x = rect_state.own.x;
        const target_y = rect_state.own.y;
        const target_width = rect_state.own.width;
        const target_height = rect_state.own.height;
        const target_area = target_width * target_height;

        std.log.debug("[IntersectionObserver] Target rect: x={d}, y={d}, w={d}, h={d}, area={d}", .{ target_x, target_y, target_width, target_height, target_area });

        // For implicit root (viewport), use a default viewport size
        // In a real implementation, this would come from the layout engine
        const viewport_width: f64 = 800;
        const viewport_height: f64 = 600;

        // Create root bounds (viewport with margins applied)
        const root_x: f64 = 0 - internal.root_margin[3]; // left margin
        const root_y: f64 = 0 - internal.root_margin[0]; // top margin
        const root_width: f64 = viewport_width + internal.root_margin[1] + internal.root_margin[3];
        const root_height: f64 = viewport_height + internal.root_margin[0] + internal.root_margin[2];

        // Compute intersection rectangle
        const intersect_left = @max(target_x, root_x);
        const intersect_top = @max(target_y, root_y);
        const intersect_right = @min(target_x + target_width, root_x + root_width);
        const intersect_bottom = @min(target_y + target_height, root_y + root_height);

        var intersect_width: f64 = 0;
        var intersect_height: f64 = 0;
        var is_intersecting = false;

        if (intersect_right > intersect_left and intersect_bottom > intersect_top) {
            // Standard intersection: positive-area overlap
            intersect_width = intersect_right - intersect_left;
            intersect_height = intersect_bottom - intersect_top;
            is_intersecting = true;
        } else if (target_area == 0) {
            // Per spec: A zero-area target is intersecting if its position is within root bounds
            // Check if the target's origin point (top-left) is within root bounds
            if (target_x >= root_x and target_x <= root_x + root_width and
                target_y >= root_y and target_y <= root_y + root_height)
            {
                is_intersecting = true;
                std.log.debug("[IntersectionObserver] Zero-area target at ({d},{d}) is within root bounds, marking as intersecting", .{ target_x, target_y });
            }
        }

        std.log.debug("[IntersectionObserver] is_intersecting={}, intersection_rect=({d},{d},{d},{d})", .{ is_intersecting, intersect_left, intersect_top, intersect_width, intersect_height });

        // Calculate intersection ratio
        var intersection_ratio: f64 = 0;
        if (target_area > 0 and is_intersecting) {
            const intersect_area = intersect_width * intersect_height;
            intersection_ratio = @min(intersect_area / target_area, 1.0);
        } else if (target_area == 0 and is_intersecting) {
            // Per spec: if target area is 0 but intersecting, ratio is 1
            intersection_ratio = 1.0;
        }

        std.log.debug("[IntersectionObserver] intersection_ratio={d}", .{intersection_ratio});

        // Find threshold index
        var threshold_index: i32 = 0;
        for (internal.thresholds.items) |threshold| {
            if (intersection_ratio >= threshold) {
                threshold_index += 1;
            } else {
                break;
            }
        }

        // Check if we need to queue an entry (threshold crossing or intersection state change)
        const should_queue = (threshold_index != obs.previous_threshold_index) or
            (is_intersecting != obs.previous_is_intersecting);

        if (should_queue) {
            // Create root bounds rect
            const root_bounds = try interfaces.DOMRectReadOnly.call_constructor(
                internal.ctx,
                webidl.Opt(f64).passed(root_x),
                webidl.Opt(f64).passed(root_y),
                webidl.Opt(f64).passed(root_width),
                webidl.Opt(f64).passed(root_height),
            );

            // Create intersection rect
            const intersection_rect = try interfaces.DOMRectReadOnly.call_constructor(
                internal.ctx,
                webidl.Opt(f64).passed(if (is_intersecting) intersect_left else 0),
                webidl.Opt(f64).passed(if (is_intersecting) intersect_top else 0),
                webidl.Opt(f64).passed(intersect_width),
                webidl.Opt(f64).passed(intersect_height),
            );

            // Create entry
            const entry = try IntersectionObserverEntryImpl.createEntry(
                internal.ctx,
                time,
                root_bounds,
                bounding_rect,
                intersection_rect,
                is_intersecting,
                false, // isVisible (would need visibility computation)
                intersection_ratio,
                target,
            );

            // Queue the entry
            try internal.queued_entries.append(internal.allocator, entry);

            // Update previous state
            obs.previous_threshold_index = threshold_index;
            obs.previous_is_intersecting = is_intersecting;
        }
    }
}

/// Invoke the callback with queued entries
fn invokeCallback(internal: *InternalState) !void {
    std.log.debug("[IntersectionObserver] invokeCallback called", .{});
    const callback_global = internal.callback orelse {
        std.log.debug("[IntersectionObserver] No callback stored!", .{});
        return;
    };
    const isolate = internal.isolate orelse {
        std.log.debug("[IntersectionObserver] No isolate!", .{});
        return;
    };
    const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        std.log.debug("[IntersectionObserver] No current context!", .{});
        return;
    };
    defer v8_engine.ffi.v8_Context_Dispose(context);
    std.log.debug("[IntersectionObserver] Got callback={*}, isolate={*}, context={*}", .{ callback_global.ptr, isolate, context });

    // Create a HandleScope for V8 operations
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(isolate) orelse return;
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Create a V8 array for the entries
    std.log.debug("[IntersectionObserver] Creating entries array with {} entries", .{internal.queued_entries.items.len});
    const entries_array = v8_engine.ffi.v8_Array_New(isolate, @intCast(internal.queued_entries.items.len));
    std.log.debug("[IntersectionObserver] Created entries array: {*}", .{entries_array});

    // Populate the array with wrapped entry objects
    const conv = v8_engine.conversions;
    for (internal.queued_entries.items, 0..) |entry, idx| {
        std.log.debug("[IntersectionObserver] Wrapping entry {} at {*}", .{ idx, entry });
        const wrapped = conv.instanceToV8(isolate, entry);
        std.log.debug("[IntersectionObserver] Wrapped entry to V8 value: {*}", .{wrapped});
        const set_result = v8_engine.ffi.v8_Array_Set(entries_array, context, @intCast(idx), wrapped);
        std.log.debug("[IntersectionObserver] Array set result: {}", .{set_result});
    }

    // Clear the queue (entries are now owned by V8)
    internal.queued_entries.clearRetainingCapacity();
    std.log.debug("[IntersectionObserver] Cleared entry queue", .{});

    // Wrap the observer instance as V8 object for the second argument
    const observer_v8 = if (internal.self_instance) |self| conv.instanceToV8(isolate, self) else return;

    // Get undefined for 'this' value
    const recv_global = v8_engine.ffi.v8_Undefined(isolate) orelse return;

    // Prepare arguments: [entries, observer]
    var global_args: [2]*v8_engine.ffi.Value = .{
        @ptrCast(entries_array),
        observer_v8,
    };

    // Get the callback function pointer
    const func_ptr = callback_global.ptr;
    std.log.debug("[IntersectionObserver] Calling callback function at {*}", .{func_ptr});

    // Call the callback function
    const result = v8_engine.ffi.v8_Function_Call_Safe(
        @ptrCast(func_ptr),
        context,
        @ptrCast(recv_global),
        2,
        @ptrCast(&global_args),
    );
    defer v8_engine.ffi.v8_FreeFunctionCallResult(result);

    // Check for errors
    if (result.error_info) |err_info| {
        if (err_info.message) |msg| {
            std.log.err("[IntersectionObserver] Callback error: {s}", .{msg});
        } else {
            std.log.err("[IntersectionObserver] Callback error (no message)", .{});
        }
    } else {
        std.log.debug("[IntersectionObserver] Callback invoked successfully", .{});
    }
}
