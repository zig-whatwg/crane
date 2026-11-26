//! HTML 8.1.7.3 steps 20 and 21: Long Animation Frames "record rendering time"
//! and Paint Timing "mark paint timing".
//!
//! Spec: https://w3c.github.io/long-animation-frames/#record-rendering-time
//! Spec: https://w3c.github.io/paint-timing/#mark-paint-timing
//!
//! Both steps share per-Browser lazy state (`State` on `BrowserScope`) and are
//! strictly read-only when no frame timing info is active (zero allocations and
//! zero clock reads on idle frames).
//!
//! Sub-steps that require a renderer (`needs-renderer`) or unexposed WebIDL:
//! - Paint Timing §5.3.2 steps 3–6 and 10.1–10.4 (`paintedImages`,
//!   `paintedTextNodes`, `first-paint`, `first-contentful-paint`, Largest
//!   Contentful Paint, Element Timing): require a renderer to compute paintable
//!   bounding rects (`getBoundingClientRect()` clipped to the scrolling area,
//!   Paint Timing §2), non-default background paint, and font block period for
//!   painted text. Per the integrator's ruling of 2026-11-18
//!   (`tools/wpt_gate_exemptions.txt`, `performance-timeline/getEntriesByName-sort.html`),
//!   `"paint"` stays out of `PerformanceObserver.supportedEntryTypes` and
//!   `PerformancePaintTiming` stays a stub until a renderer reports painted
//!   content.
//! - Long Animation Frames (`TODO(loaf)`): `recordRenderingTime` (step 20) and
//!   its handoff to `markPaintTiming` (step 21 steps 8–9, 10.5, 11) implement
//!   the full rendering-time algorithm without layout/geometry; full LoAF
//!   exposure to script awaits event-loop task/script entry-point capture and
//!   enabling `PerformanceLongAnimationFrameTiming` / `PerformanceScriptTiming`
//!   in V8 bindings and `PerformanceObserver.supportedEntryTypes`.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const platform = @import("platform");
const same_object = @import("same_object.zig");
const navigable_container = @import("navigable_container.zig");
const document_activity = @import("document_activity.zig");
const document_origin = @import("document_origin.zig");
const origin_record = @import("origin_record.zig");
const global_settings = @import("global_settings.zig");
const performance_timeline = @import("performance_timeline.zig");
const update_the_rendering = @import("update_the_rendering.zig");

const Instance = runtime.Instance;

/// Long Animation Frames §2: threshold above which a frame is a long animation
/// frame (50 milliseconds).
pub const long_frame_threshold_ms: f64 = 50.0;

/// Paint Timing §3.1: `paint timing info` struct.
pub const PaintTimingInfo = struct {
    /// Rendering update end time (DOMHighResTimeStamp, ms).
    rendering_update_end_time: f64 = 0,
    /// Implementation-defined presentation time, or null when unsupported.
    /// Crane has no display compositor, so this is always null (Paint Timing
    /// §5.3.2 step 11).
    presentation_time: ?f64 = null,

    /// Paint Timing §3.1 "default paint timestamp".
    pub fn defaultPaintTimestamp(self: PaintTimingInfo) f64 {
        return self.presentation_time orelse self.rendering_update_end_time;
    }
};

/// Long Animation Frames §3.1: one style or layout period recorded outside
/// script execution.
pub const StyleOrLayoutKind = enum { style, layout };

pub const StyleAndLayoutPeriod = struct {
    kind: StyleOrLayoutKind,
    /// Coarsened timestamps in milliseconds.
    start_time_ms: f64,
    end_time_ms: f64,
};

