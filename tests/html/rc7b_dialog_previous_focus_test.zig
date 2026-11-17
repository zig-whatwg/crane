//! A dialog's previously focused element is a WEAK link (lane rc7b, refcount
//! step 7b): WebKit's HTMLDialogElement keeps `WeakPtr<Element>
//! m_previouslyFocusedElement`. A counted reference was a node holding a
//! node of its own tree - another dialog, or the dialog itself - which the
//! counts could never free once the forced free at a realm's end was gone.
//! What script sees is unchanged: "close the dialog" step 12 focuses the
//! element that was focused before showModal() while it is still there, and
//! does nothing - no error - when that element was removed and dropped.

const std = @import("std");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

fn expectTrue(page: h.Page, source: []const u8) !void {
    const context = page.browser.current_context orelse return error.NoPage;
    const got = try context.evaluateScriptToString(source, std.testing.allocator);
    defer std.testing.allocator.free(got);
    if (!std.mem.eql(u8, got, "true")) {
        std.debug.print("expected true: {s} (got {s})\n", .{ source, got });
        return error.TestUnexpectedResult;
    }
}

fn settle(page: h.Page) !void {
    for (0..3) |_| {
        _ = try page.browser.runEventLoopBlocking(20);
        try page.run("TestUtils.gc(); TestUtils.gc(); 0;");
    }
    _ = try page.browser.runEventLoopBlocking(20);
}

fn focusRestoredToAConnectedElement() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id="b">b</button><dialog id="d"><input id="i"></dialog>';
        \\document.getElementById('b').focus();
        \\document.getElementById('d').showModal();
        \\0;
    );
    try expectTrue(page, "document.activeElement.id === 'i'");
    try settle(page);
    try page.run("document.getElementById('d').close(); 0;");
    try expectTrue(page, "document.activeElement === document.getElementById('b')");
}

test "a modal dialog closed gives focus back to the element focused before showModal() while it is still connected" {
    try onFreshThread(focusRestoredToAConnectedElement);
}

fn focusRestoredToNothingWhenTheElementWentAway() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id="b">b</button><dialog id="d"><input id="i"></dialog>';
        \\document.getElementById('b').focus();
        \\document.getElementById('d').showModal();
        \\// The previously focused element leaves the document, and script
        \\// keeps nothing of it.
        \\(() => { document.getElementById('b').remove(); })();
        \\0;
    );
    try settle(page);
    try page.run("document.getElementById('d').close(); 0;");
    // As before the link was weak: no element to give focus back to, so
    // focus is not moved (the removed element could not take it anyway).
    try expectTrue(page, "!document.getElementById('d').open && document.activeElement !== null && document.activeElement.isConnected");
}

test "a modal dialog closed after the element focused before showModal() was removed and dropped focuses nothing, and throws nothing" {
    try onFreshThread(focusRestoredToNothingWhenTheElementWentAway);
}

fn dialogSavedAsItsOwnPreviousFocus() !void {
    const page = try h.Page.open();
    defer page.close();
    const before = blk: {
        _ = try page.browser.runEventLoopBlocking(20);
        break :blk h.dom.instance_bridge.entryCount(page.browser.scope);
    };
    // showModal(), close(), showModal(): at the second call the dialog
    // itself is focused, so it is its own previously focused element. Then
    // it leaves the document while open (no close: removal runs the dialog
    // cleanup steps only) and script drops it. A counted saved focus kept
    // it alive for ever.
    try page.run(
        \\(() => {
        \\  const d = document.body.appendChild(document.createElement('dialog'));
        \\  d.showModal(); d.close(); d.showModal();
        \\  d.remove();
        \\})();
        \\0;
    );
    try settle(page);
    const after = h.dom.instance_bridge.entryCount(page.browser.scope);
    if (after != before) {
        std.debug.print("{d} node(s) before, {d} after the dialog was dropped\n", .{ before, after });
        h.dom.refcount_teardown.describeLiveNodes(page.browser.scope, 20);
        return error.NodesLeftAlive;
    }
}

test "a dialog that saved itself as its previously focused element is freed once removed and dropped" {
    try onFreshThread(dialogSavedAsItsOwnPreviousFocus);
}
