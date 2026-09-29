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
const engine = @import("engine");
const IntersectionObserver = interfaces.IntersectionObserver;
const IntersectionObserverEntryImpl = @import("IntersectionObserverEntry.zig");
const same_object = @import("same_object.zig");
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
    /// The target, weakly: [[ObservationTargets]] does not keep an element
    /// alive, and one that is collected is no longer observed. Its slab
    /// generation says whether it is still the element it was taken on.
    target: same_object.Link,
    /// Previous threshold index (for detecting threshold crossings)
    previous_threshold_index: i32 = -1,
    /// Previous isIntersecting state
    previous_is_intersecting: bool = false,
};

/// Internal state for IntersectionObserver
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// [[callback]]: the IntersectionObserverCallback value, OWNED -
    /// released in deinit.
    callback: ?engine.CallbackFunction = null,

    /// List of observed targets with their state
    observations: std.ArrayListUnmanaged(Observation),

    /// Queue of pending IntersectionObserverEntry instances
    queued_entries: std.ArrayListUnmanaged(*runtime.Instance),

    /// Parsed threshold values (sorted)
    thresholds: std.ArrayListUnmanaged(f64),

    /// The `thresholds` attribute's frozen array, made on the first read and
    /// kept (OWNED), so every read returns the same array: the list never
    /// changes after construction.
    thresholds_array: ?engine.Owned = null,

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
        if (self.callback) |callback| callback.release();
        self.callback = null;

        // Clear observations (don't free targets, we don't own them)
        self.observations.deinit(self.allocator);

        // Free queued entries we own
        for (self.queued_entries.items) |entry| {
            runtime.Instance.deinit(entry);
        }
        self.queued_entries.deinit(self.allocator);

        // Free thresholds
        self.thresholds.deinit(self.allocator);
        if (self.thresholds_array) |array| array.release();
        self.thresholds_array = null;
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

    // Set this's internal [[callback]] slot to callback: the binding hands
    // the converted function over, and the observer keeps it (OWNED) with
    // its callback context.
    internal.callback = engine.takeCallbackFunction(@ptrCast(callback));

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
    // A platform object: the binding converts it to its wrapper.
    if (internal.root) |root| return runtime.JSValue.fromInstance(root);
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

/// Getter for thresholds: "return this's internal [[thresholds]] slot" as a
/// FrozenArray<double>. The slot never changes after construction, so the
/// array is made once, in the observer's relevant realm, and every read
/// returns it.
pub fn get_thresholds(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance);
    if (internal.thresholds_array == null) {
        const values = try internal.allocator.alloc(runtime.JSValue, internal.thresholds.items.len);
        defer internal.allocator.free(values);
        for (internal.thresholds.items, values) |threshold, *value| value.* = runtime.JSValue.fromNumber(threshold);
        internal.thresholds_array = try engine.createFrozenArray(instance.ctx, values);
    }
    // The observer keeps its array; the binding gets a hold of its own.
    return (try engine.retainValue(instance.ctx, internal.thresholds_array.?.value)).take();
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
    const internal = getInternal(instance);
    forgetCollectedTargets(instance, internal);

    // "Observe a target Element":
    // 1. If target is in observer's internal [[ObservationTargets]] slot,
    //    return.
    for (internal.observations.items) |obs| {
        if (obs.target.instance == target) return;
    }

    // 2-4. A registration with previousThresholdIndex -1 and
    //    previousIsIntersecting false, and target added to
    //    [[ObservationTargets]]. (The registration's state lives here, with
    //    the target, not on the element.)
    try internal.observations.append(internal.allocator, .{
        .target = same_object.Link.to(target),
        .previous_threshold_index = -1,
        .previous_is_intersecting = false,
    });
    holdWhileObserving(instance, internal);

    // Schedule intersection computation via microtask
    std.log.debug("[IntersectionObserver] Scheduling intersection update", .{});
    try scheduleIntersectionUpdate(instance, internal);
}

