//! A key named for a document that is no longer fully active is routed nowhere (lane tl1).
//!
//! html.user_input.keyDown / keyUp take the document whose top-level traversable the key is routed in. An
//! embedder can still hold a document its frame has navigated away from - the WPT runner holds its key
//! document weakly (an address and a slab generation), as it held its pointer's target. Such a document
//! is in no navigable (HTML 7.3.1: a document's node navigable is the navigable whose active document it
//! is, or null), so there is no top-level traversable to route the key in: nothing happens, in that
//! document or in the page. tests/html/tl1_pointer_leaves_dead_document_test.zig is the pointer's half.
//!
//! Here script keeps the frame's old document (its realm stays detached and alive), and the page and the
//! old document both listen.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const input = @import("html").user_input;
const h = @import("tl1_pending_timer_helpers.zig");

const page_html =
    "<!doctype html><body>" ++
    "<iframe id=frame srcdoc=\"<!doctype html><body><button id=inside>inside</button></body>\"></iframe></body>";

fn exercise() !void {
    const page = try h.Page.open(page_html, "http://127.0.0.1:65533/start");
    defer page.close();
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
    const frame = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("frame"))) orelse return error.NoFrame;
    const frame_document = (try interfaces.HTMLIFrameElement.get_contentDocument(frame)) orelse return error.NoFrameDocument;

    // The frame's button has focus; script keeps the frame's document, and hears every key event that
    // reaches it or the page.
    try page.run(
        \\globalThis.kept = document.getElementById('frame').contentDocument;
        \\kept.getElementById('inside').focus();
        \\globalThis.heard = [];
        \\for (const type of ['keydown', 'keypress', 'keyup', 'click']) {
        \\  kept.addEventListener(type, () => heard.push('old document ' + type), true);
        \\  document.addEventListener(type, () => heard.push('page ' + type), true);
        \\}
    );

    // While the document is active a key reaches it (the control: the listeners hear).
    var keyboard: input.Keyboard = .{};
    const key: input.Key = .{ .key = "a", .code = "KeyA", .key_code = 65, .text = "a" };
    input.keyDown(&keyboard, frame_document, key, .{});
    input.keyUp(&keyboard, frame_document, key, .{});
    try page.run(
        \\if (!heard.includes('old document keydown')) throw new Error('the control key was not heard: ' + heard.join());
        \\heard.length = 0;
    );

    // The frame navigates: its old document is no longer the active document of any navigable.
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

    // Space, which arms a focused button for keyboard activation when it is routed.
    const space: input.Key = .{ .key = " ", .code = "Space", .key_code = 32, .text = " " };
    input.keyDown(&keyboard, frame_document, space, .{});
    try testing.expect(keyboard.space_armed == null);
    input.keyUp(&keyboard, frame_document, space, .{});
    try page.run(
        \\if (heard.length !== 0) throw new Error('a key for a document that is not fully active was routed: ' + heard.join());
    );
}

test "a key named for a navigated frame's old document is routed nowhere" {
    try h.onFreshThread(exercise);
}
