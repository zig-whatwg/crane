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
const same_object = @import("dom").same_object;
const clock = @import("clock");
const browser_object_lists = @import("dom").browser_object_lists;

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

    /// Entries taken out of the queue that are being wrapped for script
    /// (takeRecords(), the callback's queue): traced from here until the
    /// sequence holds them (`traceHeldNodes`). Empty outside that step.
    delivering: []const *runtime.Instance = &.{},

    /// Parsed threshold values (sorted)
    thresholds: std.ArrayListUnmanaged(f64),

    /// The `thresholds` attribute's frozen array was made (on the first
    /// read) and is kept, so every read returns the same array: the list
    /// never changes after construction. Kept by an edge from the observer's
    /// wrapper (`thresholds_slot`, engine.traceValue), never a root.
    has_thresholds_array: bool = false,

    /// The observer keeps its own wrapper (engine.keepPlatformObjectAlive)
    /// while it observes anything: ONE keep, taken when its first target is
    /// observed and released when its last goes - the keep is counted, so a
    /// keep per observe() would hold the observer until its realm ended.
    kept_alive: bool = false,

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
    }

    /// runtime.VTable.trace_held_nodes (the wrapper redesign's P6, design
    /// 4.4 "Holders"): the queued entries are unwrapped - reached only
    /// through the observer - so their targets are traced from here, each
    /// entry through its own VTable (no impl reaches another). Blink's
    /// IntersectionObserver::Trace reaches its observations_, whose
    /// IntersectionObservation::Trace visits the queued entries_
    /// (core/intersection_observer/intersection_observation.cc, Chromium
    /// 131.0.6778.0). In the collector's atomic pause; reads only.
    pub fn traceHeldNodes(instance: *runtime.Instance, tracer: *engine.Tracer) void {
        const self = Accessor.get(instance) orelse return;
        for (self.queued_entries.items) |entry| traceEntry(entry, tracer);
        for (self.delivering) |entry| traceEntry(entry, tracer);
    }

    fn traceEntry(entry: *runtime.Instance, tracer: *engine.Tracer) void {
        const trace = entry.vtable.trace_held_nodes orelse return;
        trace(entry, tracer);
    }
};

/// Helper to access internal state from instance
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) *InternalState {
    return Accessor.getCast(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // A node torn down stops being observed (dom.intersection_targets).
    @import("dom").intersection_targets.install(.{ .target_destroyed = &targetDestroyed });
    // HTML "update the rendering" step 19: "For each doc of docs, run the
    // update intersection observations steps for doc, passing in the
    // relative high resolution time given now and doc's relevant global
    // object as the timestamp" - Intersection Observer's, which owns the
    // observers' state.
    @import("dom").update_the_rendering.installStep(.intersection_observations, &updateIntersectionObservationsStep);
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
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = InternalState.init(allocator);
    internal.ctx = ctx;

    // Store internal state in instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    leaveObserving(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
        if (internal.has_thresholds_array) engine.forgetTracedChild(instance, thresholds_slot);
        internal.has_thresholds_array = false;
        internal.deinit();
        // Return the block itself, not just what it points to. The comment this
        // replaces said the arena manages it; the arena had no way to, so the
        // struct stayed allocated for the life of the process.
        runtime.arenaOf(instance).destroy(InternalState, internal);
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
    // The observer keeps its array; the binding gets a hold of its own.
    if (internal.has_thresholds_array) {
        if (engine.tracedValue(instance, thresholds_slot)) |array| return array.take();
    }
    const values = try internal.allocator.alloc(runtime.JSValue, internal.thresholds.items.len);
    defer internal.allocator.free(values);
    for (internal.thresholds.items, values) |threshold, *value| value.* = runtime.JSValue.fromNumber(threshold);
    const array = try engine.createFrozenArray(instance.ctx, values);
    engine.traceValue(instance, array.value, thresholds_slot);
    internal.has_thresholds_array = true;
    return array.take();
}

/// Where the observer keeps its `thresholds` array (Blink keeps the
/// thresholds as data and makes the array per read; Crane keeps one array so
/// that every read returns the same object).
const thresholds_slot: engine.TracedSlot = .{ .name = "thresholds" };

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

    // The new registration is processed by the next "run the update
    // intersection observations steps" (HTML "update the rendering" step
    // 19), which also delivers the observer's first notification - from a
    // task, after that update's Resize Observer step (16) has run its
    // callbacks. Crane renders on demand: the document whose step processes
    // this observer asks for that rendering opportunity, as Blink's
    // IntersectionObserver::observe schedules an animation frame
    // (core/intersection_observer/intersection_observer.cc).
    if (observingDocument(internal)) |document| @import("dom").update_the_rendering.requestFrame(document);
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

    // Clear queued entries
    for (internal.queued_entries.items) |entry| {
        runtime.Instance.deinit(entry);
    }
    internal.queued_entries.clearRetainingCapacity();
    holdWhileObserving(instance, internal);
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
    // No entries wait now: an observer that observes nothing leaves the list.
    listWhileActive(instance, internal);

    // 3. Return queue - a sequence<IntersectionObserverEntry>, an Array of
    // the current realm. Wrapping hands each entry to the wrapper cache,
    // which owns them from here; until the sequence holds them they are
    // traced from the observer (the redesign's P6).
    internal.delivering = entries;
    const made = engine.createSequenceOfPlatformObjects(engine.currentRealm() orelse instance.ctx, entries);
    internal.delivering = &.{};
    const array = made catch |err| {
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
        if (!internal.kept_alive) engine.keepPlatformObjectAlive(instance);
        internal.kept_alive = true;
    } else {
        if (internal.kept_alive) engine.releasePlatformObject(instance);
        internal.kept_alive = false;
    }
    listWhileActive(instance, internal);
}

