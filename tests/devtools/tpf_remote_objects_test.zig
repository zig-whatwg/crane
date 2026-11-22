//! What the framework suites' runners read off Runtime's remote objects and
//! do in their isolated worlds (lane tpf, the CDP test pass: Vue's Puppeteer
//! e2e suite failed on both).
//!
//! - A DOM object's RemoteObject carries Chrome's subtype and description:
//!   Puppeteer (createJSHandle) and Playwright make an ELEMENT handle only for
//!   subtype "node" - Crane answered `document` as {className: "Document",
//!   description: "Document"} with no subtype, so `page.$eval` threw
//!   "document.$eval is not a function". Chrome 157's answer for the same
//!   evaluation (tmp/plans/cdp1-evidence/vue-e2e.protocol.log.gz):
//!   {"type":"object","subtype":"node","className":"HTMLDocument",
//!   "description":"#document"}.
//! - In an isolated world (Page.createIsolatedWorld, the runners' utility
//!   world), a node's attributes read and write: they threw "Illegal
//!   invocation" (a world's node wrapper is no node-anchor wrapper), so
//!   Puppeteer's addScriptTag (`script.type = ...`) and every locator read
//!   failed.
//! - A file: document has localStorage and sessionStorage, one localStorage
//!   for every file: document (Chrome 157, measured; Vue's todomvc example
//!   page reads localStorage at mount): Crane threw SecurityError (the
//!   spec's opaque-origin path; global_settings.storageKeyOf says why the
//!   browsers win).

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

/// Runtime.evaluate of `expression` on `session` (in `context` when not 0),
/// its result RemoteObject.
fn evaluate(rec: *replay.Recorder, session: []const u8, expression: []const u8, context: i64) !std.json.Value {
    return evaluateWith(rec, session, expression, context, false);
}

/// `evaluate`, awaiting a promise result (awaitPromise) when `await_promise`.
fn evaluateWith(rec: *replay.Recorder, session: []const u8, expression: []const u8, context: i64, await_promise: bool) !std.json.Value {
    var buffer: [512]u8 = undefined;
    const awaiting = if (await_promise) ",\"awaitPromise\":true" else "";
    const params = if (context != 0)
        try std.fmt.bufPrint(&buffer, "{{\"expression\":\"{s}\",\"contextId\":{d}{s}}}", .{ expression, context, awaiting })
    else
        try std.fmt.bufPrint(&buffer, "{{\"expression\":\"{s}\"{s}}}", .{ expression, awaiting });
    const id = try rec.send("Runtime.evaluate", params, session);
    if (try rec.errorCode(id)) |code| {
        std.debug.print("Runtime.evaluate {s}: error {d}\n", .{ expression, code });
        return error.EvaluateFailed;
    }
    const r = try rec.result(id);
    if (cdp.at(r, "exceptionDetails") != null) {
        std.debug.print("Runtime.evaluate {s}: threw {s}\n", .{ expression, cdp.stringAt(r, "result.description") orelse "?" });
        return error.EvaluateThrew;
    }
    return cdp.at(r, "result") orelse error.NoResult;
}

fn expectRemote(remote: std.json.Value, subtype: ?[]const u8, description: []const u8) !void {
    const got_subtype = cdp.stringAt(remote, "subtype");
    if (subtype) |want| {
        try testing.expectEqualStrings(want, got_subtype orelse "(none)");
    } else try testing.expectEqual(@as(?[]const u8, null), got_subtype);
    try testing.expectEqualStrings(description, cdp.stringAt(remote, "description") orelse "(none)");
}

test "DOM objects' remote objects carry Chrome's subtype and description: node, array, error; a plain object none" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const session = try pageSession(allocator, rec);
    defer allocator.free(session);

    try expectRemote(try evaluate(rec, session, "document", 0), "node", "#document");
    _ = try evaluate(rec, session, "document.body || document.documentElement.appendChild(document.createElement('body'))", 0);
    _ = try evaluate(rec, session, "document.body.id = 'b', document.body.className = 'x  y', 0", 0);
    try expectRemote(try evaluate(rec, session, "document.body", 0), "node", "body#b.x.y");
    try expectRemote(try evaluate(rec, session, "document.createTextNode('t')", 0), "node", "#text");
    try testing.expectEqualStrings("array", cdp.stringAt(try evaluate(rec, session, "document.querySelectorAll('body')", 0), "subtype") orelse "(none)");
    try testing.expectEqualStrings("array", cdp.stringAt(try evaluate(rec, session, "document.body.classList", 0), "subtype") orelse "(none)");
    try testing.expectEqualStrings("error", cdp.stringAt(try evaluate(rec, session, "new DOMException('m')", 0), "subtype") orelse "(none)");
    try testing.expectEqual(@as(?[]const u8, null), cdp.stringAt(try evaluate(rec, session, "({a: 1})", 0), "subtype"));
}

