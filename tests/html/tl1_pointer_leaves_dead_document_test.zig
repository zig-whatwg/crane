//! A pointer that was over an element of a document that is no longer fully active - its frame was removed
//! or navigated away - is over nothing of it: it names no element there, and no boundary event fires at
//! that document's elements when it moves on (lane tl1).
//!
//! Here script keeps the old button, so the old document's realm is detached and alive (the collector
//! cannot take it). tests/html/tl1_pointer_after_realm_collected_test.zig is the same road with nothing
//! kept: there the collector takes the realm, and main's code leaked the boundary events or read a freed
//! object (html/browsers/browsing-the-web/navigating-across-documents/replace-before-load/
//! location-setter-user-click.html, whose every click navigates the frame its button is in).
//!
//! What browsers do: the element under the mouse is a frame's own state, and it is dropped without events
//! when the frame's document goes - Blink EventHandler::Clear (from LocalFrame::DidAttachDocument), WebKit
//! EventHandler::clear (from FrameLoader::clear), Gecko PresShell::Destroy
//! (EventStateManager::NotifyDestroyPresContext). The citations are at src/html/user_input.zig
//! Pointer.currentTarget.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const input = @import("html").user_input;
const h = @import("tl1_pending_timer_helpers.zig");

const Ending = enum {
    /// The frame is removed from its document.
    frame_removed,
    /// The frame navigates to another document, as the WPT file's frames do.
    frame_navigated,
};

const page_html =
    "<!doctype html><body><button id=outside>outside</button>" ++
    "<iframe id=frame srcdoc=\"<!doctype html><body><button id=inside>inside</button></body>\"></iframe></body>";

fn element(document: *runtime.Instance, comptime id: []const u8) !*runtime.Instance {
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoSuchElement;
}

fn exercise(comptime ending: Ending) !void {
    const page = try h.Page.open(page_html, "http://127.0.0.1:65533/start");
    defer page.close();
    // The frame's srcdoc document loads.
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
    const inside = try element(frame_document, "inside");
    const outside = try element(document, "outside");

    // Script keeps the frame's button, and hears what is fired at it and at the page's button.
    try page.run(
        \\globalThis.kept = document.getElementById('frame').contentDocument.getElementById('inside');
        \\globalThis.heard = [];
        \\for (const type of ['pointerover', 'pointerout', 'pointerleave', 'mouseout', 'mouseleave']) {
        \\  kept.addEventListener(type, () => heard.push('inside ' + type));
        \\  document.getElementById('outside').addEventListener(type, () => heard.push('outside ' + type));
        \\}
    );

    var pointer: input.Pointer = .{};
    input.pointerMove(&pointer, inside, .{});
    try page.run(
        \\if (heard.join() !== 'inside pointerover') throw new Error('the pointer did not enter the frame button: ' + heard.join());
        \\heard.length = 0;
    );

    // The frame's document ends; its button lives on in script's hands.
    switch (ending) {
        .frame_removed => try page.run("document.getElementById('frame').remove();"),
        .frame_navigated => {
            try page.run(
                \\state = 'pending';
                \\const frame = document.getElementById('frame');
                \\frame.onload = () => { state = 'navigated'; };
                \\frame.removeAttribute('srcdoc');
                \\frame.src = 'about:blank';
            );
            try page.waitForState("navigated");
        },
    }

    // The pointer is over nothing: the document it was over has gone (before the fix it still named the
    // old button).
    try std.testing.expect(pointer.currentTarget() == null);
    // It moves onto the page's button, entering it from nowhere.
    input.pointerMove(&pointer, outside, .{});
    try page.run(
        \\if (heard.join() !== 'outside pointerover') throw new Error('heard: ' + heard.join());
    );
}

fn check(comptime ending: Ending) !void {
    try h.onFreshThread(struct {
        fn body() !void {
            try exercise(ending);
        }
    }.body);
}

test "a pointer leaving an element of a removed frame's document fires no boundary events at it" {
    try check(.frame_removed);
}

test "a pointer leaving an element of a navigated frame's old document fires no boundary events at it" {
    try check(.frame_navigated);
}
