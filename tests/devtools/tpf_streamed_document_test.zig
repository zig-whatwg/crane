//! A document whose body is still arriving when it commits - React's SSR
//! and Next.js stream their HTML - reports its body's end over CDP, as
//! Chrome does (lane tpf, React's compiler playground: every test's
//! page.goto(waitUntil: 'networkidle') timed out, Playwright counting the
//! Document request as in flight forever - Crane sent no
//! Network.loadingFinished for it).

const std = @import("std");
const testing = std.testing;
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

test "a streamed document's Network.loadingFinished comes when its body ends, after its commit: the Document request ends" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const site = try replay.Site.start(allocator);
    defer site.stop();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;

    const auto = try rec.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":false,\"flatten\":true}", "");
    _ = try rec.result(auto);
    const attached = try rec.awaitEvent("Target.attachedToTarget", "", 0, &.{.{ .path = "params.targetInfo.type", .equals = "page" }});
    const session = try replay.dupeAt(allocator, rec.at(attached), "params.sessionId");
    defer allocator.free(session);
    _ = try rec.result(try rec.send("Page.enable", "{}", session));
    _ = try rec.result(try rec.send("Network.enable", "{}", session));

    var url_buffer: [96]u8 = undefined;
    var params_buffer: [160]u8 = undefined;
    const url = try site.url(&url_buffer, "/streamed.html");
    const start = rec.log.items.len;
    const navigate = try rec.send("Page.navigate", try std.fmt.bufPrint(&params_buffer, "{{\"url\":\"{s}\"}}", .{url}), session);
    const loader = try replay.dupeAt(allocator, try rec.result(navigate), "loaderId");
    defer allocator.free(loader);

    // The body ends before the parser does, so before the load event (as
    // Chrome orders them): read up to the load, then look.
    const loaded = try rec.awaitEvent("Page.loadEventFired", session, start, &.{});
    // The Document request (Chrome names it by its loaderId) commits at its
    // response's head, and its last chunk comes 300 ms later.
    const sent = rec.eventIndex("Network.requestWillBeSent", session, start, &.{
        .{ .path = "params.requestId", .equals = loader },
        .{ .path = "params.type", .equals = "Document" },
    }) orelse return error.NoDocumentRequest;
    const finished = rec.eventIndex("Network.loadingFinished", session, start, &.{.{ .path = "params.requestId", .equals = loader }}) orelse return error.DocumentRequestNeverEnded;
    try testing.expect(finished < loaded);
    const committed = rec.eventIndex("Page.frameNavigated", session, start, &.{.{ .path = "params.frame.loaderId", .equals = loader }}) orelse return error.NotCommitted;
    try testing.expect(sent < committed);
    try testing.expect(committed < finished);
    // Its body's bytes came with it, the last chunk's after the commit.
    try testing.expect(rec.eventIndex("Network.dataReceived", session, committed, &.{.{ .path = "params.requestId", .equals = loader }}) != null);
    try testing.expectEqual(@as(?usize, null), rec.eventIndex("Network.loadingFailed", session, start, &.{.{ .path = "params.requestId", .equals = loader }}));
}
