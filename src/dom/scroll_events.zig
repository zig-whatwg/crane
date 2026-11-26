//! CSSOM View §13.2 "Scrolling": each Document's list of pending scroll
//! events and HTML "update the rendering" step 9 ("run the scroll steps").
//!
//! Spec: https://drafts.csswg.org/cssom-view/#scrolling-events
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering
//!
//! Storage lives in a per-Browser `BrowserScope` supplement (`Pending`), made
//! only when a viewport or element actually scrolls. On every idle rendering
//! opportunity `runScrollSteps` is a read-only check that allocates nothing.
//!
//! Sub-steps that require a renderer / layout geometry (`needs-renderer`):
//! - CSSOM View §13.2 step 1.2 & steps 2.2–2.3: `scrollsnapchange` and
//!   `scrollsnapchanging` (`SnapEvent`) depend on scroll-snap container box
//!   geometry and eventual snap targets (CSS Scroll Snap 2).
//! - Element scrollable overflow boxes (`Element.scrollTop` / `scrollLeft` /
//!   `scrollBy`): without a layout engine elements have no scrollable overflow
//!   area, so only viewport scrolling (`Window.scroll` / `scrollTo` /
//!   `scrollBy` and `fragment_scroll.scrollToTheBeginningOfTheDocument`)
//!   changes a scroll offset today. `queueElementScroll` is provided for a
//!   renderer host to feed element and VisualViewport scroll events into the
//!   same step-9 queue.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const same_object = @import("same_object.zig");
const fire_event = @import("fire_event.zig");
const node_holds = @import("node_holds.zig");
const update_the_rendering = @import("update_the_rendering.zig");

const Instance = runtime.Instance;

pub const EventType = enum {
    scroll,
    scrollend,
};

pub const Target = union(enum) {
    /// The Document itself (viewport scroll): fires a bubbling event at
    /// `document`, which bubbles up to its Window (CSSOM View §13.2 step 2.1).
    document,
    /// An Element or VisualViewport: fires a non-bubbling event at the target
    /// (CSSOM View §13.2 step 2.4).
    other: same_object.Link,

    fn eql(a: Target, b: Target) bool {
        return switch (a) {
            .document => b == .document,
            .other => |al| switch (b) {
                .document => false,
                .other => |bl| al.instance == bl.instance and al.generation == bl.generation,
            },
        };
    }
};

const PendingEvent = struct {
    document: same_object.Link,
    target: Target,
    event_type: EventType,
};

const CompletedBox = struct {
    document: same_object.Link,
    target: Target,
};

/// Per-Browser supplement holding pending scroll events across its documents.
/// Created lazily on the first scroll; never created by `runScrollSteps` or
/// `hasPending`.
pub const Pending = struct {
    allocator: Allocator,
    /// CSSOM View §13.2: pending scroll events, in insertion order.
    events: std.ArrayListUnmanaged(PendingEvent) = .empty,
    /// CSSOM View §13.2 step 1: scrolling boxes whose scroll completed since
    /// the last scroll steps ran (emit `scrollend` at step 1).
    completed: std.ArrayListUnmanaged(CompletedBox) = .empty,

    pub fn init(allocator: Allocator) Pending {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Pending) void {
        self.events.deinit(self.allocator);
        self.completed.deinit(self.allocator);
    }

    fn hasEvent(self: *const Pending, doc: same_object.Link, target: Target, event_type: EventType) bool {
        for (self.events.items) |item| {
            if (item.document.instance == doc.instance and
                item.document.generation == doc.generation and
                item.event_type == event_type and
                item.target.eql(target)) return true;
        }
        return false;
    }

    fn appendEventUnique(self: *Pending, doc: same_object.Link, target: Target, event_type: EventType) void {
        if (self.hasEvent(doc, target, event_type)) return;
        self.events.append(self.allocator, .{
            .document = doc,
            .target = target,
            .event_type = event_type,
        }) catch {};
    }

    fn appendCompletedUnique(self: *Pending, doc: same_object.Link, target: Target) void {
        for (self.completed.items) |item| {
            if (item.document.instance == doc.instance and
                item.document.generation == doc.generation and
                item.target.eql(target)) return;
        }
        self.completed.append(self.allocator, .{ .document = doc, .target = target }) catch {};
    }
};

/// CSSOM View §13.2: "Whenever a viewport gets scrolled" (steps 1–4) plus
/// instant-scroll completion (`scrollend` per "perform a scroll" step 7.1).
/// Called only when the viewport's scroll position actually changed.
pub fn queueViewportScroll(document: *Instance) void {
    const scope = runtime.BrowserScope.ofInstance(document);
    const state = scope.of(Pending) catch return;
    const doc_link = same_object.Link.to(document);
    // Steps 3–4: deduplicated append of (doc, "scroll").
    state.appendEventUnique(doc_link, .document, .scroll);
    // Instant viewport scroll completes immediately: record for step 1's
    // scrollend append.
    state.appendCompletedUnique(doc_link, .document);
    update_the_rendering.requestFrame(document);
}

/// CSSOM View §13.2: "Whenever an element gets scrolled" / "Whenever a visual
/// viewport gets scrolled" (steps 1–4). `completed` records whether the scroll
/// also finished so step 1 queues `scrollend`.
pub fn queueTargetScroll(document: *Instance, target: *Instance, completed: bool) void {
    const scope = runtime.BrowserScope.ofInstance(document);
    const state = scope.of(Pending) catch return;
    const doc_link = same_object.Link.to(document);
    const target_ref: Target = if (target == document) .document else .{ .other = same_object.Link.to(target) };
    state.appendEventUnique(doc_link, target_ref, .scroll);
    if (completed) state.appendCompletedUnique(doc_link, target_ref);
    update_the_rendering.requestFrame(document);
}