test "in an isolated world a node's attributes read and write, and its nodes are subtype node too" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const session = try pageSession(allocator, rec);
    defer allocator.free(session);

    const tree = try rec.result(try rec.send("Page.getFrameTree", "{}", session));
    const frame_id = cdp.stringAt(tree, "frameTree.frame.id") orelse return error.NoFrame;
    var buffer: [256]u8 = undefined;
    const world = try rec.send("Page.createIsolatedWorld", try std.fmt.bufPrint(&buffer, "{{\"frameId\":\"{s}\",\"worldName\":\"__tpf_world__\",\"grantUniveralAccess\":true}}", .{frame_id}), session);
    const context = cdp.at(try rec.result(world), "executionContextId").?.integer;

    // What Puppeteer's addScriptTag does in its utility world.
    const made = try evaluate(rec, session, "(() => { const s = document.createElement('script'); s.type = 'text/javascript'; s.text = '1'; s.id = 'w'; document.head.appendChild(s); return s.type + ' ' + s.id + ' ' + document.getElementById('w').textContent })()", context);
    try testing.expectEqualStrings("text/javascript w 1", cdp.stringAt(made, "value") orelse "(none)");
    try expectRemote(try evaluate(rec, session, "document.getElementById('w')", context), "node", "script#w");
    // The main world sees the same node.
    const seen = try evaluate(rec, session, "document.getElementById('w').type", 0);
    try testing.expectEqualStrings("text/javascript", cdp.stringAt(seen, "value") orelse "(none)");

    // requestAnimationFrame from the world runs, in the same frame as the
    // page's, in handle order - the document's one map of callbacks (Blink's
    // FrameRequestCallbackCollection): it never ran before.
    _ = try evaluate(rec, session, "document.body.dataset.order = '', requestAnimationFrame(() => { document.body.dataset.order += 'm'; })", 0);
    const order = try evaluateWith(rec, session, "new Promise((resolve) => requestAnimationFrame(() => { document.body.dataset.order += 'w'; resolve(document.body.dataset.order); }))", context, true);
    try testing.expectEqualStrings("mw", cdp.stringAt(order, "value") orelse "(none)");
}

/// Page.navigate `session`'s tab to `url` and wait for its load event.
fn navigateAndLoad(rec: *replay.Recorder, session: []const u8, url: []const u8) !void {
    var buffer: [512]u8 = undefined;
    const start = rec.log.items.len;
    const id = try rec.send("Page.navigate", try std.fmt.bufPrint(&buffer, "{{\"url\":\"{s}\"}}", .{url}), session);
    if (cdp.stringAt(try rec.result(id), "errorText")) |why| {
        std.debug.print("Page.navigate {s}: {s}\n", .{ url, why });
        return error.NavigationFailed;
    }
    _ = try rec.awaitEvent("Page.loadEventFired", session, start, &.{});
}

test "a file: document has localStorage and sessionStorage: one localStorage for every file: document, as Chrome's" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "a");
    try tmp.dir.createDirPath(testing.io, "b");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "a/one.html", .data = "<p>one</p>" });
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "b/two.html", .data = "<p>two</p>" });
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", allocator);
    defer allocator.free(base);
    const one = try std.fmt.allocPrint(allocator, "file://{s}/a/one.html", .{base});
    defer allocator.free(one);
    const two = try std.fmt.allocPrint(allocator, "file://{s}/b/two.html", .{base});
    defer allocator.free(two);

    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const session = try pageSession(allocator, rec);
    defer allocator.free(session);
    _ = try rec.result(try rec.send("Page.enable", "{}", session));

    try navigateAndLoad(rec, session, one);
    const first = try evaluate(rec, session, "localStorage.setItem('k', 'from one'), sessionStorage.setItem('s', '1'), localStorage.getItem('k') + ' ' + sessionStorage.getItem('s') + ' ' + self.origin", 0);
    try testing.expectEqualStrings("from one 1 null", cdp.stringAt(first, "value") orelse "(none)");
    // Another file: document, in another directory: the same localStorage.
    try navigateAndLoad(rec, session, two);
    const second = try evaluate(rec, session, "String(localStorage.getItem('k'))", 0);
    try testing.expectEqualStrings("from one", cdp.stringAt(second, "value") orelse "(none)");
}
