//! The input device's click count and wheel (lane cdpt2; CDP part 1 gap 3,
//! tmp/plans/lane-cdpt-handoff.md): Pointer Events 4 11.1's current click
//! count - the device reports it with each press (`Pointer.click_count`,
//! CDP's clickCount) - is the detail of mousedown, mouseup, click and
//! auxclick; a primary click of count 2 is followed by dblclick (11.4.4;
//! Blink's MouseEvent::DispatchEvent); a press of count 0 makes no click
//! (Blink's DispatchMouseClickIfNeeded); a wheel turn is one trusted
//! WheelEvent at the hit, which pointer capture does not move (12.3).
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).
const std = @import("std");
const html = @import("html");
const dom = @import("dom");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const user_input = html.user_input;

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn element(document: *runtime.Instance, selector: []const u8) !*runtime.Instance {
    return (try dom.selector_matching.querySelector(document, selector)) orelse error.NoElement;
}

/// Every mouse event at #t, as "type:detail:trusted:interface".
const log_events =
    \\document.body.innerHTML = '<div id=t>t</div>';
    \\window.seen = [];
    \\for (const type of ['mousedown', 'mouseup', 'click', 'auxclick', 'dblclick'])
    \\  t.addEventListener(type, e => seen.push(type + ':' + e.detail + ':' + e.isTrusted + ':' + e.constructor.name));
;

fn doubleClick() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(log_events);
    const document = try documentOf(page);
    const target = try element(document, "#t");

    var pointer = user_input.Pointer{};
    user_input.pointerMove(&pointer, target, .{});
    pointer.click_count = 1;
    user_input.pointerDown(&pointer, 0, .{});
    user_input.pointerUp(&pointer, 0, .{});
    pointer.click_count = 2;
    user_input.pointerDown(&pointer, 0, .{});
    user_input.pointerUp(&pointer, 0, .{});

    const seen = try page.evaluate("seen.join(',')");
    defer std.testing.allocator.free(seen);
    try std.testing.expectEqualStrings(
        "mousedown:1:true:MouseEvent,mouseup:1:true:MouseEvent,click:1:true:PointerEvent," ++
            "mousedown:2:true:MouseEvent,mouseup:2:true:MouseEvent,click:2:true:PointerEvent,dblclick:2:true:MouseEvent",
        seen,
    );
}

test "a primary click of count 2 carries detail 2 and is followed by a trusted dblclick MouseEvent at its target" {
    try helpers.onFreshThread(doubleClick);
}

fn canceledClickStillDoubleClicks() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(log_events);
    try page.run("t.addEventListener('click', e => e.preventDefault());");
    const document = try documentOf(page);
    const target = try element(document, "#t");
    var pointer = user_input.Pointer{};
    user_input.pointerMove(&pointer, target, .{});
    pointer.click_count = 2;
    user_input.pointerDown(&pointer, 0, .{});
    user_input.pointerUp(&pointer, 0, .{});
    const seen = try page.evaluate("seen.filter(s => s.startsWith('dblclick')).length");
    defer std.testing.allocator.free(seen);
    // 11.4.4: "Canceling the click event does not affect the firing of a
    // dblclick event."
    try std.testing.expectEqualStrings("1", seen);
}

test "canceling the click does not stop its dblclick" {
    try helpers.onFreshThread(canceledClickStillDoubleClicks);
}

fn secondaryButton() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(log_events);
    const document = try documentOf(page);
    const target = try element(document, "#t");
    var pointer = user_input.Pointer{};
    user_input.pointerMove(&pointer, target, .{});
    pointer.click_count = 2;
    user_input.pointerDown(&pointer, 1, .{});
    user_input.pointerUp(&pointer, 1, .{});
    const seen = try page.evaluate("seen.join(',')");
    defer std.testing.allocator.free(seen);
    // "Secondary buttons MUST NOT fire dblclick events."
    try std.testing.expectEqualStrings("mousedown:2:true:MouseEvent,mouseup:2:true:MouseEvent,auxclick:2:true:PointerEvent", seen);
}

test "a middle-button press of count 2 makes auxclick detail 2 and no dblclick" {
    try helpers.onFreshThread(secondaryButton);
}

fn countZero() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(log_events);
    const document = try documentOf(page);
    const target = try element(document, "#t");
    var pointer = user_input.Pointer{};
    user_input.pointerMove(&pointer, target, .{});
    pointer.click_count = 0;
    user_input.pointerDown(&pointer, 0, .{});
    user_input.pointerUp(&pointer, 0, .{});
    const seen = try page.evaluate("seen.join(',')");
    defer std.testing.allocator.free(seen);
    try std.testing.expectEqualStrings("mousedown:0:true:MouseEvent,mouseup:0:true:MouseEvent", seen);
}

test "a press of click count 0 has detail 0 and makes no click (CDP's default clickCount)" {
    try helpers.onFreshThread(countZero);
}

fn defaultCountIsOne() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(log_events);
    const document = try documentOf(page);
    const target = try element(document, "#t");
    var pointer = user_input.Pointer{};
    user_input.pointerMove(&pointer, target, .{});
    // A host that keeps no count (WebDriver's actions here).
    user_input.pointerDown(&pointer, 0, .{});
    user_input.pointerUp(&pointer, 0, .{});
    user_input.pointerDown(&pointer, 0, .{});
    user_input.pointerUp(&pointer, 0, .{});
    const seen = try page.evaluate("seen.join(',')");
    defer std.testing.allocator.free(seen);
    try std.testing.expectEqualStrings(
        "mousedown:1:true:MouseEvent,mouseup:1:true:MouseEvent,click:1:true:PointerEvent," ++
            "mousedown:1:true:MouseEvent,mouseup:1:true:MouseEvent,click:1:true:PointerEvent",
        seen,
    );
}

test "a host that sets no click count gets detail 1 for every click, and no dblclick" {
    try helpers.onFreshThread(defaultCountIsOne);
}

fn wheelTurn() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id=c>c</div><div id=t>t</div>';
        \\window.seen = [];
        \\document.addEventListener('wheel', e => seen.push([e.target.id, e.isTrusted, e.constructor.name, e.deltaX, e.deltaY, e.deltaZ, e.deltaMode, e.bubbles, e.cancelable, e.composed, e.ctrlKey].join(':')));
        \\window.canceled = [];
        \\t.addEventListener('wheel', e => { e.preventDefault(); canceled.push(e.defaultPrevented); });
    );
    const document = try documentOf(page);
    const target = try element(document, "#t");
    const capturer = try element(document, "#c");
    var pointer = user_input.Pointer{};
    user_input.pointerMove(&pointer, capturer, .{});
    // Captured to #c: a wheel over #t still goes to #t (capture moves
    // pointer events and their mouse events, never a wheel).
    user_input.pointerDown(&pointer, 0, .{});
    try page.run("c.setPointerCapture(1)");
    const not_canceled = user_input.wheel(&pointer, target, .{ .x = 3, .y = -120.5 }, .{ .ctrl = true });
    try std.testing.expect(!not_canceled);
    user_input.pointerUp(&pointer, 0, .{});
    const seen = try page.evaluate("seen.join(',') + '|' + canceled.join(',')");
    defer std.testing.allocator.free(seen);
    try std.testing.expectEqualStrings("t:true:WheelEvent:3:-120.5:0:0:true:true:true:true|true", seen);
}

test "a wheel turn is one trusted, cancelable, bubbling WheelEvent at the hit, whatever captures the pointer" {
    try helpers.onFreshThread(wheelTurn);
}