/// Long Animation Frames §3.1: `frame timing info` struct.
pub const FrameTimingInfo = struct {
    /// Unsafe monotonic timestamps (ns).
    start_time_ns: i64 = 0,
    current_task_start_time_ns: i64 = 0,
    update_the_rendering_start_time_ns: i64 = 0,
    style_and_layout_start_time_ns: i64 = 0,
    end_time_ns: i64 = 0,
    /// Accumulated style and layout durations within the rendering update (ms).
    style_duration_ms: f64 = 0,
    layout_duration_ms: f64 = 0,
    cross_origin_isolated: bool = false,
    periods: std.ArrayListUnmanaged(StyleAndLayoutPeriod) = .empty,

    pub fn deinit(self: *FrameTimingInfo, allocator: Allocator) void {
        self.periods.deinit(allocator);
    }
};

/// Snapshot of a completed long animation frame handed out by step 20 (for
/// non-paint-timing-eligible documents) or step 21 (for paint-timing-eligible
/// documents). Retains no pointers into mutable lists.
pub const CompletedFrame = struct {
    document: same_object.Link,
    start_time_ns: i64,
    update_the_rendering_start_time_ns: i64,
    style_and_layout_start_time_ns: i64,
    end_time_ns: i64,
    style_duration_ms: f64,
    layout_duration_ms: f64,
    paint: PaintTimingInfo,
};

const ActiveEntry = struct {
    root: same_object.Link,
    info: FrameTimingInfo,
};

/// Per-Browser supplement holding active `current frame timing info` per
/// nearest same-origin root document and completed frame records. Created
/// lazily only when `recordTaskStartTime` is called.
pub const State = struct {
    allocator: Allocator,
    active: std.ArrayListUnmanaged(ActiveEntry) = .empty,
    /// Completed frames recorded by steps 20/21. Bounded so native/host
    /// recording cannot grow unbounded before LoAF PerformanceTimeline
    /// integration consumes it.
    completed: std.ArrayListUnmanaged(CompletedFrame) = .empty,

    const max_completed: usize = 64;

    pub fn init(allocator: Allocator) State {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *State) void {
        for (self.active.items) |*entry| entry.info.deinit(self.allocator);
        self.active.deinit(self.allocator);
        self.completed.deinit(self.allocator);
    }

    fn findActiveIndex(self: *const State, root: *Instance) ?usize {
        const gen = runtime.SlabAllocator.generationOf(root);
        for (self.active.items, 0..) |entry, i| {
            if (entry.root.instance == root and entry.root.generation == gen) return i;
        }
        return null;
    }

    fn pruneDead(self: *State) void {
        var i: usize = 0;
        while (i < self.active.items.len) {
            if (!self.active.items[i].root.isLive()) {
                var removed = self.active.orderedRemove(i);
                removed.info.deinit(self.allocator);
            } else i += 1;
        }
    }

    fn pushCompleted(self: *State, entry: CompletedFrame) void {
        if (self.completed.items.len >= max_completed) {
            _ = self.completed.orderedRemove(0);
        }
        self.completed.append(self.allocator, entry) catch {};
    }
};

/// Long Animation Frames §3.2.1: "nearest same-origin root" for `document`.
/// Walks ancestor navigables from outermost down, returning the first ancestor
/// active document that is same-origin and shares `document`'s relevant agent,
/// or `document` itself if none matches.
pub fn nearestSameOriginRoot(document: *Instance) *Instance {
    // 1. Collect ancestor documents from innermost to outermost.
    var ancestors: [64]*Instance = undefined;
    var count: usize = 0;
    var current = document;
    while (count < ancestors.len) {
        const window = (interfaces.Document.get_defaultView(current) catch null) orelse break;
        const container = navigable_container.of(window) orelse break;
        const parent_doc = (interfaces.Node.get_ownerDocument(container) catch null) orelse break;
        if (parent_doc == current) break;
        ancestors[count] = parent_doc;
        count += 1;
        current = parent_doc;
    }
    // 2. Check outermost ancestor first (top-down order matches HTML's
    //    "ancestor navigables" ordering).
    var i = count;
    while (i > 0) {
        i -= 1;
        const ancestor = ancestors[i];
        if (ancestor.ctx.agent != document.ctx.agent) continue;
        if (documentsSameOrigin(ancestor, document)) return ancestor;
    }
    // 3. Return document.
    return document;
}

