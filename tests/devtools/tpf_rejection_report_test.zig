//! An unhandled rejection over CDP as Chrome reports it (lane tpf): its
//! Runtime.exceptionThrown carries the rejection's reason as `exception`
//! and the stack, script and URL of the call that rejected - Blink's
//! V8Initializer::PromiseRejectHandler captures that SourceLocation when V8
//! reports the rejection, and ThreadDebugger::PromiseRejected hands it to
//! the inspector. Crane sent only {text: "Uncaught (in promise)"}, so
//! Playwright's and Puppeteer's pageerror read "Uncaught (in promise)" where
//! Chrome's name the reason (lane tpf's probe: Chrome for Testing 157 sends
//! exception {type: "string", value: <reason>} and the reject call's stack).

const std = @import("std");
const testing = std.testing;
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

/// A page session on the fixture's tab, Runtime enabled; its id, OWNED.
fn pageSession(allocator: std.mem.Allocator, rec: *replay.Recorder) ![]u8 {
    const auto = try rec.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":false,\"flatten\":true}", "");
    _ = try rec.result(auto);
    const attached = try rec.awaitEvent("Target.attachedToTarget", "", 0, &.{.{ .path = "params.targetInfo.type", .equals = "page" }});
    const session = try replay.dupeAt(allocator, rec.at(attached), "params.sessionId");
    errdefer allocator.free(session);
    _ = try rec.result(try rec.send("Runtime.enable", "{}", session));
    return session;
}

/// The exceptionThrown's top call frame.
fn topFrame(details: std.json.Value) ?std.json.Value {
    const frames = cdp.at(details, "stackTrace.callFrames") orelse return null;
    if (frames != .array or frames.array.items.len == 0) return null;
    return frames.array.items[0];
}

test "an unhandled rejection's Runtime.exceptionThrown names its reason and the stack, script and URL of the call that rejected, as Chrome's" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const session = try pageSession(allocator, rec);
    defer allocator.free(session);

    const start = rec.log.items.len;
    _ = try rec.result(try rec.send("Runtime.evaluate",
        \\{"expression":"function rejectHere() { Promise.reject('the reason'); }\nrejectHere();\n//# sourceURL=reject-site.js"}
    , session));
    const thrown = try rec.awaitEvent("Runtime.exceptionThrown", session, start, &.{});
    const details = cdp.at(rec.at(thrown), "params.exceptionDetails") orelse return error.NoDetails;
    try testing.expectEqualStrings("Uncaught (in promise)", cdp.stringAt(details, "text") orelse "(none)");
    // The reason itself, wrapped: Playwright's pageerror message.
    try testing.expectEqualStrings("string", cdp.stringAt(details, "exception.type") orelse "(none)");
    try testing.expectEqualStrings("the reason", cdp.stringAt(details, "exception.value") orelse "(none)");
    // Where it was rejected: the stack at the reject call, its script and URL.
    const top = topFrame(details) orelse return error.NoStackTrace;
    try testing.expectEqualStrings("rejectHere", cdp.stringAt(top, "functionName") orelse "(none)");
    try testing.expectEqualStrings("reject-site.js", cdp.stringAt(top, "url") orelse "(none)");
    try testing.expectEqualStrings("reject-site.js", cdp.stringAt(details, "url") orelse "(none)");
    const script_id: []const u8 = cdp.stringAt(details, "scriptId") orelse "";
    try testing.expect(script_id.len > 0);
}