/// Read-only: whether `document` has any pending scroll or scrollend events.
pub fn hasPending(document: *Instance) bool {
    const state = runtime.BrowserScope.ofInstance(document).existing(Pending) orelse return false;
    const gen = runtime.SlabAllocator.generationOf(document);
    for (state.events.items) |item| {
        if (item.document.instance == document and item.document.generation == gen) return true;
    }
    for (state.completed.items) |item| {
        if (item.document.instance == document and item.document.generation == gen) return true;
    }
    return false;
}

/// HTML 8.1.7.3 step 9: CSSOM View §13.2 "run the scroll steps" for `document`.
/// Read-only when `document` has no pending scroll events (0 allocations).
pub fn runScrollSteps(document: *Instance, frame: update_the_rendering.Frame) void {
    _ = frame;
    const state = runtime.BrowserScope.ofInstance(document).existing(Pending) orelse return;
    if (state.events.items.len == 0 and state.completed.items.len == 0) return;

    const doc_link = same_object.Link.to(document);

    // Step 1: For each scrolling box that was scrolled (and completed) in this
    // document:
    //   1.1 Resolve doc and target.
    //   1.2 needs-renderer: update scrollsnapchange targets (CSS Scroll Snap 2).
    //   1.3-1.4 If (target, "scrollend") is not already in doc's pending
    //           scroll events, append it.
    var ci: usize = 0;
    while (ci < state.completed.items.len) {
        const box = state.completed.items[ci];
        if (!box.document.isLive()) {
            _ = state.completed.orderedRemove(ci);
            continue;
        }
        if (box.document.instance == doc_link.instance and box.document.generation == doc_link.generation) {
            _ = state.completed.orderedRemove(ci);
            state.appendEventUnique(doc_link, box.target, .scrollend);
            continue;
        }
        ci += 1;
    }

    // Collect and remove this document's pending events before firing script,
    // so a listener that scrolls again queues for the next rendering update
    // rather than being lost by step 3's clear (matches Blink's
    // ScriptedAnimationController::DispatchEvents).
    var batch: std.ArrayListUnmanaged(PendingEvent) = .empty;
    defer batch.deinit(state.allocator);

    var ei: usize = 0;
    while (ei < state.events.items.len) {
        const item = state.events.items[ei];
        if (!item.document.isLive()) {
            _ = state.events.orderedRemove(ei);
            continue;
        }
        if (item.document.instance == doc_link.instance and item.document.generation == doc_link.generation) {
            _ = state.events.orderedRemove(ei);
            batch.append(state.allocator, item) catch continue;
            continue;
        }
        ei += 1;
    }

    if (batch.items.len == 0) return;

    // Keep the document live across listener invocations.
    var doc_hold: node_holds.TaskHold = .{};
    doc_hold.take(document);
    defer doc_hold.release();

    // Step 2: For each (target, type) in order:
    for (batch.items) |item| {
        if (doc_hold.get() == null) break;
        switch (item.target) {
            // Step 2.1: target is Document and type is "scroll" or "scrollend":
            // fire an event named type that bubbles at target.
            .document => dispatchScrollEvent(document, item.event_type, true),
            // Steps 2.2-2.3 (scrollsnapchange / scrollsnapchanging): needs-renderer.
            // Step 2.4: Otherwise, fire an event named type (not bubbling) at target.
            .other => |link| {
                if (!link.isLive()) continue;
                dispatchScrollEvent(link.instance, item.event_type, false);
            },
        }
    }
    // Step 3: doc's pending scroll events were emptied before dispatch above.
}

fn dispatchScrollEvent(target: *Instance, event_type: EventType, bubbles: bool) void {
    if (!target.ctx.hasEngine()) return;
    const event = interfaces.Event.call_constructor(
        target.ctx,
        runtime.DOMString.initInterned(@tagName(event_type)),
        webidl.Opt(dictionaries.EventInit).passed(.{ .bubbles = bubbles, .cancelable = false }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = fire_event.dispatchTrusted(target, event) catch {};
}

test "Pending deduplicates scroll and scrollend per (document, target)" {
    var pending = Pending.init(std.testing.allocator);
    defer pending.deinit();
    var fake_doc: Instance = undefined;
    const doc_link: same_object.Link = .{ .instance = &fake_doc, .generation = 1 };

    pending.appendEventUnique(doc_link, .document, .scroll);
    pending.appendEventUnique(doc_link, .document, .scroll);
    pending.appendCompletedUnique(doc_link, .document);
    pending.appendCompletedUnique(doc_link, .document);

    try std.testing.expectEqual(@as(usize, 1), pending.events.items.len);
    try std.testing.expectEqual(@as(usize, 1), pending.completed.items.len);

    pending.appendEventUnique(doc_link, .document, .scrollend);
    pending.appendEventUnique(doc_link, .document, .scrollend);
    try std.testing.expectEqual(@as(usize, 2), pending.events.items.len);
    try std.testing.expectEqual(EventType.scroll, pending.events.items[0].event_type);
    try std.testing.expectEqual(EventType.scrollend, pending.events.items[1].event_type);
}