/// The Browser's list (`joinObserving`) holds every observer the update and
/// notify steps can reach: one that observes something, and one whose
/// [[QueuedEntries]] still wait for "notify intersection observers" (its
/// root is still in the DOM tree of its document, so step 2 lists it, though
/// it observes nothing now). Membership is not the keep: an observer that
/// observes nothing may be collected, entries and all.
fn listWhileActive(instance: *runtime.Instance, internal: *InternalState) void {
    if (internal.observations.items.len > 0 or internal.queued_entries.items.len > 0) joinObserving(instance) else leaveObserving(instance);
}

/// The observers that observe something are their Browser's list
/// (dom.browser_object_lists `.intersection_observers`) - what
/// dom.intersection_targets asks when a node is torn down. Found from the
/// observer's and the node's address: one Browser's, whatever realm each is
/// in. It was one list per thread, every Browser's observers in it.
fn joinObserving(instance: *runtime.Instance) void {
    const observing = browser_object_lists.of(instance, .intersection_observers) catch return;
    observing.add(instance) catch {};
}

fn leaveObserving(instance: *runtime.Instance) void {
    const observing = browser_object_lists.existing(instance, .intersection_observers) orelse return;
    observing.remove(instance);
}

/// dom.intersection_targets: `node` is being torn down - it is observed by
/// nothing from now on, and an observer whose last target it was lets its
/// hold go.
fn targetDestroyed(node: *runtime.Instance) void {
    const observing = browser_object_lists.existing(node, .intersection_observers) orelse return;
    var i: usize = 0;
    while (i < observing.slice().len) {
        const observer = observing.slice()[i];
        const internal = getInternal(observer);
        var j: usize = 0;
        var forgot = false;
        while (j < internal.observations.items.len) {
            if (internal.observations.items[j].target.instance == node) {
                _ = internal.observations.orderedRemove(j);
                forgot = true;
            } else j += 1;
        }
        // holdWhileObserving may take the observer out of the list.
        const before = observing.slice().len;
        if (forgot) holdWhileObserving(observer, internal);
        if (observing.slice().len == before) i += 1;
    }
}

/// Drop the observations of targets that have been collected: a collected
/// element is observed by nothing. A node torn down tells its observers
/// itself (dom.intersection_targets); this also catches a slot already
/// reissued when the observer next looks at its targets.
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

/// One observer, as a step or a task took it: callbacks run script, and may
/// drop the last reference to another observer (it disconnects, so its keep
/// goes) and a collection free it before its turn.
const Held = struct {
    observer: *runtime.Instance,
    generation: u64,

    /// The observer's state, if it is still the observer that was taken.
    fn live(self: Held) ?*InternalState {
        if (runtime.SlabAllocator.generationOf(self.observer) != self.generation) return null;
        if (self.observer.getState(State).own._internal == null) return null;
        return getInternal(self.observer);
    }
};

/// The Document whose "run the update intersection observations steps"
/// processes the observer, and whose "notify intersection observers" calls
/// it: the one its root is in the DOM tree of. An explicit root's is the
/// root's node document (or the root, a Document); an implicit root
/// observer's root is "the top-level browsing context's document node"
/// (3.1, the implicit root) - step 1: "For the top-level browsing context,
/// this includes implicit root observers" - the active document of the
/// top-level traversable the observer's Window's document is in. Null for
/// an observer of a realm with no Window (nothing renders there).
fn observingDocument(internal: *InternalState) ?*runtime.Instance {
    if (internal.root) |root| return (interfaces.Node.get_ownerDocument(root) catch null) orelse root;
    const record = internal.ctx.realm orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.vtable != &interfaces.Window.vtable) return null;
    const document = (interfaces.Window.get_document(global) catch null) orelse return null;
    return @import("html").focus.topLevelDocumentOf(document);
}