fn documentsSameOrigin(a: *Instance, b: *Instance) bool {
    if (a == b) return true;
    const a_rec = (document_origin.shareable(a) catch null) orelse return false;
    const b_rec = (document_origin.shareable(b) catch null) orelse return false;
    return origin_record.sameOrigin(
        .{ .serialized = a_rec.serialized orelse "null", .record = a_rec },
        .{ .serialized = b_rec.serialized orelse "null", .record = b_rec },
    );
}

/// Paint Timing §2: whether `document`'s browsing context is paint-timing
/// eligible. A top-level browsing context is eligible; nested browsing
/// contexts are not configured to report paint timing in Crane.
pub fn isPaintTimingEligible(document: *Instance) bool {
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return false;
    return navigable_container.of(window) == null;
}

/// Long Animation Frames §3.2.1: "record task start time" given
/// `unsafe_task_start_ns` (monotonic ns) and `document`.
pub fn recordTaskStartTime(document: *Instance, unsafe_task_start_ns: i64) void {
    // 1. If document is not fully active or visibilityState is "hidden", return.
    if (!isVisibleAndFullyActive(document)) return;
    // 2. Let root be document's nearest same-origin root.
    const root = nearestSameOriginRoot(document);
    // 3. If root is not fully active or visibilityState is "hidden", return.
    if (root != document and !isVisibleAndFullyActive(root)) return;

    const scope = runtime.BrowserScope.ofInstance(root);
    const state = scope.of(State) catch return;
    state.pruneDead();

    // 4-5. Ensure current frame timing info on root, then update current task start time.
    if (state.findActiveIndex(root)) |idx| {
        state.active.items[idx].info.current_task_start_time_ns = unsafe_task_start_ns;
        return;
    }
    const cross_origin_isolated = blk: {
        const window = (interfaces.Document.get_defaultView(root) catch null) orelse break :blk false;
        const settings = global_settings.of(window) orelse break :blk false;
        break :blk settings.cross_origin_isolated(window);
    };
    state.active.append(state.allocator, .{
        .root = same_object.Link.to(root),
        .info = .{
            .start_time_ns = unsafe_task_start_ns,
            .current_task_start_time_ns = unsafe_task_start_ns,
            .cross_origin_isolated = cross_origin_isolated,
        },
    }) catch {};
}

/// Append a style or layout period (with coarsened ms timestamps) to `document`'s
/// relevant frame timing info, if active. Read-only when inactive.
pub fn recordStyleOrLayoutPeriod(document: *Instance, kind: StyleOrLayoutKind, start_time_ms: f64, end_time_ms: f64) void {
    const state = runtime.BrowserScope.ofInstance(document).existing(State) orelse return;
    const root = nearestSameOriginRoot(document);
    const idx = state.findActiveIndex(root) orelse return;
    state.active.items[idx].info.periods.append(state.allocator, .{
        .kind = kind,
        .start_time_ms = start_time_ms,
        .end_time_ms = end_time_ms,
    }) catch {};
}

/// Clear `document`'s current frame timing info (e.g. when visibility becomes
/// hidden or document ceases to be fully active — LoAF §3.2.1). Read-only when
/// inactive.
pub fn clearCurrentFrameTimingInfo(document: *Instance) void {
    const state = runtime.BrowserScope.ofInstance(document).existing(State) orelse return;
    const idx = state.findActiveIndex(document) orelse return;
    var removed = state.active.orderedRemove(idx);
    removed.info.deinit(state.allocator);
}

/// Read-only: whether `document` currently has an active frame timing info.
pub fn hasActiveFrameTimingInfo(document: *Instance) bool {
    const state = runtime.BrowserScope.ofInstance(document).existing(State) orelse return false;
    return state.findActiveIndex(document) != null;
}

