//! Lane quick2, on top of lane tl1's rule (src/html/user_input.zig Pointer.currentTarget): a pointer is over
//! nothing of a document that is no longer fully active, and no event is made there. The pointer state lane
//! quick2 added follows the same rule:
//!
//! - a touch contact whose document has gone is forgotten without events - no pointerup, no touchend, no tap -
//!   and it is no active pointer of its tab any more, so the next touch is the primary one;
//! - a pointer capture target (pending or set) of a document that has gone is no target: no gotpointercapture
//!   or lostpointercapture is fired at it, and the pointer's events go to the element under it;
//! - the element a touch's last tap left the legacy mouse on is forgotten with its document: the next tap
//!   fires no mouseout or mouseleave there.
//!
//! In the first three tests script keeps the old button, so the old document's realm is detached and alive and
//! a listener would hear an event. In the last one nothing is kept: the collector takes the realm, and an event
//! made in it is never freed (tests/html/tl1_pointer_after_realm_collected_test.zig says why) - the Browser is
//! made with std.testing.allocator, so that event fails the test as a leak.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const input = @import("html").user_input;
const h = @import("tl1_pending_timer_helpers.zig");

const page_html =
    "<!doctype html><body><button id=outside>outside</button>" ++
    "<iframe id=frame srcdoc=\"<!doctype html><body><button id=inside>inside</button></body>\"></iframe></body>";

const Ending = enum { frame_removed, frame_navigated };

fn element(document: *runtime.Instance, comptime id: []const u8) !*runtime.Instance {
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoSuchElement;
}

const Buttons = struct { inside: *runtime.Instance, outside: *runtime.Instance };

/// The page with its frame loaded. With `keeps`, script keeps the frame's button (`kept`) and `heard` records
/// "<inside|outside> <type>" for every event of `types` at either button.
fn open(comptime keeps: bool, comptime types: []const u8) !struct { page: h.Page, buttons: Buttons } {
    const page = try h.Page.open(page_html, "http://127.0.0.1:65533/start");
    errdefer page.close();
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
    const frame = try element(document, "frame");
    const frame_document = (try interfaces.HTMLIFrameElement.get_contentDocument(frame)) orelse return error.NoFrameDocument;
    const buttons: Buttons = .{ .inside = try element(frame_document, "inside"), .outside = try element(document, "outside") };
    if (keeps) try page.run("globalThis.kept = document.getElementById('frame').contentDocument.getElementById('inside');\n" ++
        "globalThis.heard = [];\n" ++
        "for (const type of [" ++ types ++ "]) {\n" ++
        "  kept.addEventListener(type, () => heard.push('inside ' + type));\n" ++
        "  document.getElementById('outside').addEventListener(type, () => heard.push('outside ' + type));\n" ++
        "}\n");
    return .{ .page = page, .buttons = buttons };
}

/// The frame's document ends.
fn end(page: h.Page, comptime ending: Ending) !void {
    switch (ending) {
        .frame_removed => try page.run("document.getElementById('frame').remove();"),
        .frame_navigated => {
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
        },
    }
}

fn touchPoint(id: i32) input.Pointer {
    return .{ .pointer_id = id, .pointer_type = .touch };
}

fn press(point: *input.Pointer, target: *runtime.Instance) void {
    point.touch_hit = input.Weak.of(target);
    point.touch_change = .pressed;
    input.touchFrame(&.{point}, .{});
}

fn lift(point: *input.Pointer) void {
    point.touch_change = .released;
    input.touchFrame(&.{point}, .{});
}

