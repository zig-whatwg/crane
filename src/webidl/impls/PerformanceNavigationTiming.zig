//! Implementation for PerformanceNavigationTiming interface
//!
//! Spec: https://w3c.github.io/navigation-timing/#sec-PerformanceNavigationTiming
//!
//! The navigation timing entry of a Document: made by "create the navigation
//! timing entry" (`dom.performance_timeline`, through the hook this impl
//! installs) when a navigation makes the document, its resource timing set up
//! from the navigation's fetch. Its document load timing - DOM interactive,
//! the DOMContentLoaded and load event times - is read when asked, from the
//! load timing info its global's timeline records as the document loads.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const engine = @import("engine");
const performance_timeline = @import("dom").performance_timeline;
const PerformanceNavigationTiming = interfaces.PerformanceNavigationTiming;

pub const State = PerformanceNavigationTiming.State;

pub const ImplError = error{
    NotImplemented,
};

/// The entry's redirect count, navigation type and not restored reasons.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    redirect_count: u16,
    navigation_type: performance_timeline.NavigationType,
    /// Navigation Timing step 11's backing struct: a copy, OWNED; null for
    /// a document that was not a back/forward traversal's.
    not_restored_reasons: ?performance_timeline.NotRestoredReasons = null,
    /// The NotRestoredReasons object made from it, traced by the entry so
    /// every read answers the same object; null until the first read.
    reasons_object: ?*runtime.Instance = null,
    reasons_object_generation: u64 = 0,
};

const reasons_object_slot: engine.TracedSlot = .{ .name = "notRestoredReasons" };

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    performance_timeline.installNavigationTimings(.{ .create = &createEntry });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: its own state, then PerformanceResourceTiming's
/// part (which goes on to PerformanceEntry's).
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.reasons_object != null) engine.forgetTracedChild(instance, reasons_object_slot);
        if (internal.not_restored_reasons) |*reasons| reasons.deinit(internal.allocator);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.PerformanceResourceTiming.deinit(instance);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// "create the navigation timing entry" steps 2-8 (Navigation Timing 5).
fn createEntry(realm: runtime.Context, timing: *const performance_timeline.ResourceTiming, redirect_count: u16, navigation_type: performance_timeline.NavigationType, service_worker_timing: ?performance_timeline.NavigationServiceWorkerTiming, not_restored_reasons: ?*const performance_timeline.NotRestoredReasons) anyerror!*runtime.Instance {
    const allocator = realm.allocator;
    // 2. A new PerformanceNavigationTiming in global's realm.
    const instance = try init(allocator, State, &PerformanceNavigationTiming.vtable, realm);
    errdefer runtime.Instance.deinit(instance);
    // 3. Setup the resource timing entry: its step 3 initializes the
    // PerformanceEntry (startTime 0, "navigation", the document's URL), and
    // steps 4-11 are the rest of `timing`.
    try performance_timeline.initializeEntry(instance, timing.start_time, .navigation, timing.url, timing.end_time);
    // 8, and the fetchStart getter steps: with a service worker timing,
    // fetchStart is its fetch event dispatch time (made relative to the
    // time origin, as every other attribute), not the fetch's post-redirect
    // start - so it follows the worker's activation. Chrome and Firefox
    // mark fetchStart after activation, Safari does not
    // (service-workers/.../navigation-timing-extended.https.html, wpt.fyi
    // df642c4142). The entry's setup copies what it is given.
    var own = timing.*;
    if (service_worker_timing) |sw| own.fetch_start = sw.fetch_event_dispatch_time;
    try performance_timeline.setupResourceTiming(instance, &own);
    // 6-7. Redirect count and navigation type. 11. Its not restored
    // reasons, a copy (the object is made when first read).
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    const reasons: ?performance_timeline.NotRestoredReasons = if (not_restored_reasons) |given| try given.clone(allocator) else null;
    internal.* = .{
        .allocator = allocator,
        .redirect_count = redirect_count,
        .navigation_type = navigation_type,
        .not_restored_reasons = reasons,
    };
    instance.getState(State).own._internal = internal;
    return instance;
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    return state.own._internal orelse error.InvalidStateError;
}

