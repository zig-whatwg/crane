//! Implementation for ResizeObserver interface
//!
//! Spec: https://drafts.csswg.org/resize-observer-1/
//!
//! The observer keeps its [[callback]], its [[observationTargets]] (each a
//! ResizeObservation: the target, the observed box, the last reported size)
//! and, between a gather and its broadcast, its [[activeTargets]] and whether
//! it skipped any. HTML "update the rendering" step 16.2.5-16.3 runs the
//! gather/broadcast loop for each document (dom.resize_observations, the
//! hook this type installs), after the step's style update.
//!
//! Sizes come from the platform's layout (`platform.layoutBox`: the border
//! box is its offset rect, the content box its client rect less the
//! padding). A platform that lays out nothing - Crane's own headless
//! platforms - gives no box: every size is 0x0, as for an element that has
//! none (display: none), so an observation is delivered once, when it
//! starts (its last reported size begins at -1 x -1).
//!
//! Lifetime (3.5): the observer lives while script references it or it
//! observes a target - it keeps its own wrapper while it observes anything
//! (engine.keepPlatformObjectAlive, as IntersectionObserver does) and is on
//! its Browser's list of observing ResizeObservers
//! (dom.browser_object_lists `.resize_observers`). Targets are weak links: a
//! collected element is observed by nothing.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const same_object = dom.same_object;
const browser_object_lists = dom.browser_object_lists;
const ResizeObserver = interfaces.ResizeObserver;
const Size = dom.resize_observations.Size;

pub const State = ResizeObserver.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// The box a ResizeObservation watches (ResizeObserverBoxOptions).
const Box = enums.ResizeObserverBoxOptions;

/// A ResizeObservation (3.1).
const Observation = struct {
    /// The target, weakly: a collected element is observed by nothing.
    target: same_object.Link,
    observed_box: Box,
    /// lastReportedSizes' one entry; (-1, -1) until the first broadcast.
    last_reported: Size = .{ .inline_size = -1, .block_size = -1 },
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// [[callback]], OWNED.
    callback: ?engine.CallbackFunction = null,
    /// [[observationTargets]].
    observations: std.ArrayListUnmanaged(Observation) = .empty,
    /// [[activeTargets]]: the targets, looked up again at the broadcast
    /// (another observer's callback may unobserve one in between).
    active: std.ArrayListUnmanaged(same_object.Link) = .empty,
    /// [[skippedTargets]] is not empty.
    skipped: bool = false,
    /// The observer keeps its own wrapper while it observes anything.
    kept_alive: bool = false,
    /// The entries being wrapped for the callback: traced from here until
    /// the sequence holds them.
    delivering: []const *runtime.Instance = &.{},
    self_instance: ?*runtime.Instance = null,

    fn deinit(self: *InternalState) void {
        if (self.callback) |callback| callback.release();
        self.callback = null;
        self.observations.deinit(self.allocator);
        self.active.deinit(self.allocator);
    }

    /// runtime.VTable.trace_held_nodes: entries being wrapped reach their
    /// targets through their own trace.
    pub fn traceHeldNodes(instance: *runtime.Instance, tracer: *engine.Tracer) void {
        const self = Accessor.get(instance) orelse return;
        for (self.delivering) |entry| {
            const trace = entry.vtable.trace_held_nodes orelse continue;
            trace(entry, tracer);
        }
    }
};

const Accessor = webidl.utils.InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) *InternalState {
    return Accessor.getCast(instance);
}

/// The hooks this type owns, installed once at process start.
pub fn installHooks() void {
    dom.resize_observations.install(.{ .run = runSteps });
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
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    leaveObserving(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
        internal.deinit();
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
}

/// new ResizeObserver(callback): 1-3. The [[callback]] (the binding hands
/// the converted function over) and an empty [[observationTargets]]. 4. "Add
/// this to Document.[[resizeObservers]]": the observers a document runs are
/// those of its realm that observe something (`runSteps`), so an observer
/// joins its Browser's list when it starts observing.
pub fn call_constructor(ctx: runtime.Context, callback: callbacks.ResizeObserverCallback) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &ResizeObserver.vtable, ctx);
    errdefer deinit(instance);
    const internal = getInternal(instance);
    internal.self_instance = instance;
    internal.callback = engine.takeCallbackFunction(@ptrCast(callback));
    return instance;
}