/// "Run the update intersection observations steps" step 1 and "notify
/// intersection observers" step 2: the IntersectionObservers whose root is
/// in the DOM tree of `document` (`observingDocument`), from the Browser's
/// list (dom.browser_object_lists `.intersection_observers`, in the order
/// they joined it: `listWhileActive`). A snapshot: callbacks may add or
/// remove observers. OWNED by `allocator`.
fn observersOf(document: *runtime.Instance, allocator: std.mem.Allocator) ?[]Held {
    const observing = browser_object_lists.existing(document, .intersection_observers) orelse return null;
    var list: std.ArrayListUnmanaged(Held) = .empty;
    for (observing.slice()) |observer| {
        if (observer.getState(State).own._internal == null) continue;
        if (observingDocument(getInternal(observer)) != document) continue;
        list.append(allocator, .{ .observer = observer, .generation = runtime.SlabAllocator.generationOf(observer) }) catch {
            list.deinit(allocator);
            return null;
        };
    }
    return list.toOwnedSlice(allocator) catch {
        list.deinit(allocator);
        return null;
    };
}

/// HTML "update the rendering" step 19 for `document`: Intersection Observer
/// "run the update intersection observations steps" (3.2.10). The observers'
/// callbacks do not run here: "queue an IntersectionObserverEntry" step 3
/// queues a task to notify them (`queueIntersectionObserverTask`).
///
/// Spec: https://w3c.github.io/IntersectionObserver/#run-the-update-intersection-observations-steps
fn updateIntersectionObservationsStep(document: *runtime.Instance, frame: @import("dom").update_the_rendering.Frame) void {
    // The entries' time keeps computeIntersections' clock (not yet the
    // frame's relative high resolution time).
    _ = frame;
    const allocator = document.ctx.allocator;
    // 1. Let observer list be the IntersectionObservers whose root is in the
    //    DOM tree of document.
    const observers = observersOf(document, allocator) orelse return;
    defer allocator.free(observers);
    var queued = false;
    // 2. For each observer in observer list: for each target, compute its
    //    intersection and queue an IntersectionObserverEntry when its
    //    threshold index or intersecting state changed (computeIntersections).
    for (observers) |held| {
        const internal = held.live() orelse continue;
        forgetCollectedTargets(held.observer, internal);
        computeIntersections(internal) catch |err| {
            std.log.err("IntersectionObserver: computeIntersections failed: {}", .{err});
            continue;
        };
        if (internal.queued_entries.items.len > 0) queued = true;
        listWhileActive(held.observer, internal);
    }
    // "Queue an IntersectionObserverEntry" step 3, once for the step's
    // entries: queue an intersection observer task for document.
    if (queued) queueIntersectionObserverTask(document);
}

/// A queued "notify intersection observers" task's document.
const NotifyTask = struct {
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
    generation: u64,
};

/// Intersection Observer "queue an intersection observer task" (3.2.4) for
/// `document`.
///
/// Spec: https://w3c.github.io/IntersectionObserver/#queue-intersection-observer-task
fn queueIntersectionObserverTask(document: *runtime.Instance) void {
    const document_internals = @import("dom").document_internals;
    // 1. If document's IntersectionObserverTaskQueued flag is set to true,
    //    return.
    if (document_internals.intersectionObserverTaskQueued(document)) return;
    const loop = document.ctx.getOptionalEventLoop() orelse return;
    const allocator = document.ctx.allocator;
    // Out of memory, the task is not queued now and nothing is lost: the
    // entries stay in their observers' [[QueuedEntries]] and the flag stays
    // false, so the next update - asked for here - queues it (its step finds
    // the entries waiting). A rendering step has no caller to report to (HTML
    // "update the rendering" has no failure path; its steps return nothing),
    // and Crane's other steps drop an allocation failure the same way
    // (Document's reveal step, ResizeObserver's gather).
    const task = allocator.create(NotifyTask) catch return retryNextFrame(document);
    const generation = runtime.SlabAllocator.generationOf(document);
    task.* = .{ .allocator = allocator, .document = document, .generation = generation };
    // 2. Set document's IntersectionObserverTaskQueued flag to true.
    document_internals.setIntersectionObserverTaskQueued(document, true) catch {
        allocator.destroy(task);
        return retryNextFrame(document);
    };
    // 3. Queue a task on the IntersectionObserver task source associated
    //    with the document's event loop to notify intersection observers.
    //    The task's document is `document`: one that can never be fully
    //    active again drops it (`dropNotifyTask`).
    loop.queueTask(.{
        .callback = notifyIntersectionObservers,
        .context = task,
        .drop = dropNotifyTask,
        .document = document,
        .document_generation = generation,
    });
}