/// Operation: unobserve
/// Stops observing the specified target element
///
/// Spec: https://w3c.github.io/IntersectionObserver/#dom-intersectionobserver-unobserve
pub fn call_unobserve(instance: *runtime.Instance, target: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance);
    forgetCollectedTargets(instance, internal);

    // 1. Remove the registration whose observer is this from target, if
    //    present.
    // 2. Remove target from this's internal [[ObservationTargets]] slot, if
    //    present.
    for (internal.observations.items, 0..) |obs, i| {
        if (obs.target.instance == target) {
            _ = internal.observations.orderedRemove(i);
            break;
        }
    }
    holdWhileObserving(instance, internal);
}

/// Operation: disconnect
/// Stops observing all target elements
///
/// Spec: https://w3c.github.io/IntersectionObserver/#dom-intersectionobserver-disconnect
pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance);

    // For each target in this's [[ObservationTargets]]: 1. remove the
    // registration from target; 2. remove target from [[ObservationTargets]].
    internal.observations.clearRetainingCapacity();
    holdWhileObserving(instance, internal);

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

    // 1. Let queue be a copy of this's internal [[QueuedEntries]] slot.
    // 2. Clear this's internal [[QueuedEntries]] slot.
    const entries = try internal.queued_entries.toOwnedSlice(internal.allocator);
    defer internal.allocator.free(entries);

    // 3. Return queue - a sequence<IntersectionObserverEntry>, an Array of
    // the current realm. Wrapping hands each entry to the wrapper cache,
    // which owns them from here.
    const array = engine.createSequenceOfPlatformObjects(engine.currentRealm() orelse instance.ctx, entries) catch |err| {
        for (entries) |entry| runtime.Instance.deinit(entry);
        return err;
    };
    // OWNED: the binding takes it.
    return array.take();
}

// ============================================================================
// Internal methods
// ============================================================================

/// The observer's lifetime: "An IntersectionObserver will remain alive until
/// both of these conditions hold: there are no scripting references to the
/// observer, and the observer is not observing any targets." A target keeps
/// its observer alive through its registration in the spec; here the
/// observer holds its own wrapper while it observes anything - pending
/// activity, as Blink's IntersectionObserver is ActiveScriptWrappable while it
/// has observations - and lets it go when it observes nothing.
fn holdWhileObserving(instance: *runtime.Instance, internal: *InternalState) void {
    if (internal.observations.items.len > 0) {
        engine.keepPlatformObjectAlive(instance);
    } else {
        engine.releasePlatformObject(instance);
    }
}

/// Drop the observations of targets that have been collected: a collected
/// element is observed by nothing. Deviation, stated: the observer notices
/// only when it next looks at its targets (observe, unobserve, an update) -
/// nothing tells it when an element goes - so an observer whose every target
/// was collected keeps its hold until then.
fn forgetCollectedTargets(instance: *runtime.Instance, internal: *InternalState) void {
    var i: usize = 0;
    var forgot = false;
    while (i < internal.observations.items.len) {
        if (internal.observations.items[i].target.isLive()) {
            i += 1;
            continue;
        }
        _ = internal.observations.orderedRemove(i);
        forgot = true;
    }
    if (forgot) holdWhileObserving(instance, internal);
}

/// Context for the intersection observer microtask callback. The observer is
/// held as (address, slab generation): nothing keeps an observer alive while
/// it observes (the spec's lifetime rule is not implemented), so it may have
/// been collected, and its slot reused, by the time the microtask runs.
const IntersectionMicrotaskContext = struct {
    allocator: std.mem.Allocator,
    observer: *runtime.Instance,
    generation: u64,
};