/// observe(target, options)
pub fn call_observe(instance: *runtime.Instance, target: *runtime.Instance, options: webidl.Opt(dictionaries.ResizeObserverOptions)) anyerror!void {
    const internal = getInternal(instance);
    forgetCollectedTargets(instance, internal);
    // 1. If target is in [[observationTargets]], call unobserve() with it.
    try call_unobserve(instance, target);
    // 2. Let observedBox be options' box.
    const opts = if (options.was_passed) options.value else dictionaries.ResizeObserverOptions{};
    const observed_box: Box = opts.box orelse ._content_box_;
    // 3-4. A new ResizeObservation(target, observedBox), added.
    try internal.observations.append(internal.allocator, .{ .target = same_object.Link.to(target), .observed_box = observed_box });
    holdWhileObserving(instance, internal);
    // The observation is delivered at the next rendering opportunity of the
    // target's document.
    if (interfaces.Node.get_ownerDocument(target) catch null) |document| dom.update_the_rendering.requestFrame(document);
}

/// unobserve(target)
pub fn call_unobserve(instance: *runtime.Instance, target: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance);
    // 1-3. The observation whose target is target, removed if found.
    for (internal.observations.items, 0..) |observation, i| {
        if (observation.target.instance == target and observation.target.isLive()) {
            _ = internal.observations.orderedRemove(i);
            break;
        }
    }
    holdWhileObserving(instance, internal);
}

/// disconnect(): 1. Clear [[observationTargets]]. 2. Clear [[activeTargets]].
pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance);
    internal.observations.clearRetainingCapacity();
    internal.active.clearRetainingCapacity();
    internal.skipped = false;
    holdWhileObserving(instance, internal);
}

// ============================================================================
// Lifetime
// ============================================================================

/// 3.5: alive while observing - the observer's own wrapper kept (one keep)
/// and on its Browser's list while it observes anything.
fn holdWhileObserving(instance: *runtime.Instance, internal: *InternalState) void {
    if (internal.observations.items.len > 0) {
        if (!internal.kept_alive) engine.keepPlatformObjectAlive(instance);
        internal.kept_alive = true;
        const observing = browser_object_lists.of(instance, .resize_observers) catch return;
        observing.add(instance) catch {};
    } else {
        if (internal.kept_alive) engine.releasePlatformObject(instance);
        internal.kept_alive = false;
        leaveObserving(instance);
    }
}

fn leaveObserving(instance: *runtime.Instance) void {
    const observing = browser_object_lists.existing(instance, .resize_observers) orelse return;
    observing.remove(instance);
}

/// A collected target is observed by nothing.
fn forgetCollectedTargets(instance: *runtime.Instance, internal: *InternalState) void {
    var i: usize = 0;
    var forgot = false;
    while (i < internal.observations.items.len) {
        if (!internal.observations.items[i].target.isLive()) {
            _ = internal.observations.orderedRemove(i);
            forgot = true;
        } else i += 1;
    }
    if (forgot) holdWhileObserving(instance, internal);
}

// ============================================================================
// HTML "update the rendering" 16.2.5-16.3 (dom.resize_observations)
// ============================================================================

/// An observer of a snapshot, with its slab generation: a callback may drop
/// the last reference to another observer of the snapshot (it disconnects,
/// so its own keep goes) and a collection free it before its turn.
const Held = struct {
    observer: *runtime.Instance,
    generation: u64,

    /// The observer's state, if it is still the observer the snapshot took.
    fn live(self: Held) ?*InternalState {
        if (runtime.SlabAllocator.generationOf(self.observer) != self.generation) return null;
        return Accessor.get(self.observer);
    }
};