/// Read-only: the completed frames recorded on `document`'s BrowserScope.
pub fn completedFrames(document: *Instance) []const CompletedFrame {
    const state = runtime.BrowserScope.ofInstance(document).existing(State) orelse return &.{};
    return state.completed.items;
}

/// HTML 8.1.7.3 step 20: Long Animation Frames §3.2.1 "record rendering time"
/// given `document` and `frame.style_and_layout_start_ns` (step 15's
/// `unsafeStyleAndLayoutStartTime`).
/// Read-only when no frame timing info is active (0 allocations, 0 clock reads).
pub fn recordRenderingTime(document: *Instance, frame: update_the_rendering.Frame) void {
    const state = runtime.BrowserScope.ofInstance(document).existing(State) orelse return;
    if (state.active.items.len == 0) return;

    // 1. Let root be document's nearest same-origin root.
    const root = nearestSameOriginRoot(document);
    // 2-3. Let timingInfo be root's current frame timing info; if null, return.
    const idx = state.findActiveIndex(root) orelse return;
    const info = &state.active.items[idx].info;

    // 4. Assert: timingInfo's style and layout stack is empty (no style/layout
    //    or script is in progress at step 20).

    // 5-6. Compute frameDuration between relative high resolution time of
    //      timingInfo.start_time and current high resolution time.
    const now_ns: i64 = @intCast(platform.monotonicNow().ns);
    const start_ms = relativeMs(root.ctx, info.start_time_ns);
    const now_ms = relativeMs(root.ctx, now_ns);
    const frame_duration_ms = now_ms - start_ms;

    // 7. If frameDuration is less than 50 milliseconds, set root's current
    //    frame timing info to null and return.
    if (frame_duration_ms < long_frame_threshold_ms) {
        var removed = state.active.orderedRemove(idx);
        removed.info.deinit(state.allocator);
        return;
    }

    // 8. Set timingInfo's update the rendering start time to its current task start time.
    info.update_the_rendering_start_time_ns = info.current_task_start_time_ns;
    // 9. Set timingInfo's style and layout start time to unsafeStyleAndLayoutStart.
    info.style_and_layout_start_time_ns = frame.style_and_layout_start_ns;

    // 10. Coarsened styleAndLayoutStart (ms).
    const style_and_layout_start_ms = relativeMs(root.ctx, frame.style_and_layout_start_ns);

    // 11. Accumulate style and layout periods that started at or after
    //     styleAndLayoutStart into style_duration_ms / layout_duration_ms.
    for (info.periods.items) |period| {
        if (period.start_time_ms < style_and_layout_start_ms) continue;
        const duration = @max(0.0, period.end_time_ms - period.start_time_ms);
        switch (period.kind) {
            .style => info.style_duration_ms += duration,
            .layout => info.layout_duration_ms += duration,
        }
    }
    // 12. Empty timingInfo's style and layout periods.
    info.periods.clearRetainingCapacity();

    // 13. If root's browsing context is not paint-timing eligible:
    //     13.1 Set root's current frame timing info to null.
    //     13.2 Set timingInfo's end time to unsafe shared current time.
    //     13.3 Queue a long animation frame entry given root, timingInfo, and
    //          a new (zero) paint timing info.
    if (!isPaintTimingEligible(root)) {
        var removed = state.active.orderedRemove(idx);
        defer removed.info.deinit(state.allocator);
        removed.info.end_time_ns = now_ns;
        queueLongAnimationFrameEntry(state, root, &removed.info, .{});
    }
    // Otherwise root is paint-timing eligible: leave current frame timing info
    // on root so step 21 ("mark paint timing") completes and queues it with
    // paintTimingInfo.
}

