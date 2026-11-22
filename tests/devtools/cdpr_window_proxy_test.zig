//! Lane cdpr's share of cdpt2's gaps (main, 2026-11-21 9:28 PM ET): a tab's
//! own window - Browser.getWindowForTarget / getWindowBounds /
//! setWindowBounds with Chrome's states (chrome/browser/devtools/protocol/
//! browser_handler.cc), read by the page's screenX/screenY/outerWidth/
//! outerHeight and moved by its moveTo - and a context's proxy -
//! Target.createBrowserContext {proxyServer, proxyBypassList} parsed as
//! Chrome's ProxyRules and ProxyBypassRules, with ProxyList::Fallback past a
//! proxy that cannot be reached.
//!
//! Written in the CDP phase, not run (user directive 2026-11-21 5:48 PM ET:
//! implement now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

/// The existing tab's page session, Page and Runtime enabled, and its main
/// context.
const Page = struct {
    session: []u8,
    target_id: []u8,
    main_context: i64,

    fn deinit(self: *Page, allocator: std.mem.Allocator) void {
        allocator.free(self.session);
        allocator.free(self.target_id);
    }
};

fn attachExisting(fx: *replay.Fixture, allocator: std.mem.Allocator) !Page {
    const rec = &fx.rec;
    const auto = try rec.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":false,\"flatten\":true}", "");
    _ = try rec.result(auto);
    const attached = try rec.awaitEvent("Target.attachedToTarget", "", 0, &.{.{ .path = "params.targetInfo.type", .equals = "page" }});
    const session = try replay.dupeAt(allocator, rec.at(attached), "params.sessionId");
    errdefer allocator.free(session);
    const target_id = try replay.dupeAt(allocator, rec.at(attached), "params.targetInfo.targetId");
    errdefer allocator.free(target_id);
    const start = rec.log.items.len;
    const runtime = try rec.send("Runtime.enable", "{}", session);
    _ = try rec.result(runtime);
    const created = rec.eventIndex("Runtime.executionContextCreated", session, start, &.{.{ .path = "params.context.auxData.isDefault", .equals = "true" }}) orelse return error.NoMainContext;
    return .{ .session = session, .target_id = target_id, .main_context = cdp.at(rec.at(created), "params.context.id").?.integer };
}

fn evaluate(rec: *replay.Recorder, allocator: std.mem.Allocator, page: *const Page, expression: []const u8) ![]u8 {
    var buffer: [512]u8 = undefined;
    const id = try rec.send("Runtime.evaluate", try std.fmt.bufPrint(&buffer, "{{\"expression\":\"{s}\",\"contextId\":{d},\"returnByValue\":true}}", .{ expression, page.main_context }), page.session);
    return replay.dupeAt(allocator, try rec.result(id), "result.value");
}

test "a tab's window: setWindowBounds moves and sizes it, the page's screenX/screenY/outerWidth/outerHeight and innerWidth read it, getWindowForTarget reports it" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    var page = try attachExisting(fx, allocator);
    defer page.deinit(allocator);
    const rec = &fx.rec;

    const window = try rec.send("Browser.getWindowForTarget", "{}", page.session);
    const w = try rec.result(window);
    const window_id = cdp.at(w, "windowId").?.integer;
    try testing.expectEqualStrings("normal", cdp.stringAt(w, "bounds.windowState").?);

    var buffer: [256]u8 = undefined;
    const set = try rec.send("Browser.setWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d},\"bounds\":{{\"left\":10,\"top\":20,\"width\":800,\"height\":600}}}}", .{window_id}), "");
    _ = try rec.result(set);
    const seen = try evaluate(rec, allocator, &page, "[screenX, screenY, outerWidth, outerHeight, innerWidth, innerHeight].join()");
    defer allocator.free(seen);
    try testing.expectEqualStrings("10,20,800,600,800,600", seen);

    const again = try rec.send("Browser.getWindowForTarget", "{}", page.session);
    const g = try rec.result(again);
    try testing.expectEqual(window_id, cdp.at(g, "windowId").?.integer);
    try testing.expectEqual(@as(i64, 10), cdp.at(g, "bounds.left").?.integer);
    try testing.expectEqual(@as(i64, 20), cdp.at(g, "bounds.top").?.integer);
    try testing.expectEqual(@as(i64, 800), cdp.at(g, "bounds.width").?.integer);
    try testing.expectEqual(@as(i64, 600), cdp.at(g, "bounds.height").?.integer);

    // The page moves its window: the tab's rect, which the host reads.
    const moved = try evaluate(rec, allocator, &page, "(moveTo(5, 6), resizeBy(-100, 0), [screenX, screenY, outerWidth].join())");
    defer allocator.free(moved);
    try testing.expectEqualStrings("5,6,700", moved);
    const bounds = try rec.send("Browser.getWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d}}}", .{window_id}), "");
    const b = try rec.result(bounds);
    try testing.expectEqual(@as(i64, 5), cdp.at(b, "bounds.left").?.integer);
    try testing.expectEqual(@as(i64, 700), cdp.at(b, "bounds.width").?.integer);
}

