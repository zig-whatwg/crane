//! A pointer that was over an element of a document whose realm the collector has since taken is over nothing:
//! moving it elsewhere reads nothing of that realm, fires nothing there and leaks nothing (lane tl1).
//!
//! Found twice on main, in html/browsers/browsing-the-web/navigating-across-documents/replace-before-load/
//! location-setter-user-click.html under load (the bug-finding runner, 24 processes at once): as 12 leaked
//! allocations at a runner child's exit (30 of 72 processes on main 929bcfca883, 13 of 24 on 9a0207b5b4),
//! and as a segmentation fault (3 of 96 on 929bcfca883). Each click of that file navigates the frame its
//! button is in, and the next click moves the runner's mouse off the previous button. Nothing of script
//! reaches the old document by then, so the collector takes its realm; the realm's end is a task it queues
//! (protocol_realms.realmCollected), and until that task has run the old Window and its tree are still
//! allocated, so the pointer's weak references (an address and a slab generation) still resolve the old
//! button. The boundary events - pointerout, three pointerleave, mouseout, three mouseleave - were made in
//! that realm:
//!
//! - the leak: an object made in a realm with no engine behind it is never wrapped and never freed
//!   (Instance.releaseIfUnwrapped leaves it), so each event's strings stayed - 12 allocations;
//! - the crash: the event's timestamp step read the old Window's Performance object, which the collector
//!   had freed with its wrapper when script of the frame had read `performance`:
//!
//!       Instance.stateAs  <-  Performance getInternal / nowOfRealm  <-  dom.performance_timeline.now
//!         <-  Event innerEventCreationSteps  <-  PointerEvent constructor
//!         <-  html.user_input.firePointerEvent  <-  pointerMove
//!
//! tests/html/tl1_pointer_leaves_dead_document_test.zig is the same road with the old realm kept alive by
//! script.
//!
//! Here script keeps nothing of the frame's document, the frame navigates, and a collection is asked for
//! (TestUtils.gc()'s operation) before the pointer moves - with the event loop not turned (the realm's end
//! still queued) and with it turned (the realm ended, its tree freed: this one passed before the fix too).
//!
//! The Browser is made with std.testing.allocator, so an event nobody freed fails the test as a leak.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const input = @import("html").user_input;
const h = @import("tl1_pending_timer_helpers.zig");

/// What the event loop does between the collection and the pointer's move.
const After = enum {
    /// Nothing: the collected realm's end is still a queued task.
    loop_not_turned,
    /// It turns: the collected realm has ended.
    loop_turned,
};

/// What the test does with the pointer after that.
const Probe = enum { current_target, move_away };

/// What the frame's script did before the frame navigated.
const Frame = enum {
    /// It read `performance`, as a page's script does: the Window's Performance object has a wrapper, so it
    /// is the collector that frees it (the crash).
    reads_performance,
    /// It read nothing of its window (the leak).
    reads_nothing,

    fn html(comptime self: Frame) []const u8 {
        return "<!doctype html><body><button id=outside>outside</button>" ++
            "<iframe id=frame srcdoc=\"<!doctype html><body><button id=inside>inside</button>" ++
            (if (self == .reads_performance) "<script>performance.now();</script>" else "") ++
            "</body>\"></iframe></body>";
    }
};

fn element(document: *runtime.Instance, comptime id: []const u8) !*runtime.Instance {
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoSuchElement;
}

fn collect(page: h.Page) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    const agent = page.browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

fn exercise(comptime frame_script: Frame, comptime after: After, comptime probe: Probe) !void {
    const page = try h.Page.open(comptime frame_script.html(), "http://127.0.0.1:65533/start");
    defer page.close();
    // The frame's srcdoc document loads. The poll keeps nothing of it.
    try page.run(
        \\globalThis.state = 'pending';
        \\globalThis.poll = setInterval(() => {
        \\  const inner = document.getElementById('frame').contentDocument;
        \\  if (inner && inner.getElementById('inside')) { state = 'loaded'; clearInterval(poll); }
        \\}, 5);
    );
    try page.waitForState("loaded");
    const context = page.browser.current_context orelse return error.NoPage;
    const document = context.document_instance orelse return error.NoDocument;
    const outside = try element(document, "outside");

    var pointer: input.Pointer = .{};
    {
        const frame = try element(document, "frame");
        const frame_document = (try interfaces.HTMLIFrameElement.get_contentDocument(frame)) orelse return error.NoFrameDocument;
        const inside = try element(frame_document, "inside");
        input.pointerMove(&pointer, inside, .{});
        try testing.expect(pointer.currentTarget() == inside);
    }

    // The frame navigates: its old document's realm is detached, and nothing of script reaches it.
    try page.run(
        \\state = 'pending';
        \\{
        \\  const frame = document.getElementById('frame');
        \\  frame.onload = () => { state = 'navigated'; };
        \\  frame.removeAttribute('srcdoc');
        \\  frame.src = 'about:blank';
        \\}
    );
    try page.waitForState("navigated");

    // The collector takes the old realm.
    try collect(page);
    switch (after) {
        .loop_not_turned => {},
        .loop_turned => try page.turn(20),
    }

    switch (probe) {
        // The pointer is over nothing: the document it was over has gone.
        .current_target => try testing.expect(pointer.currentTarget() == null),
        // It moves onto the page's button, entering it from nowhere: no boundary event is made for the
        // old document (on main's code the first one read the freed Performance object, or was leaked).
        .move_away => {
            input.pointerMove(&pointer, outside, .{});
            try testing.expect(pointer.currentTarget() == outside);
        },
    }
}

fn check(comptime frame_script: Frame, comptime after: After, comptime probe: Probe) !void {
    try h.onFreshThread(struct {
        fn body() !void {
            try exercise(frame_script, after, probe);
        }
    }.body);
}

test "a pointer over an element of a collected realm, its end still queued, is over nothing" {
    try check(.reads_nothing, .loop_not_turned, .current_target);
}

test "a pointer moved off an element of a collected realm, its end still queued, leaks no event" {
    try check(.reads_nothing, .loop_not_turned, .move_away);
}

test "a pointer moved off an element of a collected realm, its end still queued, does not read the Performance object the collector freed" {
    try check(.reads_performance, .loop_not_turned, .move_away);
}

test "a pointer moved off an element of a collected realm that has ended reads nothing of that realm" {
    try check(.reads_performance, .loop_turned, .move_away);
}