/// The document load timing and previous document unload timing: its
/// global's timeline's record of its associated Document.
fn loadTiming(instance: *runtime.Instance) !performance_timeline.LoadTimingInfo {
    _ = try internalOf(instance);
    const info = performance_timeline.loadTimingOf(instance.ctx) orelse return .{};
    return info.*;
}

/// Getter for unloadEventStart: the previous document unload timing's unload
/// event start time (0: none recorded - no same-origin previous document).
pub fn get_unloadEventStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try loadTiming(instance)).unload_event_start;
}

/// Getter for unloadEventEnd
pub fn get_unloadEventEnd(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try loadTiming(instance)).unload_event_end;
}

/// Getter for domInteractive: the document load timing's DOM interactive time.
pub fn get_domInteractive(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try loadTiming(instance)).dom_interactive;
}

/// Getter for domContentLoadedEventStart
pub fn get_domContentLoadedEventStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try loadTiming(instance)).dom_content_loaded_event_start;
}

/// Getter for domContentLoadedEventEnd
pub fn get_domContentLoadedEventEnd(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try loadTiming(instance)).dom_content_loaded_event_end;
}

/// Getter for domComplete
pub fn get_domComplete(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try loadTiming(instance)).dom_complete;
}

/// Getter for loadEventStart
pub fn get_loadEventStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try loadTiming(instance)).load_event_start;
}

/// Getter for loadEventEnd
pub fn get_loadEventEnd(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try loadTiming(instance)).load_event_end;
}

/// Getter for type: the navigation type.
pub fn get_type(instance: *runtime.Instance) anyerror!enums.NavigationTimingType {
    return switch ((try internalOf(instance)).navigation_type) {
        .navigate => ._navigate_,
        .reload => ._reload_,
        .back_forward => ._back_forward_,
    };
}

/// Getter for redirectCount
pub fn get_redirectCount(instance: *runtime.Instance) anyerror!u16 {
    return (try internalOf(instance)).redirect_count;
}

/// Getter for criticalCHRestart: no `Critical-CH` restart happens here.
pub fn get_criticalCHRestart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    _ = try internalOf(instance);
    return 0;
}

/// Getter for notRestoredReasons: "this's not restored reasons" - Navigation
/// Timing step 11's "create a NotRestoredReasons object given document's not
/// restored reasons and document's relevant realm", null when they are
/// null. The object is made the first time it is read (nothing tells the
/// two apart: it holds a copy of the struct, and every read after answers
/// the same object, which the entry traces).
pub fn get_notRestoredReasons(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = try internalOf(instance);
    const reasons = if (internal.not_restored_reasons) |*value| value else return null;
    if (internal.reasons_object) |object| {
        if (runtime.SlabAllocator.generationOf(object) == internal.reasons_object_generation) return object;
    }
    const object = try interfaces.NotRestoredReasons.initWith(instance.ctx.allocator, instance.ctx, .{ .backing = @as(*const performance_timeline.NotRestoredReasons, reasons) });
    engine.traceChild(instance, object, reasons_object_slot);
    internal.reasons_object = object;
    internal.reasons_object_generation = runtime.SlabAllocator.generationOf(object);
    return object;
}

/// Getter for activationStart (Prerendering Revamped): a document that was
/// not prerendered was activated at 0.
pub fn get_activationStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    _ = try internalOf(instance);
    return 0;
}

/// Getter for confidence
/// TODO(perftimeline): PerformanceTimingConfidence (its randomized trigger
/// rate and value) is not made yet.
pub fn get_confidence(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: toJSON
/// TODO(perftimeline): the generated result struct types the nullable
/// notRestoredReasons and confidence as non-optional instances, which a
/// document with neither cannot fill (a codegen question for the
/// integrator).
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.PerformanceNavigationTiming.PerformanceNavigationTimingToJSON {
    _ = instance;
    return error.NotImplemented;
}