/// The microtask's steps: compute the intersections, then notify.
fn intersectionMicrotask(data: ?*anyopaque) void {
    std.log.debug("[IntersectionObserver] Microtask callback invoked", .{});
    const ctx: *IntersectionMicrotaskContext = @ptrCast(@alignCast(data orelse return));
    const observer = ctx.observer;
    const generation = ctx.generation;
    ctx.allocator.destroy(ctx);
    if (runtime.SlabAllocator.generationOf(observer) != generation) return;
    const state = observer.getState(State);
    if (state.own._internal == null) return;
    const internal = getInternal(observer);
    forgetCollectedTargets(observer, internal);

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

/// Schedule an intersection update via microtask, in the agent of the
/// observer's relevant realm. (The spec runs the observation steps in "update
/// the rendering" and notifies from a task; a microtask is this engine's
/// stand-in, with no rendering loop.)
fn scheduleIntersectionUpdate(instance: *runtime.Instance, internal: *InternalState) !void {
    const ctx = try internal.allocator.create(IntersectionMicrotaskContext);
    ctx.* = .{ .allocator = internal.allocator, .observer = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    // The surrounding agent's microtask queue; a realm with no engine behind
    // it has none.
    const queued: engine.Error!void = if (internal.ctx.agent) |agent| engine.queueMicrotask(agent, intersectionMicrotask, ctx) else error.NotSupported;
    queued catch |err| {
        internal.allocator.destroy(ctx);
        if (err == error.OutOfMemory) return error.OutOfMemory;
        // No engine behind the realm, so no microtask queue: compute now.
        try computeIntersections(internal);
        if (internal.queued_entries.items.len > 0) try invokeCallback(internal);
    };
}

/// Compute intersections for all observed targets
fn computeIntersections(internal: *InternalState) !void {
    std.log.debug("[IntersectionObserver] computeIntersections: {} observations", .{internal.observations.items.len});
    const time: typedefs.DOMHighResTimeStamp = @as(f64, @floatFromInt(clock.monotonicMillis()));

    for (internal.observations.items, 0..) |*obs, idx| {
        std.log.debug("[IntersectionObserver] Processing observation {}", .{idx});
        // A target collected since the observer last looked: not observed.
        if (!obs.target.isLive()) continue;
        const target = obs.target.instance;

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

/// Notify intersection observers, step 3 for this observer.
///
/// Spec: https://w3c.github.io/IntersectionObserver/#notify-intersection-observers
fn invokeCallback(internal: *InternalState) !void {
    const observer = internal.self_instance orelse return;
    const realm = internal.ctx;

    // 1. If observer's internal [[QueuedEntries]] slot is empty, continue.
    if (internal.queued_entries.items.len == 0) return;
    // 2. Let queue be a copy of observer's internal [[QueuedEntries]] slot.
    // 3. Clear observer's internal [[QueuedEntries]] slot.
    const queue = try internal.queued_entries.toOwnedSlice(internal.allocator);
    defer internal.allocator.free(queue);

    // 4. Let callback be the value of observer's internal [[callback]] slot.
    const callback = internal.callback orelse {
        for (queue) |entry| runtime.Instance.deinit(entry);
        return;
    };

    // queue as a sequence<IntersectionObserverEntry>. Wrapping hands each
    // entry to the wrapper cache, which owns them from here.
    const entries = engine.createSequenceOfPlatformObjects(realm, queue) catch |err| {
        for (queue) |entry| runtime.Instance.deinit(entry);
        return err;
    };
    defer entries.release();

    // 5. Invoke callback with queue as the first argument, observer as the
    // second argument, and observer as the callback this value. If this
    // throws an exception, report the exception.
    const this_value: runtime.JSValue = .{ .instance = observer };
    const completion = try engine.invokeCallbackFunction(realm, &callback, .{ .value = this_value }, &.{ entries.value, this_value }, .{
        .report = .{ .report = reportException, .host = realm },
    });
    switch (completion) {
        inline else => |value| value.release(),
    }
}

/// HTML "report an exception" for the global of the realm the engine names -
/// the callback's associated realm - or else the observer's (`host`).
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const observer_realm: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse observer_realm;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    // Step 2's error information is the engine's, extracted where the
    // exception was thrown: a thrown value that is not an Error carries no
    // position of its own to extract it from again.
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}