test "a tab's window states (browser_handler.cc): maximized takes the screen's available area and refuses new bounds until normal, which restores the rect; fullscreen the whole screen; minimized keeps the rect" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    var page = try attachExisting(fx, allocator);
    defer page.deinit(allocator);
    const rec = &fx.rec;
    const window = try rec.send("Browser.getWindowForTarget", "{}", page.session);
    const window_id = cdp.at(try rec.result(window), "windowId").?.integer;
    var buffer: [256]u8 = undefined;

    _ = try rec.result(try rec.send("Browser.setWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d},\"bounds\":{{\"left\":10,\"top\":20,\"width\":800,\"height\":600}}}}", .{window_id}), ""));
    _ = try rec.result(try rec.send("Browser.setWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d},\"bounds\":{{\"windowState\":\"maximized\"}}}}", .{window_id}), ""));
    const screen = try evaluate(rec, allocator, &page, "[0, 0, screen.availWidth, screen.availHeight].join()");
    defer allocator.free(screen);
    const maximized = try evaluate(rec, allocator, &page, "[screenX, screenY, outerWidth, outerHeight].join()");
    defer allocator.free(maximized);
    try testing.expectEqualStrings(screen, maximized);
    const state = try rec.send("Browser.getWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d}}}", .{window_id}), "");
    try testing.expectEqualStrings("maximized", cdp.stringAt(try rec.result(state), "bounds.windowState").?);

    // New bounds for a maximized window: Chrome's refusal.
    const refused = try rec.send("Browser.setWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d},\"bounds\":{{\"width\":500}}}}", .{window_id}), "");
    const r = rec.at(try rec.awaitResponse(refused));
    try testing.expectEqualStrings("To resize minimized/maximized/fullscreen window, restore it to normal state first.", cdp.stringAt(r, "error.message").?);
    // A state with bounds: refused before anything changes.
    const mixed = try rec.send("Browser.setWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d},\"bounds\":{{\"windowState\":\"minimized\",\"width\":500}}}}", .{window_id}), "");
    try testing.expectEqual(@as(?i64, -32602), try rec.errorCode(mixed));

    // Normal again: the rect it had.
    _ = try rec.result(try rec.send("Browser.setWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d},\"bounds\":{{\"windowState\":\"normal\"}}}}", .{window_id}), ""));
    const restored = try evaluate(rec, allocator, &page, "[screenX, screenY, outerWidth, outerHeight].join()");
    defer allocator.free(restored);
    try testing.expectEqualStrings("10,20,800,600", restored);

    // Fullscreen: the whole screen; minimized from normal keeps the rect.
    _ = try rec.result(try rec.send("Browser.setWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d},\"bounds\":{{\"windowState\":\"fullscreen\"}}}}", .{window_id}), ""));
    const whole = try evaluate(rec, allocator, &page, "String([screen.width, screen.height].join() === [screenX, screenY, outerWidth, outerHeight].slice(2).join() && screenX === 0)");
    defer allocator.free(whole);
    try testing.expectEqualStrings("true", whole);
    _ = try rec.result(try rec.send("Browser.setWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d},\"bounds\":{{\"windowState\":\"normal\"}}}}", .{window_id}), ""));
    _ = try rec.result(try rec.send("Browser.setWindowBounds", try std.fmt.bufPrint(&buffer, "{{\"windowId\":{d},\"bounds\":{{\"windowState\":\"minimized\"}}}}", .{window_id}), ""));
    const minimized = try evaluate(rec, allocator, &page, "[screenX, screenY, outerWidth, outerHeight].join()");
    defer allocator.free(minimized);
    try testing.expectEqualStrings("10,20,800,600", minimized);
}

