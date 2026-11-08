//! An object element whose load failed is not fetched again when it is
//! moved (lane crash1 batch 2: editing/crashtests/insertAdjacentElement-
//! with-DOMSubtreeModified.html never finished loading).
//!
//! HTML 4.8.7 re-determines what an object represents whenever it is
//! inserted into or removed from a document, so an error handler that moves
//! its object - that crashtest's - fetches again, fails again, moves it
//! again: forever, each round delaying the load event. Firefox 159 does
//! that (4 fetches and 4 error events for a 404 object moved 3 times);
//! Chrome 157 fetches once and fires one error, Safari 27.2 fetches once and
//! fires none (crash1 b2 probe, tmp/crash1/probe/d2b.html, a 404-counting
//! server). Per mechanism: an error event on a failed load (Chrome,
//! Firefox), no new fetch when an object whose load failed moves (Chrome,
//! Safari) - together Chrome's behaviour: Blink's
//! HTMLObjectElement::RenderFallbackContent sets use_fallback_content_, and
//! HTMLPlugInElement::AttachLayoutTree does nothing while UseFallbackContent()
//! holds. A data or type attribute change still re-determines it (the
//! spec's trigger, unchanged).
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

fn pump(page: helpers.Page, turns: usize) !void {
    for (0..turns) |_| _ = try page.browser.runEventLoopBlocking(5);
}

fn expectValue(page: helpers.Page, source: []const u8, want: []const u8) !void {
    const got = try page.evaluate(source);
    defer std.testing.allocator.free(got);
    if (!std.mem.eql(u8, want, got)) std.debug.print("{s}\n  answered {s}\n", .{ source, got });
    try std.testing.expectEqualStrings(want, got);
}

/// An object whose data cannot be parsed into a URL (relative to
/// about:blank): step 3.3 fires error and falls back - a failed load with no
/// network.
const setup =
    \\globalThis.errors = 0;
    \\document.body.innerHTML = '<div id=a></div><div id=b></div>';
    \\globalThis.o = document.createElement('object');
    \\o.onerror = () => { errors++; };
    \\o.data = 'invalid-url';
    \\document.getElementById('a').appendChild(o);
;

test "an object whose load failed fires error once, and moving it fetches nothing again" {
    try helpers.onFreshThread(struct {
        fn run() !void {
            const page = try helpers.Page.open();
            defer page.close();
            try page.run(setup);
            try pumpUntil(page, "errors === 1", 200);
            // Three moves: removed from and inserted into the document each
            // time.
            try page.run(
                \\document.getElementById('b').appendChild(o);
                \\document.getElementById('a').appendChild(o);
                \\document.getElementById('b').insertAdjacentElement('beforebegin', o);
            );
            try pump(page, 40);
            try expectValue(page, "errors", "1");
        }
    }.run);
}

test "an error handler that moves its object does not loop: the document's load event fires" {
    try helpers.onFreshThread(struct {
        fn run() !void {
            const page = try helpers.Page.open();
            defer page.close();
            // The crashtest's shape: the handler moves the object in front of
            // its next sibling (a remove and an insert) each time it runs.
            try page.run(
                \\globalThis.errors = 0;
                \\document.body.innerHTML = '<object id=x2></object><div id=x3></div>';
                \\const o = document.getElementById('x2');
                \\o.onerror = () => { errors++; document.getElementById('x3').insertAdjacentElement('beforebegin', o); };
                \\o.data = 'invalid-url';
            );
            try pumpUntil(page, "errors >= 1", 200);
            try pump(page, 40);
            try expectValue(page, "errors", "1");
        }
    }.run);
}

test "a data attribute change after a failed load re-determines the object" {
    try helpers.onFreshThread(struct {
        fn run() !void {
            const page = try helpers.Page.open();
            defer page.close();
            try page.run(setup);
            try pumpUntil(page, "errors === 1", 200);
            try page.run("o.data = 'still-invalid';");
            try pumpUntil(page, "errors === 2", 200);
        }
    }.run);
}