fn touchContactOfAGoneDocument() !void {
    const opened = try open(true, "'pointerup', 'pointercancel', 'pointerout', 'pointerleave', 'lostpointercapture', 'touchend', 'touchcancel', " ++
        "'mousemove', 'mousedown', 'mouseup', 'click'");
    const page = opened.page;
    defer page.close();

    var first = touchPoint(2);
    press(&first, opened.buttons.inside);
    try testing.expect(first.in_contact);
    try end(page, .frame_removed);

    // The contact lifts: its document has gone, so it is forgotten without events.
    lift(&first);
    try testing.expect(!first.in_contact);
    try page.run("if (heard.length) throw new Error('events at a gone document: ' + heard.join());");

    // Another finger touches the page: no other touch is in contact, so it is the primary one.
    try page.run("document.getElementById('outside').addEventListener('pointerdown', (e) => { globalThis.primary = e.isPrimary; });");
    var second = touchPoint(3);
    press(&second, opened.buttons.outside);
    lift(&second);
    try page.run(
        \\if (primary !== true) throw new Error('the next touch is not primary: ' + primary);
        \\if (heard.join() !== 'outside pointerup,outside lostpointercapture,outside pointerout,outside pointerleave,outside touchend,outside mousemove,outside mousedown,outside mouseup,outside click') throw new Error('heard: ' + heard.join());
    );
}

test "a touch contact whose document has gone lifts without events and is no active pointer" {
    try h.onFreshThread(touchContactOfAGoneDocument);
}

fn captureTargetOfAGoneDocument() !void {
    const opened = try open(true, "'gotpointercapture', 'lostpointercapture', 'pointerover', 'pointerout', 'pointerleave', 'mouseout', 'mouseleave', 'pointermove', 'pointerup'");
    const page = opened.page;
    defer page.close();

    // The mouse goes down on the frame's button, whose pointerdown listener captures it.
    try page.run("kept.addEventListener('pointerdown', (e) => { kept.setPointerCapture(e.pointerId); globalThis.had = kept.hasPointerCapture(e.pointerId); });");
    var pointer: input.Pointer = .{};
    input.pointerMove(&pointer, opened.buttons.inside, .{});
    input.pointerDown(&pointer, 0, .{});
    try page.run(
        \\if (had !== true) throw new Error('the frame button did not capture the mouse: ' + had);
        \\heard.length = 0;
    );
    try end(page, .frame_navigated);

    // The mouse moves onto the page's button: the capture went with its document, with no event there.
    input.pointerMove(&pointer, opened.buttons.outside, .{});
    try testing.expect(pointer.currentTarget() == opened.buttons.outside);
    input.pointerUp(&pointer, 0, .{});
    try page.run(
        \\if (heard.join() !== 'outside pointerover,outside pointermove,outside pointerup') throw new Error('heard: ' + heard.join());
        \\if (kept.hasPointerCapture(1)) throw new Error('an element of a gone document has the capture');
    );
}

test "a pointer capture target of a document that has gone gets no capture event and no pointer event" {
    try h.onFreshThread(captureTargetOfAGoneDocument);
}

fn legacyMouseOfAGoneDocument() !void {
    const opened = try open(true, "'mouseout', 'mouseleave', 'mouseover'");
    const page = opened.page;
    defer page.close();

    var point = touchPoint(2);
    press(&point, opened.buttons.inside);
    lift(&point);
    try page.run(
        \\if (heard.join() !== 'inside mouseover') throw new Error('the tap moved no mouse onto the frame button: ' + heard.join());
        \\heard.length = 0;
    );
    try end(page, .frame_removed);

    // The next tap's mouse enters the page's button from nowhere.
    press(&point, opened.buttons.outside);
    lift(&point);
    try page.run("if (heard.join() !== 'outside mouseover') throw new Error('heard: ' + heard.join());");
}

test "a tap after the last tapped element's document has gone fires no mouse boundary event there" {
    try h.onFreshThread(legacyMouseOfAGoneDocument);
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

fn touchContactOfACollectedRealm() !void {
    const opened = try open(false, "");
    const page = opened.page;
    defer page.close();

    var point = touchPoint(2);
    press(&point, opened.buttons.inside);
    // The frame navigates with the finger down; nothing of script reaches the old document, and the collector
    // takes its realm. The realm's end is still a queued task: the old tree is allocated.
    try end(page, .frame_navigated);
    try collect(page);

    // The finger lifts: nothing is made in the collected realm (an event made there is never freed).
    lift(&point);
    try testing.expect(!point.in_contact);
    // The finger taps the page's button.
    press(&point, opened.buttons.outside);
    try testing.expect(point.in_contact and point.is_primary);
    lift(&point);
}

test "a touch lifted after its document's realm was collected makes no event there" {
    try h.onFreshThread(touchContactOfACollectedRealm);
}