test "Target.createBrowserContext {proxyServer, proxyBypassList}: the context's requests go through Chrome's rules, past a proxy that refuses the connection to the next (ProxyList::Fallback)" {
    var gpa: replay.LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    // The loopback site serves as the proxy (absolute-form requests).
    const proxy = try replay.Site.start(allocator);
    defer proxy.stop();
    const fx = try replay.Fixture.start(allocator);
    defer fx.stop();
    const rec = &fx.rec;
    const auto = try rec.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true}", "");
    _ = try rec.result(auto);

    // Port 1 refuses: the list's second proxy takes the request.
    var buffer: [512]u8 = undefined;
    const made = try rec.send("Target.createBrowserContext", try std.fmt.bufPrint(&buffer, "{{\"disposeOnDetach\":true,\"proxyServer\":\"http=127.0.0.1:1,127.0.0.1:{d}\",\"proxyBypassList\":\"*.direct.test\"}}", .{proxy.listener.port()}), "");
    const context_id = try replay.dupeAt(allocator, try rec.result(made), "browserContextId");
    defer allocator.free(context_id);
    const start = rec.log.items.len;
    const created = try rec.send("Target.createTarget", try std.fmt.bufPrint(&buffer, "{{\"url\":\"about:blank\",\"browserContextId\":\"{s}\"}}", .{context_id}), "");
    const target_id = try replay.dupeAt(allocator, try rec.result(created), "targetId");
    defer allocator.free(target_id);
    const attached = try rec.awaitEvent("Target.attachedToTarget", "", start, &.{.{ .path = "params.targetInfo.targetId", .equals = target_id }});
    const session = try replay.dupeAt(allocator, rec.at(attached), "params.sessionId");
    defer allocator.free(session);
    for ([_][]const u8{ "Page.enable", "Page.setLifecycleEventsEnabled", "Runtime.enable", "Runtime.runIfWaitingForDebugger" }) |method| {
        _ = try rec.result(try rec.send(method, if (std.mem.eql(u8, method, "Page.setLifecycleEventsEnabled")) "{\"enabled\":true}" else "{}", session));
    }

    // A host no resolver knows: only the proxy can answer it.
    const nav_start = rec.log.items.len;
    const navigate = try rec.send("Page.navigate", try std.fmt.bufPrint(&buffer, "{{\"url\":\"http://proxied.test/\",\"frameId\":\"{s}\"}}", .{target_id}), session);
    const n = try rec.result(navigate);
    try testing.expect(cdp.at(n, "errorText") == null);
    _ = try rec.awaitEvent("Page.lifecycleEvent", session, nav_start, &.{
        .{ .path = "params.name", .equals = "load" },
        .{ .path = "params.frameId", .equals = target_id },
    });
    try testing.expect(proxy.proxied.load(.acquire) >= 1);
    const created_context = rec.eventIndex("Runtime.executionContextCreated", session, nav_start, &.{.{ .path = "params.context.auxData.isDefault", .equals = "true" }}) orelse return error.NoContext;
    const check = try rec.send("Runtime.evaluate", try std.fmt.bufPrint(&buffer, "{{\"expression\":\"document.getElementById('x').textContent\",\"contextId\":{d},\"returnByValue\":true}}", .{cdp.at(rec.at(created_context), "params.context.id").?.integer}), session);
    try testing.expectEqualStrings("hello", cdp.stringAt(try rec.result(check), "result.value").?);
}