/// HTML 8.1.7.3 step 21: Paint Timing §5.3.2 "mark paint timing" for `document`.
/// Read-only when no frame timing info is active (0 allocations, 0 clock reads).
pub fn markPaintTiming(document: *Instance, frame: update_the_rendering.Frame) void {
    _ = frame;
    // Step 1: If document's browsing context is not paint-timing eligible, return.
    if (!isPaintTimingEligible(document)) return;

    // Steps 3–6 and 10.1–10.4 (paintedImages, paintedTextNodes, first-paint,
    // first-contentful-paint, report largest contentful paint, report element
    // timing): needs-renderer. Crane paints no boxes/pixels and keeps "paint"
    // out of PerformanceObserver.supportedEntryTypes (integrator ruling
    // 2026-11-18, tools/wpt_gate_exemptions.txt).

    // Steps 8–9: Let frameTimingInfo be document's current frame timing info;
    // set document's current frame timing info to null.
    const state = runtime.BrowserScope.ofInstance(document).existing(State) orelse return;
    const idx = state.findActiveIndex(document) orelse return;
    var removed = state.active.orderedRemove(idx);
    defer removed.info.deinit(state.allocator);

    // Step 2: Let paintTimingInfo be a new paint timing info whose rendering
    // update end time is the current high resolution time given document's
    // relevant global object (and presentation_time = null).
    const now_ns: i64 = @intCast(platform.monotonicNow().ns);
    const paint_timing_info: PaintTimingInfo = .{
        .rendering_update_end_time = relativeMs(document.ctx, now_ns),
        .presentation_time = null,
    };

    // Step 11: Crane does not support implementation-defined presentation
    // times, so flushPaintTimings runs synchronously now.
    // Step 10.5: Since frameTimingInfo is not null, queue a long animation
    // frame entry given document, frameTimingInfo, and paintTimingInfo.
    queueLongAnimationFrameEntry(state, document, &removed.info, paint_timing_info);
}

/// Long Animation Frames §3.2.1 "queue a long animation frame entry".
/// TODO(loaf): create and queue a `PerformanceLongAnimationFrameTiming` entry
/// in `document`'s performance timeline once `PerformanceLongAnimationFrameTiming`
/// and `PerformanceScriptTiming` are enabled in V8 bindings and
/// `"long-animation-frame"` is added to `PerformanceObserver.supportedEntryTypes`.
fn queueLongAnimationFrameEntry(state: *State, document: *Instance, info: *const FrameTimingInfo, paint: PaintTimingInfo) void {
    state.pushCompleted(.{
        .document = same_object.Link.to(document),
        .start_time_ns = info.start_time_ns,
        .update_the_rendering_start_time_ns = info.update_the_rendering_start_time_ns,
        .style_and_layout_start_time_ns = info.style_and_layout_start_time_ns,
        .end_time_ns = info.end_time_ns,
        .style_duration_ms = info.style_duration_ms,
        .layout_duration_ms = info.layout_duration_ms,
        .paint = paint,
    });
}

fn isVisibleAndFullyActive(document: *Instance) bool {
    if (!document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return false;
    return (interfaces.Document.get_visibilityState(document) catch return false) != ._hidden_;
}

fn relativeMs(realm: runtime.Context, moment_ns: i64) f64 {
    const unsafe_ms = @as(f64, @floatFromInt(moment_ns)) / std.time.ns_per_ms;
    return performance_timeline.relativeCoarseTime(realm, unsafe_ms) orelse unsafe_ms;
}

test "PaintTimingInfo.defaultPaintTimestamp prefers presentationTime and falls back to paintTime" {
    const without_presentation: PaintTimingInfo = .{ .rendering_update_end_time = 123.4, .presentation_time = null };
    try std.testing.expectEqual(@as(f64, 123.4), without_presentation.defaultPaintTimestamp());
    const with_presentation: PaintTimingInfo = .{ .rendering_update_end_time = 123.4, .presentation_time = 130.0 };
    try std.testing.expectEqual(@as(f64, 130.0), with_presentation.defaultPaintTimestamp());
}
