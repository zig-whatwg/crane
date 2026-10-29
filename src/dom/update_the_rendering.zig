//! HTML 8.1.7.3 "update the rendering": its per-document steps, in the
//! spec's order, and the one way to ask for a rendering opportunity.
//!
//! A window event loop's rendering opportunity is the browser layer's
//! (src/browser/rendering.zig: the frame clock, the maps of animation frame
//! callbacks, the ordered list). The steps belong to the owners of the state
//! they read. An owner outside the impls (html.autofocus, html.focus,
//! dom.style) is called by the list directly; an owner that is an impl
//! installs its step here, once, at process start, so that the browser layer
//! never names the impl. A step nobody installed is skipped.
//!
//! Demand: Crane renders on demand, as every engine does (WebKit
//! `Page::scheduleRenderingUpdate`, Blink `ScheduleAnimation`, Gecko
//! `nsRefreshDriver::ScheduleRenderingPhase`): `requestFrame(document)` is how
//! any owner says that `document` has work for the next rendering
//! opportunity. A document with neither a request nor animation frame
//! callbacks gets no frame ("unnecessary rendering", step 4), and a loop no
//! document asks a frame of arms no timer.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering
//!
//! lint-impls: hook for Context, Document
const std = @import("std");
const process_start = @import("process_start.zig");
const refcount = @import("refcount.zig");
const runtime = @import("runtime");

/// The per-document steps of "update the rendering", numbered as the spec
/// numbers them. Steps 1-5 (collect the documents, order them, filter the
/// non-renderable and the unnecessary) and step 15 (the unsafe style and
/// layout start time) are the loop's own, not a document's.
pub const Step = enum(u5) {
    /// 6. Reveal: "has been revealed", the pagereveal event.
    reveal = 6,
    /// 7. Flush autofocus candidates (top-level traversables' documents).
    flush_autofocus_candidates = 7,
    /// 8. CSSOM View "run the resize steps".
    resize = 8,
    /// 9. CSSOM View "run the scroll steps".
    scroll = 9,
    /// 10. CSSOM View "evaluate media queries and report changes".
    media_queries = 10,
    /// 11. Web Animations "update animations and send events": the
    /// animations module's (dom.animations, an owner outside the impls),
    /// which the list calls directly.
    animations = 11,
    /// 12. Fullscreen "run the fullscreen steps".
    fullscreen = 12,
    /// 13. The canvas context lost steps.
    context_lost = 13,
    /// 14. Run the animation frame callbacks.
    animation_frame_callbacks = 14,
    /// 16. Style and layout, content-visibility proximity, ResizeObserver.
    style_and_layout = 16,
    /// 17. The focus fixup.
    focus_fixup = 17,
    /// 18. CSS View Transitions "perform pending transition operations".
    view_transitions = 18,
    /// 19. Intersection Observer "run the update intersection observations
    /// steps".
    intersection_observations = 19,
    /// 20. Long Animation Frames "record rendering time".
    rendering_time = 20,
    /// 21. Paint Timing "mark paint timing".
    paint_timing = 21,
    /// 22. Update the rendering or user interface (the host's: Crane draws
    /// nothing).
    update_ui = 22,
    /// 23. CSS Position "process top layer removals".
    top_layer_removals = 23,
};

/// What a step is given about the frame it runs in.
pub const Frame = struct {
    /// frameTimestamp: the event loop's "last render opportunity time", an
    /// unsafe monotonic moment in nanoseconds (the platform clock). A step
    /// that hands it to script converts it with the relative high
    /// resolution time of the document's relevant global.
    timestamp_ns: i64,
};

/// One owner's step for one document. `document` is fully active and
/// renderable when the step starts; the step may run script, after which
/// the loop checks every document again before the next one.
pub const DocumentStep = *const fn (document: *runtime.Instance, frame: Frame) void;

// ============================================================================
// The refresh grid
// ============================================================================
//
// A display refreshes at moments `origin + k * interval`. A window event
// loop's rendering opportunities (src/browser/rendering.zig) and a dedicated
// worker's animation frames (html/worker_host.zig) both land on such a grid,
// so consecutive frames are whole refresh intervals apart, as a vsync's are.

