//! console.timeStamp, console.profile and console.profileEnd - no standard
//! defines them, all three browsers ship them
//! (specs/supplementary/console-webcompat.idl) - over CDP as Chrome's: the
//! namespace's own writable operations (Angular's DevTools performance
//! integration spies on console.timeStamp: 10 of its acceptance tests
//! failed on "timeStamp() method does not exist"). None is a console
//! message: Chrome for Testing 157 sends no Runtime.consoleAPICalled for any
//! of the three, and with Profiler enabled profile/profileEnd are
//! Profiler.consoleProfileStarted/Finished (lane tpf's probe, 2:40 AM ET) -
//! V8's console hands them to the profiler agent (V8Console::Profile).

const std = @import("std");
const testing = std.testing;
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

test "console.timeStamp, profile and profileEnd are console's writable operations; none is a console message, and profile/profileEnd start and finish a console profile, as Chrome's" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;

    const auto = try rec.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":false,\"flatten\":true}", "");
    _ = try rec.result(auto);
    const attached = try rec.awaitEvent("Target.attachedToTarget", "", 0, &.{.{ .path = "params.targetInfo.type", .equals = "page" }});
    const session = try replay.dupeAt(allocator, rec.at(attached), "params.sessionId");
    defer allocator.free(session);
    _ = try rec.result(try rec.send("Runtime.enable", "{}", session));
    _ = try rec.result(try rec.send("Profiler.enable", "{}", session));

    const start = rec.log.items.len;
    const id = try rec.send("Runtime.evaluate",
        \\{"expression":"['timeStamp', 'profile', 'profileEnd'].map((m) => { const d = Object.getOwnPropertyDescriptor(console, m); return typeof d.value + ':' + d.writable + d.enumerable + d.configurable; }).join() + ' ' + String(console.timeStamp('t', 0, 1, 'track', 'group', 'primary')) + String(console.profile('p')) + String(console.profileEnd('p')) + String(console.log('after'))","returnByValue":true}
    , session);
    const r = try rec.result(id);
    try testing.expect(cdp.at(r, "exceptionDetails") == null);
    try testing.expectEqualStrings("function:truetruetrue,function:truetruetrue,function:truetruetrue undefinedundefinedundefinedundefined", cdp.stringAt(r, "result.value") orelse "(none)");

    // The console.log after them is the one console message, and it comes
    // after the profile's start and finish.
    const after = try rec.awaitEvent("Runtime.consoleAPICalled", session, start, &.{.{ .path = "params.type", .equals = "log" }});
    try testing.expectEqual(@as(usize, 1), rec.countEvents("Runtime.consoleAPICalled", session, start, &.{}));
    const started = rec.eventIndex("Profiler.consoleProfileStarted", session, start, &.{.{ .path = "params.title", .equals = "p" }}) orelse return error.ProfileNotStarted;
    const finished = rec.eventIndex("Profiler.consoleProfileFinished", session, start, &.{.{ .path = "params.title", .equals = "p" }}) orelse return error.ProfileNotFinished;
    try testing.expect(started < finished);
    try testing.expect(finished < after);
}