/// The observers of `document` - Document.[[resizeObservers]]: those of its
/// realm (an observer belongs to the document of the global it was made in)
/// that observe something, on its Browser's list. A snapshot: callbacks may
/// add or remove observers. OWNED by `allocator`.
fn observersOf(document: *runtime.Instance, allocator: std.mem.Allocator) ?[]Held {
    const observing = browser_object_lists.existing(document, .resize_observers) orelse return null;
    var list: std.ArrayListUnmanaged(Held) = .empty;
    for (observing.slice()) |observer| {
        if (observer.ctx != document.ctx) continue;
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

/// Step 16.2.5-16.3 for `document`.
fn runSteps(document: *runtime.Instance) void {
    const allocator = document.ctx.allocator;
    // 16.2.5. Let depth be 0.
    var depth: usize = 0;
    // 16.2.6. Gather active resize observations at depth depth for doc.
    gather(document, allocator, depth);
    // 16.2.7. While doc has active resize observations:
    while (hasActive(document, allocator)) {
        // 1. Set depth to the result of broadcasting active resize
        //    observations given doc.
        depth = broadcast(document, allocator);
        // 2. Recalculate styles and update layout for doc: Crane computes
        //    style at each read (calculateBoxSize reads the resolved style
        //    and the platform's box afresh), and layout is the renderer's.
        // 3. Gather active resize observations at depth depth for doc.
        gather(document, allocator, depth);
    }
    // 16.3. If doc has skipped resize observations, then deliver resize loop
    // error given doc.
    if (hasSkipped(document, allocator)) deliverLoopError(document);
}

/// 3.4.1 Gather active resize observations at depth.
fn gather(document: *runtime.Instance, allocator: std.mem.Allocator, depth: usize) void {
    const observers = observersOf(document, allocator) orelse return;
    defer allocator.free(observers);
    for (observers) |held| {
        const internal = held.live() orelse continue;
        forgetCollectedTargets(held.observer, internal);
        // 1. Clear [[activeTargets]] and [[skippedTargets]].
        internal.active.clearRetainingCapacity();
        internal.skipped = false;
        // 2. For each observation: active ones deeper than depth are
        //    active, the rest skipped.
        for (internal.observations.items) |observation| {
            const target = observation.target.instance;
            const current = calculateBoxSize(target, observation.observed_box);
            if (current.inline_size == observation.last_reported.inline_size and current.block_size == observation.last_reported.block_size) continue;
            if (depthOf(target) > depth) {
                internal.active.append(internal.allocator, observation.target) catch {};
            } else internal.skipped = true;
        }
    }
}

/// 3.4.2 Has active resize observations.
fn hasActive(document: *runtime.Instance, allocator: std.mem.Allocator) bool {
    const observers = observersOf(document, allocator) orelse return false;
    defer allocator.free(observers);
    for (observers) |held| if (held.live()) |internal| if (internal.active.items.len > 0) return true;
    return false;
}

/// 3.4.3 Has skipped resize observations.
fn hasSkipped(document: *runtime.Instance, allocator: std.mem.Allocator) bool {
    const observers = observersOf(document, allocator) orelse return false;
    defer allocator.free(observers);
    for (observers) |held| if (held.live()) |internal| if (internal.skipped) return true;
    return false;
}

/// 3.4.5 Broadcast active resize observations: the shallowest broadcast
/// target's depth.
fn broadcast(document: *runtime.Instance, allocator: std.mem.Allocator) usize {
    // 1. Let shallowestTargetDepth be infinity.
    var shallowest: usize = std.math.maxInt(usize);
    const observers = observersOf(document, allocator) orelse return shallowest;
    defer allocator.free(observers);
    // 2. For each observer:
    for (observers) |held| {
        const internal = held.live() orelse continue;
        const observer = held.observer;
        // 1. If [[activeTargets]] is empty, continue.
        if (internal.active.items.len == 0) continue;
        // 2. Let entries be an empty list.
        var entries: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
        defer entries.deinit(allocator);
        // 3. For each observation in [[activeTargets]]:
        for (internal.active.items) |link| {
            if (!link.isLive()) continue;
            const observation = findObservation(internal, link.instance) orelse continue;
            // 1-2. Create and populate an entry, add it.
            const made = createEntry(observer.ctx, link.instance) orelse continue;
            entries.append(allocator, made.entry) catch {
                runtime.Instance.deinit(made.entry);
                continue;
            };
            // 3. lastReportedSizes = the entry's sizes of the observed box.
            observation.last_reported = switch (observation.observed_box) {
                ._border_box_ => made.border_box,
                ._content_box_ => made.content_box,
                ._device_pixel_content_box_ => made.device_pixel_content_box,
            };
            // 4-5. The shallowest target depth.
            shallowest = @min(shallowest, depthOf(link.instance));
        }
        // 5. Clear [[activeTargets]] (before the callback: it may observe
        //    again).
        internal.active.clearRetainingCapacity();
        // 4. Invoke [[callback]] with entries and observer, observer as the
        //    callback this value; report what it throws.
        invokeCallback(observer, internal, entries.items) catch {};
    }
    // 3. Return shallowestTargetDepth.
    return shallowest;
}

fn findObservation(internal: *InternalState, target: *runtime.Instance) ?*Observation {
    for (internal.observations.items) |*observation| {
        if (observation.target.instance == target and observation.target.isLive()) return observation;
    }
    return null;
}

const MadeEntry = struct {
    entry: *runtime.Instance,
    border_box: Size,
    content_box: Size,
    device_pixel_content_box: Size,
};

/// 3.4.4 Create and populate a ResizeObserverEntry for `target`, in the
/// observer's realm. Null when it cannot be made.
fn createEntry(realm: runtime.Context, target: *runtime.Instance) ?MadeEntry {
    // 3-5. The three sizes.
    const border_box = calculateBoxSize(target, ._border_box_);
    const content_box = calculateBoxSize(target, ._content_box_);
    const device_pixel_content_box = calculateBoxSize(target, ._device_pixel_content_box_);
    // 6-8. contentRect: the content box at (padding left, padding top) -
    // all zero for a target with no layout box (Blink's ResizeObserverEntry
    // for an element with no LayoutObject).
    const padding: Padding = if (layoutBoxOf(target) != null) paddingOf(target) else .{};
    const rect = interfaces.DOMRectReadOnly.call_constructor(
        realm,
        webidl.Opt(f64).passed(padding.left),
        webidl.Opt(f64).passed(padding.top),
        webidl.Opt(f64).passed(content_box.inline_size),
        webidl.Opt(f64).passed(content_box.block_size),
    ) catch return null;
    const rect_generation = runtime.SlabAllocator.generationOf(rect);
    const entry = interfaces.ResizeObserverEntry.initWith(realm.allocator, realm, .{
        .target = target,
        .content_rect = rect,
        .border_box = border_box,
        .content_box = content_box,
        .device_pixel_content_box = device_pixel_content_box,
    }) catch {
        rect.releaseIfUnwrapped(rect_generation);
        return null;
    };
    return .{ .entry = entry, .border_box = border_box, .content_box = content_box, .device_pixel_content_box = device_pixel_content_box };
}

/// 3.4.5 step 2.4: invoke the callback with the entries as a sequence.
fn invokeCallback(observer: *runtime.Instance, internal: *InternalState, entries: []const *runtime.Instance) !void {
    if (entries.len == 0) return;
    const callback = internal.callback orelse {
        for (entries) |entry| runtime.Instance.deinit(entry);
        return;
    };
    const realm = observer.ctx;
    // Wrapping hands each entry to the wrapper cache, which owns them from
    // here; until the sequence holds them they are traced from the observer.
    internal.delivering = entries;
    const made = engine.createSequenceOfPlatformObjects(realm, entries);
    internal.delivering = &.{};
    const sequence = made catch |err| {
        for (entries) |entry| runtime.Instance.deinit(entry);
        return err;
    };
    defer sequence.release();
    const this_value: runtime.JSValue = .{ .instance = observer };
    const completion = try engine.invokeCallbackFunction(realm, &callback, .{ .value = this_value }, &.{ sequence.value, this_value }, .{
        .report = .{ .report = reportException, .host = realm },
    });
    switch (completion) {
        inline else => |value| value.release(),
    }
}

/// HTML "report an exception" for the callback's realm's global - or else
/// the observer's (`host`).
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const observer_realm: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse observer_realm;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

/// 3.4.6 Deliver resize loop error notification: an ErrorEvent whose message
/// is "ResizeObserver loop completed with undelivered notifications.",
/// reported for the document's global (Chrome, Firefox and Safari use this
/// message, with no error value).
fn deliverLoopError(document: *runtime.Instance) void {
    const record = document.ctx.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const info: runtime.ErrorInfo = .{
        .message = "ResizeObserver loop completed with undelivered notifications.",
        .filename = "",
        .lineno = 0,
        .colno = 0,
        .error_value = null,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &info, .{});
}

// ============================================================================
// CSS: depth and box sizes
// ============================================================================

/// 3.4.7 Calculate depth for node: the number of nodes on the parent path
/// from `node` to the root of its flattened tree - each step the node's
/// assigned slot, else its parent, a shadow root's host for a shadow root's
/// child (Blink's ResizeObservation::TargetDepth walks FlatTreeTraversal's
/// parents alike). Only the comparison between depths matters.
fn depthOf(node: *runtime.Instance) usize {
    var depth: usize = 0;
    var current: ?*runtime.Instance = node;
    while (current) |n| : (depth += 1) current = flatParentOf(n);
    return depth;
}

fn flatParentOf(node: *runtime.Instance) ?*runtime.Instance {
    if (dom.shadow_dom_algorithms.assignedSlotOf(node)) |slot| return slot;
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return null;
    if (parent.vtable == &interfaces.ShadowRoot.vtable) return interfaces.ShadowRoot.get_host(parent) catch null;
    return parent;
}

/// The target's layout box from the platform, if it lays out and gives one.
fn layoutBoxOf(target: *runtime.Instance) ?@import("platform").BoxMetrics {
    const platform = @import("platform");
    if (platform.capabilities.layout == .unsupported) {
        return null;
    } else {
        const browser = @import("html").platform_state.of(target.ctx) orelse return null;
        const document = interfaces.Node.get_ownerDocument(target) catch null;
        return platform.layoutBox(browser, dom.image_sources.layoutNode(document), dom.image_sources.layoutNode(target));
    }
}

const Padding = struct { top: f64 = 0, right: f64 = 0, bottom: f64 = 0, left: f64 = 0 };

/// The target's padding, from its resolved style (CSSOM's resolved value of
/// a padding is the used value). The renderer protocol gives a box's offset
/// (border box) and client (padding box) rects, not its content box, so the
/// content box is the client box less this. TODO(renderer): a percentage
/// padding resolves against the containing block, which only the renderer
/// knows - it reads as 0 here until the protocol gives the content box.
fn paddingOf(target: *runtime.Instance) Padding {
    var padding: Padding = .{};
    const style = (dom.style.engine.computedStyle(target, null) catch return padding) orelse return padding;
    const allocator = target.ctx.allocator;
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    inline for (.{ .{ "top", .padding_top }, .{ "right", .padding_right }, .{ "bottom", .padding_bottom }, .{ "left", .padding_left } }) |side| {
        text.clearRetainingCapacity();
        style.serializeResolved(side[1], &text, allocator) catch {};
        if (std.mem.endsWith(u8, text.items, "px")) {
            @field(padding, side[0]) = std.fmt.parseFloat(f64, text.items[0 .. text.items.len - 2]) catch 0;
        }
    }
    return padding;
}

/// Whether the target's writing mode is vertical: its inline axis is the
/// vertical one.
fn isVertical(target: *runtime.Instance) bool {
    const style = (dom.style.engine.computedStyle(target, null) catch return false) orelse return false;
    return style.keyword(.writing_mode) != .horizontal_tb;
}

/// 3.4.8 Calculate box size, given target and observed box. A target with
/// no layout box - every target, without a platform that lays out - is 0x0.
fn calculateBoxSize(target: *runtime.Instance, observed_box: Box) Size {
    const box = layoutBoxOf(target) orelse return .{};
    // The physical width and height of the observed box.
    var width: f64 = 0;
    var height: f64 = 0;
    switch (observed_box) {
        // 1. border-box: the border area's dimensions.
        ._border_box_ => {
            width = box.offset.width;
            height = box.offset.height;
        },
        // 2. content-box: the content area's dimensions. 3.
        //    device-pixel-content-box: the content area's in integral device
        //    pixels.
        ._content_box_, ._device_pixel_content_box_ => {
            const padding = paddingOf(target);
            width = @max(0, box.client.width - padding.left - padding.right);
            height = @max(0, box.client.height - padding.top - padding.bottom);
            if (observed_box == ._device_pixel_content_box_) {
                const ratio = devicePixelRatioOf(target);
                width = @round(width * ratio);
                height = @round(height * ratio);
            }
        },
    }
    // inlineSize is the length in the inline axis, blockSize in the block
    // axis: a vertical writing mode swaps them.
    if (isVertical(target)) return .{ .inline_size = height, .block_size = width };
    return .{ .inline_size = width, .block_size = height };
}

fn devicePixelRatioOf(target: *runtime.Instance) f64 {
    const record = target.ctx.getRealm() orelse return 1;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return 1));
    return interfaces.Window.get_devicePixelRatio(window) catch 1;
}
