//! Lane rendering1: the rendering opportunity's frame clock and "update the
//! rendering" (HTML 8.1.7.3), driven from a real Browser loop.
//!
//! Each test runs on a thread of its own (a Browser per thread; the test
//! directory is one executable - AGENTS.md "A test directory is one
//! executable").
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

/// Pump the page's loop until `condition` evaluates to "true": at most
/// `turns` loop turns, each waiting at most 5 ms for a timer. A false
/// condition at the end fails the test.
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

fn framesLandOnTheRefreshGrid() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Five consecutive frames, each requested from the previous one.
    try page.run(
        \\globalThis.stamps = [];
        \\requestAnimationFrame(function tick(t) {
        \\  stamps.push([t, performance.now()]);
        \\  if (stamps.length < 5) requestAnimationFrame(tick);
        \\});
    );
    try pumpUntil(page, "stamps.length === 5", 400);
    // Each timestamp is a refresh moment: never after the callback's own
    // now, and consecutive frames are whole refresh intervals apart (a
    // display's vsync grid), not "16 ms after the timer last fired".
    const result = try page.evaluate(
        \\(() => {
        \\  const out = [];
        \\  for (let i = 0; i < stamps.length; i++) {
        \\    const [t, now] = stamps[i];
        \\    if (t > now + 0.001) out.push('frame ' + i + ' timestamp ' + t + ' after now ' + now);
        \\    if (i > 0) {
        \\      const gap = (t - stamps[i - 1][0]) / (1000 / 60);
        \\      if (gap < 0.98 || Math.abs(gap - Math.round(gap)) > 0.02) out.push('gap ' + i + ' is ' + gap + ' frames');
        \\    }
        \\  }
        \\  return out.join('; ') || 'ok';
        \\})()
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

test "rAF timestamps are refresh moments: whole frames apart, never after now" {
    try helpers.onFreshThread(framesLandOnTheRefreshGrid);
}

fn childTimestampIsRelativeToItsOwnTimeOrigin() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.child = document.createElement('iframe');
        \\child.srcdoc = '<!doctype html><body>child';
        \\globalThis.loaded = false;
        \\child.onload = () => { loaded = true; };
        \\document.body.appendChild(child);
    );
    try pumpUntil(page, "loaded", 400);
    // One frame: the parent's and the child's callbacks share the frame's
    // timestamp, each as a relative high resolution time of its own global
    // (HTML update the rendering step 14).
    try page.run(
        \\globalThis.seen = null;
        \\const w = child.contentWindow;
        \\let parentStamp, childStamp, childNow;
        \\requestAnimationFrame(t => { parentStamp = t; });
        \\w.requestAnimationFrame(t => {
        \\  childStamp = t; childNow = w.performance.now();
        \\  seen = { parentStamp, childStamp, childNow,
        \\           shift: w.performance.timeOrigin - performance.timeOrigin };
        \\});
    );
    try pumpUntil(page, "seen !== null", 400);
    const result = try page.evaluate(
        \\(() => {
        \\  const { parentStamp, childStamp, childNow, shift } = seen;
        \\  if (childStamp > childNow + 0.001) return 'child timestamp ' + childStamp + ' after its now ' + childNow;
        \\  if (Math.abs((parentStamp - childStamp) - shift) > 0.25) return 'parent ' + parentStamp + ' child ' + childStamp + ' origin shift ' + shift;
        \\  return 'ok';
        \\})()
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

test "a child document's rAF timestamp is the same frame, relative to its own time origin" {
    try helpers.onFreshThread(childTimestampIsRelativeToItsOwnTimeOrigin);
}

fn parentThenChildrenInContainerOrder() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.ready = 0;
        \\function frame() {
        \\  const f = document.createElement('iframe');
        \\  f.srcdoc = '<!doctype html><body>';
        \\  f.onload = () => { ready++; };
        \\  return f;
        \\}
        \\globalThis.second = frame(); document.body.prepend(second);
        \\globalThis.first = frame(); document.body.prepend(first);
    );
    try pumpUntil(page, "ready === 2", 400);
    try page.run(
        \\globalThis.order = [];
        \\second.contentWindow.requestAnimationFrame(() => order.push('second'));
        \\first.contentWindow.requestAnimationFrame(() => order.push('first'));
        \\requestAnimationFrame(() => order.push('parent'));
    );
    try pumpUntil(page, "order.length === 3", 400);
    const result = try page.evaluate("order.join()");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("parent,first,second", result);
}

test "one frame runs the parent's callbacks, then its children's in container order" {
    try helpers.onFreshThread(parentThenChildrenInContainerOrder);
}

fn cancelWithinAFrameAndMicrotasksBetweenCallbacks() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.log = [];
        \\let b;
        \\requestAnimationFrame(() => {
        \\  log.push('a');
        \\  cancelAnimationFrame(b);
        \\  Promise.resolve().then(() => log.push('microtask'));
        \\});
        \\b = requestAnimationFrame(() => log.push('b'));
        \\requestAnimationFrame(() => { log.push('c'); globalThis.done = true; });
        \\globalThis.done = false;
    );
    try pumpUntil(page, "done", 400);
    const result = try page.evaluate("log.join()");
    defer std.testing.allocator.free(result);
    // "run the animation frame callbacks" step 3: a handle cancelled by an
    // earlier callback of the same frame is skipped; each callback's "clean
    // up after running script" performs a microtask checkpoint.
    try std.testing.expectEqualStrings("a,microtask,c", result);
}

test "cancelAnimationFrame in a frame skips a later callback; microtasks run between callbacks" {
    try helpers.onFreshThread(cancelWithinAFrameAndMicrotasksBetweenCallbacks);
}

fn noFrameWithoutDemand() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.ran = false;
        \\requestAnimationFrame(() => { ran = true; });
    );
    try pumpUntil(page, "ran", 400);
    // The frame ran and nothing asked for another: no rendering opportunity
    // stays armed, so the loop has no pending work of its own.
    var turns: usize = 0;
    while (turns < 10) : (turns += 1) _ = try page.browser.runEventLoopBlocking(20);
    const loop = page.browser.event_loop.?;
    try std.testing.expect(!loop.hasPendingWork());
}

test "a page that asks for no frame keeps no rendering opportunity armed" {
    try helpers.onFreshThread(noFrameWithoutDemand);
}

fn idleDeadlineStopsAtThePendingFrame() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.remaining = null;
        \\requestAnimationFrame(() => {});
        \\requestIdleCallback(d => { remaining = d.timeRemaining(); });
    );
    try pumpUntil(page, "remaining !== null", 400);
    const result = try page.evaluate("remaining <= 1000 / 60 + 0.1 ? 'ok' : String(remaining)");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

test "an idle period ends at the next rendering opportunity while a frame is wanted" {
    try helpers.onFreshThread(idleDeadlineStopsAtThePendingFrame);
}
