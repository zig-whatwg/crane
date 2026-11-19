//! Lane blk4: the algorithms that move or unset a document's sequential
//! focus navigation starting point (HTML 6.6.5), which Crane keeps as a live
//! Range since the focused element is the point (dom.focused_area.set).
//!
//! - "Sequential navigation" step 7: a navigation that finds no candidate
//!   unsets the point, so the next one starts from the document - not from a
//!   point nothing follows, where every later Tab would find nothing again.
//! - Navigation API "potentially reset the focus" step 12: after the reset,
//!   the point is the focus target (the body), so Tab goes to the first
//!   focusable element, not the one after the element focused before the
//!   navigation (navigation-api/focus-reset/basic.html, which Chrome passes).
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

fn tabFromAPointNothingFollows() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id="first">a</button><button id="last">b</button>';
        \\last.focus(); last.blur();
    );
    try expectScript(page, "document.activeElement === document.body", "true");
    const document = page.browser.current_context.?.document_instance.?;
    // The point is where `last` was: nothing follows it, focus stays put
    // (step 8: a headless top-level traversable has no controls of its own)
    // and the point is unset.
    html.focus.navigateSequentially(document, .forward);
    try expectScript(page, "document.activeElement === document.body", "true");
    // So the next Tab starts from the document.
    html.focus.navigateSequentially(document, .forward);
    try expectScript(page, "document.activeElement.id", "first");
}

test "sequential navigation that finds nothing after the point unsets it: the next starts from the document" {
    try helpers.onFreshThread(tabFromAPointNothingFollows);
}

fn tabAfterAFocusReset() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id="first">a</button><button id="second">b</button>';
        \\globalThis.done = false;
        \\navigation.addEventListener('navigate', e => e.intercept({ handler: () => Promise.resolve() }), { once: true });
        \\first.focus();
        \\navigation.navigate('#reset').finished.then(() => { done = true; }, () => { done = true; });
    );
    // Bounded by turns, not by the clock: each turn returns once nothing is
    // pending.
    var turns: usize = 0;
    while (turns < 50) : (turns += 1) {
        const finished = try page.evaluate("String(done)");
        defer std.testing.allocator.free(finished);
        if (std.mem.eql(u8, finished, "true")) break;
        try page.turn();
    }
    try expectScript(page, "String(done)", "true");
    try expectScript(page, "document.activeElement === document.body", "true");
    const document = page.browser.current_context.?.document_instance.?;
    html.focus.navigateSequentially(document, .forward);
    try expectScript(page, "document.activeElement.id", "first");
}

test "after the navigation API resets the focus, Tab starts from the focus target" {
    try helpers.onFreshThread(tabAfterAFocusReset);
}