/// The update that could not queue its task asks for the next rendering
/// opportunity, whose step queues it.
fn retryNextFrame(document: *runtime.Instance) void {
    @import("dom").update_the_rendering.requestFrame(document);
}

/// The task never runs (its loop ends, or its document can never be fully
/// active again): its context goes, and the flag with it, if the document
/// is still the one it was queued for.
fn dropNotifyTask(data: ?*anyopaque) void {
    const task: *NotifyTask = @ptrCast(@alignCast(data orelse return));
    if (runtime.SlabAllocator.generationOf(task.document) == task.generation) {
        @import("dom").document_internals.setIntersectionObserverTaskQueued(task.document, false) catch {};
    }
    task.allocator.destroy(task);
}

/// Intersection Observer "notify intersection observers" (3.2.5) for the
/// task's document.
///
/// Spec: https://w3c.github.io/IntersectionObserver/#notify-intersection-observers-algo
fn notifyIntersectionObservers(data: ?*anyopaque) void {
    const task: *NotifyTask = @ptrCast(@alignCast(data orelse return));
    const document = task.document;
    const generation = task.generation;
    task.allocator.destroy(task);
    if (runtime.SlabAllocator.generationOf(document) != generation) return;
    // 1. Set document's IntersectionObserverTaskQueued flag to false.
    @import("dom").document_internals.setIntersectionObserverTaskQueued(document, false) catch {};
    // 2. Let notify list be a list of all IntersectionObservers whose root
    //    is in the DOM tree of document.
    const allocator = document.ctx.allocator;
    const observers = observersOf(document, allocator) orelse return;
    defer allocator.free(observers);
    // 3. For each observer in notify list: 3.1-3.5 (invokeCallback). A
    //    callback may end another observer, which `live` sees.
    for (observers) |held| {
        const internal = held.live() orelse continue;
        invokeCallback(internal) catch |err| {
            std.log.err("IntersectionObserver: invokeCallback failed: {}", .{err});
        };
        // Its entries delivered, an observer that observes nothing leaves
        // the list (`listWhileActive`).
        if (held.live()) |after| listWhileActive(held.observer, after);
    }
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
        // The entry made below takes the rect; an observation that queues
        // none lets it go (nothing else ever names it).
        const bounding_generation = runtime.SlabAllocator.generationOf(bounding_rect);
        var bounding_taken = false;
        defer if (!bounding_taken) bounding_rect.releaseIfUnwrapped(bounding_generation);

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
            const root_generation = runtime.SlabAllocator.generationOf(root_bounds);
            var rects_taken = false;
            defer if (!rects_taken) root_bounds.releaseIfUnwrapped(root_generation);

            // Create intersection rect
            const intersection_rect = try interfaces.DOMRectReadOnly.call_constructor(
                internal.ctx,
                webidl.Opt(f64).passed(if (is_intersecting) intersect_left else 0),
                webidl.Opt(f64).passed(if (is_intersecting) intersect_top else 0),
                webidl.Opt(f64).passed(intersect_width),
                webidl.Opt(f64).passed(intersect_height),
            );
            const intersection_generation = runtime.SlabAllocator.generationOf(intersection_rect);
            defer if (!rects_taken) intersection_rect.releaseIfUnwrapped(intersection_generation);

            // Create the entry: it takes the three rects and holds the target.
            const entry = try interfaces.IntersectionObserverEntry.initWith(internal.ctx.allocator, internal.ctx, .{
                .time = time,
                .root_bounds = @as(?*runtime.Instance, root_bounds),
                .bounding_client_rect = bounding_rect,
                .intersection_rect = intersection_rect,
                .is_intersecting = is_intersecting,
                .is_visible = false, // isVisible (would need visibility computation)
                .intersection_ratio = intersection_ratio,
                .target = target,
            });
            rects_taken = true;
            bounding_taken = true;

            // Queue the entry
            internal.queued_entries.append(internal.allocator, entry) catch |err| {
                runtime.Instance.deinit(entry);
                return err;
            };

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
    // entry to the wrapper cache, which owns them from here; until the
    // sequence holds them they are traced from the observer (P6).
    internal.delivering = queue;
    const made = engine.createSequenceOfPlatformObjects(realm, queue);
    internal.delivering = &.{};
    const entries = made catch |err| {
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