test "an unhandled rejection with an Error: its exception is the Error, its stack the Error's own" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const session = try pageSession(allocator, rec);
    defer allocator.free(session);

    const start = rec.log.items.len;
    _ = try rec.result(try rec.send("Runtime.evaluate",
        \\{"expression":"function makeError() { return new Error('boom'); }\nfunction rejectLater(e) { Promise.reject(e); }\nrejectLater(makeError());\n//# sourceURL=reject-error.js"}
    , session));
    const thrown = try rec.awaitEvent("Runtime.exceptionThrown", session, start, &.{});
    const details = cdp.at(rec.at(thrown), "params.exceptionDetails") orelse return error.NoDetails;
    try testing.expectEqualStrings("Uncaught (in promise)", cdp.stringAt(details, "text") orelse "(none)");
    try testing.expectEqualStrings("Error", cdp.stringAt(details, "exception.className") orelse "(none)");
    try testing.expect(std.mem.startsWith(u8, cdp.stringAt(details, "exception.description") orelse "", "Error: boom"));
    // An Error's stack is where it was made (V8's Exception::GetStackTrace).
    const top = topFrame(details) orelse return error.NoStackTrace;
    try testing.expectEqualStrings("makeError", cdp.stringAt(top, "functionName") orelse "(none)");
}

test "a rejection's captured stack goes with its record: handled in the same task, handled after its report (exceptionRevoked), left at the end - nothing leaks" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const session = try pageSession(allocator, rec);
    defer allocator.free(session);

    const start = rec.log.items.len;
    // Handled before the microtask checkpoint: never reported, its stack
    // released at "handle".
    _ = try rec.result(try rec.send("Runtime.evaluate",
        \\{"expression":"Promise.reject('handled at once').catch(() => {}); 'ok'"}
    , session));
    // Reported, then handled: Runtime.exceptionRevoked.
    _ = try rec.result(try rec.send("Runtime.evaluate",
        \\{"expression":"globalThis.later = Promise.reject('handled later'); 'ok'"}
    , session));
    const thrown = try rec.awaitEvent("Runtime.exceptionThrown", session, start, &.{});
    try testing.expectEqualStrings("handled later", cdp.stringAt(rec.at(thrown), "params.exceptionDetails.exception.value") orelse "(none)");
    _ = try rec.result(try rec.send("Runtime.evaluate",
        \\{"expression":"later.catch(() => {}); 'ok'"}
    , session));
    _ = try rec.awaitEvent("Runtime.exceptionRevoked", session, start, &.{});
    // Only the one was reported.
    try testing.expectEqual(@as(usize, 1), rec.countEvents("Runtime.exceptionThrown", session, start, &.{}));
    // And one still waiting for its checkpoint when the Browser ends.
    _ = try rec.result(try rec.send("Runtime.evaluate",
        \\{"expression":"Promise.reject('left'); 'ok'"}
    , session));
}

test "a page's own script's unhandled rejections, during its load: each Runtime.exceptionThrown names its reason - one rejected in a function, one thrown in a promise reaction" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const site = try replay.Site.start(allocator);
    defer site.stop();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const session = try pageSession(allocator, rec);
    defer allocator.free(session);
    _ = try rec.result(try rec.send("Page.enable", "{}", session));

    var url_buffer: [96]u8 = undefined;
    var params_buffer: [160]u8 = undefined;
    const start = rec.log.items.len;
    _ = try rec.result(try rec.send("Page.navigate", try std.fmt.bufPrint(&params_buffer, "{{\"url\":\"{s}\"}}", .{try site.url(&url_buffer, "/reject.html")}), session));
    const first = try rec.awaitEvent("Runtime.exceptionThrown", session, start, &.{});
    const second = try rec.awaitEvent("Runtime.exceptionThrown", session, first + 1, &.{});
    const a = cdp.at(rec.at(first), "params.exceptionDetails") orelse return error.NoDetails;
    const b = cdp.at(rec.at(second), "params.exceptionDetails") orelse return error.NoDetails;
    try testing.expectEqualStrings("from page", cdp.stringAt(a, "exception.value") orelse "(none)");
    try testing.expectEqualStrings("rejectInPage", cdp.stringAt(topFrame(a) orelse return error.NoStackTrace, "functionName") orelse "(none)");
    try testing.expectEqualStrings("from reaction", cdp.stringAt(b, "exception.value") orelse "(none)");
}
