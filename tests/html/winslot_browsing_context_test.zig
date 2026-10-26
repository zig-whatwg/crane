//! No browsing context names a Window whose realm has ended (lane winslot1,
//! kind 1).
//!
//! A browsing context's active window is a bare pointer, read by user
//! activation, the opener, frames[i], a frame's named property and the
//! navigable destruction steps. When an iframe is removed its browsing
//! context is discarded but, a Window having been active in it, retired
//! rather than freed (BrowsingContext.discard) - and nothing cleared its
//! active window when that Window's realm ended: the retired context named a
//! torn-down Window, and once the Window's slot goes back, whatever the slab
//! issues there next. The Window's teardown now clears it on every context
//! of its Browser that names it (Navigables.forgetWindow), as Blink's
//! DOMWindow::DisconnectFromFrame and the frame's window reset clear both
//! sides.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const dom = @import("dom");
const helpers = @import("winslot_helpers.zig");

/// How many browsing contexts of the Browser - live or retired - name
/// `window` as their active window.
fn contextsNaming(page: helpers.Page, window: *runtime.Instance) usize {
    const navigables = dom.browser_state.existingNavigablesIn(page.browser.scope) orelse return 0;
    var n: usize = 0;
    for (navigables.live.items) |ctx| {
        if (ctx.active_window == @as(?*anyopaque, @ptrCast(window))) n += 1;
    }
    return n;
}

fn removedFrame() !void {
    const page = try helpers.Page.open();
    defer page.close();
    var before: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer before.deinit(testing.allocator);
    try helpers.windows(page.browser, &before);
    try page.run(
        \\globalThis.pending = 1;
        \\globalThis.f = document.body.appendChild(document.createElement('iframe'));
        \\f.addEventListener('load', () => { pending = 0; }, { once: true });
        \\f.srcdoc = '<body>one</body>';
    );
    try page.settle();
    const frame = try helpers.newWindow(page.browser, before.items);
    try testing.expectEqual(@as(usize, 1), contextsNaming(page, frame.window));

    // Removed: its browsing context is discarded and retired, its realm
    // detached; then the collector takes the realm and its end runs.
    try page.run("f.remove(); delete globalThis.f;");
    try page.collect();
    try testing.expect(frame.ended());
    const naming = contextsNaming(page, frame.window);
    if (naming != 0) std.debug.print("{d} browsing context(s) still name the ended Window\n", .{naming});
    try testing.expectEqual(@as(usize, 0), naming);
}

test "a removed frame's retired browsing context no longer names its Window once the Window's realm ends" {
    try helpers.onFreshThread(removedFrame);
}

fn navigatedFrame() !void {
    const page = try helpers.Page.open();
    defer page.close();
    var before: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer before.deinit(testing.allocator);
    try helpers.windows(page.browser, &before);
    try page.run(
        \\globalThis.pending = 1;
        \\globalThis.f = document.body.appendChild(document.createElement('iframe'));
        \\f.addEventListener('load', () => { pending = 0; }, { once: true });
        \\f.srcdoc = '<body>one</body>';
    );
    try page.settle();
    const old = try helpers.newWindow(page.browser, before.items);
    try page.run(
        \\globalThis.pending = 1;
        \\f.addEventListener('load', () => { pending = 0; }, { once: true });
        \\f.srcdoc = '<body>two</body>';
    );
    try page.settle();
    try page.collect();
    try testing.expect(old.ended());
    try testing.expectEqual(@as(usize, 0), contextsNaming(page, old.window));
    // The frame's context names its current Window, and the frame still works.
    try page.expectEval("f.contentDocument.body.textContent + ':' + (frames[0] === f.contentWindow)", "two:true");
}

test "a navigated frame's browsing context names only its current Window" {
    try helpers.onFreshThread(navigatedFrame);
}
