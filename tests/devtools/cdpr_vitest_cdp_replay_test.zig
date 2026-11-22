//! Vitest browser mode's `cdp()`, replayed (lane cdpr, part C of the CDP part
//! 1 conformance trace, tmp/plans/cdp-conformance-trace.md): Vue's
//! TransitionGroup tests call `cdp().send('HeapProfiler.collectGarbage')` 190
//! times, through @vitest/browser-playwright - Playwright's
//! `newCDPSession(page)` = Target.attachToBrowserTarget, then
//! Target.attachToTarget from that session: a SECOND session on a page the
//! runner already drives, with its own domain state. Its CDPSession sends the
//! command with `"params": null` (tmp/plans/cdp1-evidence/
//! vue-e2e-browser.protocol.log l.859-926), which Chrome for Testing 157
//! answers (crdtp Dispatchable::MaybeParseParams).
//!
//! Written in the CDP phase, not run (user directive 2026-11-21 5:48 PM ET:
//! implement now, run every test in one later pass). Gap G2 (fixed on
//! lane/cdpr, json_rpc.zig) is what the null params check.

const std = @import("std");
const testing = std.testing;
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

test "Vitest cdp(): a browser session from attachToBrowserTarget attaches a second page session; HeapProfiler.collectGarbage with \"params\": null succeeds on it (G2)" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;

    // The runner's own session on the page (Playwright's auto-attach).
    const auto = try rec.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true}", "");
    _ = try rec.result(auto);
    const first = try rec.awaitEvent("Target.attachedToTarget", "", 0, &.{.{ .path = "params.targetInfo.type", .equals = "page" }});
    const page_id = try replay.dupeAt(allocator, rec.at(first), "params.targetInfo.targetId");
    defer allocator.free(page_id);
    const runner_session = try replay.dupeAt(allocator, rec.at(first), "params.sessionId");
    defer allocator.free(runner_session);
    const runner_runtime = try rec.send("Runtime.enable", "{}", runner_session);
    _ = try rec.result(runner_runtime);

    // cdp(): attachToBrowserTarget (#48) - attachedToTarget for the browser
    // target on the caller, then the new session's id.
    const browser_start = rec.log.items.len;
    const to_browser = try rec.send("Target.attachToBrowserTarget", "{}", "");
    const browser_reply = try rec.awaitResponse(to_browser);
    const browser_session = try replay.dupeAt(allocator, try rec.result(to_browser), "sessionId");
    defer allocator.free(browser_session);
    const announced = rec.eventIndex("Target.attachedToTarget", "", browser_start, &.{
        .{ .path = "params.sessionId", .equals = browser_session },
        .{ .path = "params.targetInfo.type", .equals = "browser" },
    }) orelse return error.BrowserSessionNotAnnounced;
    try testing.expect(announced < browser_reply);

    // attachToTarget {targetId, flatten} FROM that session (#49): announced
    // on it, a new session on the page.
    var buffer: [256]u8 = undefined;
    const page_start = rec.log.items.len;
    const to_page = try rec.send("Target.attachToTarget", try std.fmt.bufPrint(&buffer, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{page_id}), browser_session);
    const page_reply = try rec.awaitResponse(to_page);
    const second = try replay.dupeAt(allocator, try rec.result(to_page), "sessionId");
    defer allocator.free(second);
    try testing.expect(!std.mem.eql(u8, second, runner_session));
    const attached = rec.eventIndex("Target.attachedToTarget", browser_session, page_start, &.{
        .{ .path = "params.sessionId", .equals = second },
        .{ .path = "params.targetInfo.targetId", .equals = page_id },
    }) orelse return error.PageSessionNotAnnounced;
    try testing.expect(attached < page_reply);

    // HeapProfiler.collectGarbage, exactly as the CDPSession sends it (#50):
    // "params": null. Answered {} each time; V8's GC task runs from the
    // Browser's loop (its foreground task runner, pumped there).
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const id = rec.takeId();
        const message = try std.fmt.bufPrint(&buffer, "{{\"id\":{d},\"method\":\"HeapProfiler.collectGarbage\",\"params\":null,\"sessionId\":\"{s}\"}}", .{ id, second });
        try rec.sendText(message);
        try testing.expectEqual(@as(?i64, null), try rec.errorCode(id));
        const r = try rec.result(id);
        try testing.expectEqual(@as(usize, 0), r.object.count());
    }
    // A command with no params at all, as Playwright sends Page.enable.
    const no_params_id = rec.takeId();
    try rec.sendText(try std.fmt.bufPrint(&buffer, "{{\"id\":{d},\"method\":\"Runtime.enable\",\"sessionId\":\"{s}\"}}", .{ no_params_id, second }));
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(no_params_id));
    // The second session's own Runtime: its own report of the page's main
    // context, on it (the runner's session already had one).
    _ = try rec.awaitEvent("Runtime.executionContextCreated", second, page_reply, &.{
        .{ .path = "params.context.auxData.isDefault", .equals = "true" },
        .{ .path = "params.context.auxData.frameId", .equals = page_id },
    });

    // The runner's session is untouched by the second's commands.
    const still = try rec.send("Runtime.evaluate", "{\"expression\":\"1 + 1\",\"returnByValue\":true}", runner_session);
    try testing.expectEqual(@as(i64, 2), cdp.at(try rec.result(still), "result.value").?.integer);

    // Detaching the second session (the test's end) ends only it.
    const detach = try rec.send("Target.detachFromTarget", try std.fmt.bufPrint(&buffer, "{{\"sessionId\":\"{s}\"}}", .{second}), browser_session);
    try testing.expectEqual(@as(?i64, null), try rec.errorCode(detach));
    const again = try rec.send("Runtime.evaluate", "{\"expression\":\"2 + 2\",\"returnByValue\":true}", runner_session);
    try testing.expectEqual(@as(i64, 4), cdp.at(try rec.result(again), "result.value").?.integer);
}

test "the devtools thread's sessions take \"params\": null too: Target.getTargetInfo and Browser.getVersion (G2)" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    var buffer: [128]u8 = undefined;
    for ([_][]const u8{ "Browser.getVersion", "Target.getTargetInfo", "Target.getTargets" }) |method| {
        const id = rec.takeId();
        try rec.sendText(try std.fmt.bufPrint(&buffer, "{{\"id\":{d},\"method\":\"{s}\",\"params\":null}}", .{ id, method }));
        try testing.expectEqual(@as(?i64, null), try rec.errorCode(id));
    }
}