/// 60 Hz, in nanoseconds: the refresh interval of the display Crane
/// emulates for a host that names none. The spec leaves the rate to the user
/// agent ("if the browser is attempting to achieve a 60Hz refresh rate, then
/// rendering opportunities occur at a maximum of every 60th of a second").
pub const default_refresh_interval_ns: i64 = 16_666_667;

/// The first refresh moment at or after `at`, on the grid from `origin`
/// with `interval` (all ns; `interval` > 0).
pub fn nextRefreshAtOrAfter(origin: i64, interval: i64, at: i64) i64 {
    const since = at - origin;
    if (since <= 0) return origin;
    return origin + (std.math.divCeil(i64, since, interval) catch unreachable) * interval;
}

/// The latest refresh moment at or before `at`, on the grid from `origin`
/// with `interval` (all ns; `interval` > 0); `origin` before it.
pub fn latestRefreshAtOrBefore(origin: i64, interval: i64, at: i64) i64 {
    const since = at - origin;
    if (since <= 0) return origin;
    return origin + @divFloor(since, interval) * interval;
}

/// What the browser layer supplies: the event loop's half.
pub const Loop = struct {
    /// `document` has work for the next rendering opportunity of its
    /// event loop. Borrowed: the loop keeps its identity checked by slab
    /// generation, never a reference.
    request_frame: *const fn (document: *runtime.Instance) void,
    /// The animations of `realm`'s event loop (dom.animations: the global
    /// animation list, the documents' timelines and event queues), owned by
    /// that loop; null for a realm no Browser loop runs.
    animation_registry: ?*const fn (realm: runtime.Context) ?*animations.Registry = null,
    /// The latest refresh moment at or before now (monotonic ns) on the
    /// refresh grid of `realm`'s event loop: a document timeline's time
    /// before its document's first rendering opportunity.
    latest_refresh: ?*const fn (realm: runtime.Context) ?i64 = null,
};

const animations = @import("animations/registry.zig");

/// The animations of `realm`'s event loop (Loop.animation_registry).
pub fn animationRegistry(realm: runtime.Context) ?*animations.Registry {
    const impl = loop orelse return null;
    const get = impl.animation_registry orelse return null;
    return get(realm);
}

/// The latest refresh moment at or before now of `realm`'s event loop
/// (Loop.latest_refresh).
pub fn latestRefresh(realm: runtime.Context) ?i64 {
    const impl = loop orelse return null;
    const get = impl.latest_refresh orelse return null;
    return get(realm);
}

const step_count = @typeInfo(Step).@"enum".fields.len;

// process-wide: function pointers the browser layer installs once at process start (crane.Process), the same for every Browser and thread
var loop: ?Loop = null;
// process-wide: function pointers each step's owner installs once at process start (crane.Process); a frame's state is its event loop's and its documents', never this table's
var steps: [24]?DocumentStep = [_]?DocumentStep{null} ** 24;

/// Called by the browser layer, once, at process start (process_start.zig).
pub fn installLoop(impl: Loop) void {
    process_start.assertInstalling();
    loop = impl;
}

/// Called by `step`'s owner, once, at process start (process_start.zig).
pub fn installStep(step: Step, document_step: DocumentStep) void {
    process_start.assertInstalling();
    steps[@intFromEnum(step)] = document_step;
}

/// Ask `document`'s event loop for a rendering opportunity. Without an
/// installed loop - a document no Browser runs - nothing happens.
pub fn requestFrame(document: *runtime.Instance) void {
    const impl = loop orelse return;
    impl.request_frame(document);
}

// ============================================================================
// The focus fixup's demand
// ============================================================================
//
// HTML "update the rendering" step 17 designates the viewport when the
// focused area "is no longer a focusable area" - a `:focus { display: none }`
// rule, `disabled`, `hidden`, `inert`. Blink and WebKit find that in the style
// and layout update any style invalidation schedules (Blink's focused-element
// check in its lifecycle update, cleared by a posted task; WebKit
// Document::resolveStyle). Crane computes style lazily and has no such push,
// but every DOM mutation moves its document's tree version
// (refcount.bumpTreeVersion: inserts, removals, moves, attribute changes,
// data changes). So while an element is focused the document is WATCHED: its
// next tree-version move asks for a frame, once; the fixup step arms the
// watch again while an element is still focused. A CSSOM-only change
// (insertRule, a sheet's text) moves no tree version and is not seen.

