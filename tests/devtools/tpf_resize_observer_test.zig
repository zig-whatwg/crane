//! ResizeObserver at the rendering update, driven over CDP as the framework
//! suites drive it (lane tpf): Svelte's runtime-browser dimension bindings
//! (bind:clientWidth and friends wait on a ResizeObserver callback) and
//! zone.js's ResizeObserver patch tests (Angular) both timed out - Crane's
//! ResizeObserver was a stub whose observe() threw.
//!
//! Resize Observer 1 (specs/w3c/resize-observer-1.md) section 3.4 with HTML
//! "update the rendering" step 16.2.5-16.3: an observation starts with
//! last reported size -1 x -1, so it is delivered at the next rendering
//! update; with no platform renderer every box is 0x0 (Crane lays nothing
//! out), so it is delivered once and never again until a size changes.

const std = @import("std");
const testing = std.testing;
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

/// A page session on the fixture's tab, Runtime enabled, with a body; its
/// id, OWNED.
fn pageSession(allocator: std.mem.Allocator, rec: *replay.Recorder) ![]u8 {
    const auto = try rec.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":false,\"flatten\":true}", "");
    _ = try rec.result(auto);
    const attached = try rec.awaitEvent("Target.attachedToTarget", "", 0, &.{.{ .path = "params.targetInfo.type", .equals = "page" }});
    const session = try replay.dupeAt(allocator, rec.at(attached), "params.sessionId");
    errdefer allocator.free(session);
    _ = try rec.result(try rec.send("Runtime.enable", "{}", session));
    _ = try evaluate(rec, session, "document.body || document.documentElement.appendChild(document.createElement('body'))", false);
    return session;
}

/// Runtime.evaluate of `expression` (no double quotes) on `session`, its
/// result's value as text, awaiting a promise when `await_promise`. The
/// text is the log's.
fn evaluate(rec: *replay.Recorder, session: []const u8, expression: []const u8, await_promise: bool) ![]const u8 {
    var buffer: [768]u8 = undefined;
    const awaiting = if (await_promise) ",\"awaitPromise\":true" else "";
    const id = try rec.send("Runtime.evaluate", try std.fmt.bufPrint(&buffer, "{{\"expression\":\"{s}\",\"returnByValue\":true{s}}}", .{ expression, awaiting }), session);
    if (try rec.errorCode(id)) |code| {
        std.debug.print("Runtime.evaluate {s}: error {d}\n", .{ expression, code });
        return error.EvaluateFailed;
    }
    const r = try rec.result(id);
    if (cdp.at(r, "exceptionDetails") != null) {
        std.debug.print("Runtime.evaluate {s}: threw {s}\n", .{ expression, cdp.stringAt(r, "result.description") orelse "?" });
        return error.EvaluateThrew;
    }
    return cdp.stringAt(r, "result.value") orelse "(not a string)";
}

test "ResizeObserver: an observation is delivered at the next rendering update - its target, 0x0 boxes with no renderer, the observer as this and as the second argument, each size array the same frozen array" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const session = try pageSession(allocator, rec);
    defer allocator.free(session);

    const delivered = try evaluate(rec, session,
        \\new Promise((resolve) => { const p = document.createElement('p'); document.body.append(p); const ro = new ResizeObserver(function (entries, observer) { const e = entries[0]; resolve([entries.length, e.target === document.body, entries[1].target === p, this === ro, observer === ro, e.contentRect.width, e.contentRect.height, e.borderBoxSize[0].inlineSize, e.contentBoxSize[0].blockSize, e.devicePixelContentBoxSize.length, e.borderBoxSize === e.borderBoxSize, Object.isFrozen(e.contentBoxSize)].join()); }); ro.observe(document.body); ro.observe(p, { box: 'border-box' }); })
    , true);
    try testing.expectEqualStrings("2,true,true,true,true,0,0,0,0,1,true,true", delivered);
}

test "ResizeObserver: delivered once while the size does not change; observing a target twice is one observation; unobserve and disconnect before the update deliver nothing" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const session = try pageSession(allocator, rec);
    defer allocator.free(session);

    _ = try evaluate(rec, session,
        \\globalThis.calls = []; const once = new ResizeObserver((entries) => calls.push('once:' + entries.length)); once.observe(document.body); once.observe(document.body); const gone = new ResizeObserver(() => calls.push('unobserved')); gone.observe(document.body); gone.unobserve(document.body); const cut = new ResizeObserver(() => calls.push('disconnected')); cut.observe(document.body); cut.disconnect(); 'ok'
    , false);
    // Three rendering updates: the first delivers, the next two do not.
    const seen = try evaluate(rec, session, "new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => requestAnimationFrame(() => resolve(calls.join())))))", true);
    try testing.expectEqualStrings("once:1", seen);
}

test "ResizeObserver: an exception in the callback is reported to the window and the next observer still runs" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const session = try pageSession(allocator, rec);
    defer allocator.free(session);

    const seen = try evaluate(rec, session,
        \\new Promise((resolve) => { const log = []; addEventListener('error', (e) => { log.push('error:' + e.error.message + ':' + e.message.endsWith('Error: boom')); e.preventDefault(); }); new ResizeObserver(() => { throw new Error('boom'); }).observe(document.body); new ResizeObserver(() => { log.push('second'); resolve(log.join()); }).observe(document.body); })
    , true);
    try testing.expectEqualStrings("error:boom:true,second", seen);
}
