//! A document without a body is render-blocked only while it is loading
//! (lane crash1 batch 2: 28 WPT crashtests waited for test-wait.js's
//! animation frames, which never came).
//!
//! HTML 3.1.6: a Document "allows adding render-blocking elements" when its
//! content type is text/html and its body element is null, and is
//! render-blocked while its render-blocking element set is non-empty OR it
//! allows adding them, until an implementation-defined timeout - so a
//! loaded document whose script removed its body, or its root, or replaced
//! the root with another element, had no rendering opportunity (update the
//! rendering removes render-blocked documents) until Crane's 30 s timeout.
//!
//! No browser does that: Chrome 157, Firefox 159 and Safari 27.2 pass every
//! such crashtest (dom/nodes/crashtests/documentElement-remove-descendant-
//! query.html, editing/crashtests/selection-modify-after-body-removed-in-
//! design-mode.html and 26 more; wpt.fyi stable, run fea36e49dd). Gecko's
//! Document::IsRenderBlocked: "The spec does not check the ready state, so a
//! document without a body is render-blocked until the timeout, also after
//! parsing. Here a missing body blocks rendering only while parsing, so that
//! a document renders when script removes the body or the root element" -
//! `!mRenderBlockingElementSet.IsEmpty() || (AllowsAddingRenderBlocking
//! Elements() && mReadyState == READYSTATE_LOADING)`. Blink
//! (RenderBlockingResourceManager) and WebKit (Document::blockRenderingOn)
//! block on the set alone; a missing body only stops elements joining it.
//! No newer spec is involved: golden rule 2, the browsers; Crane takes
//! Gecko's condition, which keeps the spec's rule while the document loads.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

/// Pump the page's loop until `condition` evaluates to "true": at most
/// `turns` loop turns of at most 5 ms each. A false condition at the end
/// fails the test.
fn pumpUntil(page: helpers.Page, condition: []const u8, turns: usize) !void {
    var turn: usize = 0;
    while (turn < turns) : (turn += 1) {
        _ = try page.browser.runEventLoopBlocking(5);
        const value = try page.evaluate(condition);
        defer std.testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
    }
    const value = try page.evaluate(condition);
    defer std.testing.allocator.free(value);
    std.debug.print("condition never held: {s} -> {s}\n", .{ condition, value });
    return error.ConditionNeverHeld;
}

/// After `mutation` - with the document loaded - two animation frames in a
/// row run, as test-wait.js waits for them.
fn framesRunAfter(comptime mutation: []const u8) fn () anyerror!void {
    return struct {
        fn run() !void {
            const page = try helpers.Page.open();
            defer page.close();
            try page.run("globalThis.frames = 0;" ++ mutation ++
                "requestAnimationFrame(() => { frames++; requestAnimationFrame(() => { frames++; }); });");
            // 400 turns: about 2 s, far below the 30 s timeout.
            try pumpUntil(page, "frames === 2", 400);
        }
    }.run;
}

test "a loaded document whose body script removed has rendering opportunities" {
    try helpers.onFreshThread(framesRunAfter("document.body.remove();"));
}

test "a loaded document whose root script removed has rendering opportunities" {
    try helpers.onFreshThread(framesRunAfter("document.documentElement.remove();"));
}

test "a loaded document whose root script replaced with a br has rendering opportunities" {
    try helpers.onFreshThread(framesRunAfter("document.replaceChild(document.createElement('br'), document.documentElement);"));
}

test "no animation frame runs while a body-less document is loading (document.open), one runs once it has a body" {
    try helpers.onFreshThread(struct {
        fn run() !void {
            const page = try helpers.Page.open();
            defer page.close();
            // document.open: readiness "loading", every child gone - no body.
            // Each frame records the state it ran in: none may run while the
            // document is loading without a body (the spec's rule, kept).
            try page.run(
                \\globalThis.seen = [];
                \\document.open();
                \\requestAnimationFrame(function tick() { seen.push(document.readyState + ' ' + (document.body === null)); if (seen.length < 3) requestAnimationFrame(tick); });
            );
            const state = try page.evaluate("document.readyState + ' ' + (document.body === null)");
            defer std.testing.allocator.free(state);
            try std.testing.expectEqualStrings("loading true", state);
            for (0..40) |_| _ = try page.browser.runEventLoopBlocking(5);
            const loading_frames = try page.evaluate("seen.filter(s => s === 'loading true').length");
            defer std.testing.allocator.free(loading_frames);
            try std.testing.expectEqualStrings("0", loading_frames);
            // The body arrives: no longer render-blocked.
            try page.run("document.write('<body>'); document.close();");
            try pumpUntil(page, "seen.length >= 1", 400);
            const after = try page.evaluate("seen.filter(s => s === 'loading true').length");
            defer std.testing.allocator.free(after);
            try std.testing.expectEqualStrings("0", after);
        }
    }.run);
}