/// `document`'s focused area is now `element` (null: its viewport)
/// (dom.focused_area.set). An element can stop being focusable in the very
/// change that focused it (`:focus { display: none }`), so designating one
/// asks for a frame and starts the watch.
pub fn focusedAreaChanged(document: *runtime.Instance, element: ?*runtime.Instance) void {
    if (element == null) {
        refcount.watchRendering(document, false);
        return;
    }
    refcount.watchRendering(document, true);
    requestFrame(document);
}

/// The focus fixup ran and an element is still focused: watch again.
pub fn watchFocusedArea(document: *runtime.Instance) void {
    refcount.watchRendering(document, true);
}

/// Run `step` for `document`, if its owner installed it. The loop's.
pub fn run(step: Step, document: *runtime.Instance, frame: Frame) void {
    const installed = steps[@intFromEnum(step)] orelse return;
    installed(document, frame);
}

/// Whether `step`'s owner installed it.
pub fn isInstalled(step: Step) bool {
    return steps[@intFromEnum(step)] != null;
}

test "the steps keep the spec's numbers and order" {
    comptime {
        std.debug.assert(step_count == 17);
        var previous: u5 = 0;
        for (@typeInfo(Step).@"enum".fields) |field| {
            std.debug.assert(field.value > previous);
            previous = field.value;
        }
    }
    try std.testing.expectEqual(@as(u5, 6), @intFromEnum(Step.reveal));
    try std.testing.expectEqual(@as(u5, 14), @intFromEnum(Step.animation_frame_callbacks));
    try std.testing.expectEqual(@as(u5, 17), @intFromEnum(Step.focus_fixup));
    try std.testing.expectEqual(@as(u5, 23), @intFromEnum(Step.top_layer_removals));
}

test "refresh moments are a grid from its origin" {
    try std.testing.expectEqual(@as(i64, 1_000), nextRefreshAtOrAfter(1_000, 100, 500));
    try std.testing.expectEqual(@as(i64, 1_000), nextRefreshAtOrAfter(1_000, 100, 1_000));
    try std.testing.expectEqual(@as(i64, 1_100), nextRefreshAtOrAfter(1_000, 100, 1_001));
    try std.testing.expectEqual(@as(i64, 1_300), nextRefreshAtOrAfter(1_000, 100, 1_250));
    try std.testing.expectEqual(@as(i64, 1_200), latestRefreshAtOrBefore(1_000, 100, 1_299));
    try std.testing.expectEqual(@as(i64, 1_300), latestRefreshAtOrBefore(1_000, 100, 1_300));
    try std.testing.expectEqual(@as(i64, 1_000), latestRefreshAtOrBefore(1_000, 100, 10));
}

test "without an installed loop a frame request does nothing, and an uninstalled step is skipped" {
    const saved_loop = loop;
    const saved_steps = steps;
    defer {
        loop = saved_loop;
        steps = saved_steps;
    }
    loop = null;
    steps = [_]?DocumentStep{null} ** 24;
    // Never dereferenced: with nothing installed nothing reads the document.
    var document: runtime.Instance = undefined;
    requestFrame(&document);
    run(.reveal, &document, .{ .timestamp_ns = 0 });
    try std.testing.expect(!isInstalled(.reveal));
}

test "an installed step runs for its document with the frame" {
    const saved_steps = steps;
    defer steps = saved_steps;
    const Probe = struct {
        var seen: ?*runtime.Instance = null;
        var timestamp: i64 = 0;
        fn step(document: *runtime.Instance, frame: Frame) void {
            seen = document;
            timestamp = frame.timestamp_ns;
        }
    };
    steps[@intFromEnum(Step.reveal)] = &Probe.step;
    var document: runtime.Instance = undefined;
    run(.reveal, &document, .{ .timestamp_ns = 42 });
    try std.testing.expect(Probe.seen == &document);
    try std.testing.expectEqual(@as(i64, 42), Probe.timestamp);
    run(.scroll, &document, .{ .timestamp_ns = 7 });
    try std.testing.expectEqual(@as(i64, 42), Probe.timestamp);
}
