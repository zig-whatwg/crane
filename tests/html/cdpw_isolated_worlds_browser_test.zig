//! A Browser's isolated worlds (src/browser/isolated_worlds.zig over the
//! engine's world realms, engine section 4.2a): what CDP's
//! Page.createIsolatedWorld and addScriptToEvaluateOnNewDocument {worldName}
//! stand on.
//!
//! - A world per (navigable, name), Blink's InspectorPageAgent::
//!   EnsureDOMWrapperWorld: the same request answers the same realm, another
//!   name another world.
//! - A navigation ends the old document's world realms; the world (its id)
//!   is kept for the navigable, and the next request makes its realm for the
//!   new document.
//! - A WindowProxy per (navigable, world): a frame's world WindowProxy that
//!   world script holds reaches the frame's new Window after the frame
//!   navigates, as the main world's does.
//! - Frames: code of a world reaching a frame's objects gets the frame's
//!   realm in the same world, made on first need.
//!
//! Written for the CDP test pass (the user's directive of 2026-11-21 5:48 PM
//! ET: implement now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const runtime = @import("runtime");

const isolated_worlds = browser_mod.isolated_worlds;

fn makeBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    return browser_mod.Browser.init(allocator, .{ .snapshot_path = "" });
}

const Reports = struct {
    count: usize = 0,
    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }
};

fn expect(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    if (!std.mem.eql(u8, expected, got)) std.debug.print("{s}\n  -> {s}\n", .{ source, got });
    try testing.expectEqualStrings(expected, got);
}

const navigable: u64 = 1;

test "createIsolatedWorld answers one realm per (navigable, name), and another name another world" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;
    const page = ctx.realm orelse return error.NoRealm;

    const utility = try isolated_worlds.createIsolatedWorld(page, navigable, "__playwright_utility_world__", true);
    try testing.expectEqual(utility, try isolated_worlds.createIsolatedWorld(page, navigable, "__playwright_utility_world__", true));
    const other = try isolated_worlds.createIsolatedWorld(page, navigable, "__puppeteer_utility_world__", false);
    try testing.expect(other != utility);
    try testing.expectEqual(page, engine.mainRealmOf(utility));
    try testing.expect(engine.worldOf(utility) != engine.worldOf(other));
    try testing.expectEqualStrings("__playwright_utility_world__", engine.worldInfoOf(utility).?.name);
    try testing.expect(engine.worldInfoOf(utility).?.universal_access);
    var out: [4]runtime.Context = undefined;
    try testing.expectEqual(@as(usize, 2), isolated_worlds.realmsOf(page, &out));
    // Two worlds and the page, one DOM.
    try expect(page, "document.title = 'shared'; 'ok'", "ok");
    try expect(utility, "document.title", "shared");
    try expect(other, "document.title", "shared");
}

test "a navigation ends the document's world realms and keeps the world for the navigable" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const before = (browser.current_context orelse return error.NoContext).realm orelse return error.NoRealm;
    const first = try isolated_worlds.createIsolatedWorld(before, navigable, "__utility__", false);
    const world = engine.worldOf(first);
    try expect(first, "globalThis.fromOldDocument = 1; 'ok'", "ok");

    try browser.navigate("about:blank", .window);
    _ = try browser.runEventLoopBlocking(50);
    const after = (browser.current_context orelse return error.NoContext).realm orelse return error.NoRealm;
    try testing.expect(after != before);
    // No world realm for the new document until one is asked for.
    var out: [2]runtime.Context = undefined;
    try testing.expectEqual(@as(usize, 0), isolated_worlds.realmsOf(after, &out));
    // The same world (id) for the navigable, a new realm for the new document.
    const second = try isolated_worlds.createIsolatedWorld(after, navigable, "__utility__", false);
    try testing.expectEqual(world, engine.worldOf(second));
    try expect(second, "typeof fromOldDocument", "undefined");
}

test "a frame's world WindowProxy held by world script reaches the frame's new Window after it navigates" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;
    try ctx.loadHTML(
        \\<!DOCTYPE html><html><body><iframe srcdoc="<p id=one>one</p>"></iframe></body></html>
    , .{ .base_url = "http://localhost/worlds.html" });
    _ = try browser.runEventLoopBlocking(100);
    const page = ctx.realm orelse return error.NoRealm;
    const utility = try isolated_worlds.createIsolatedWorld(page, navigable, "__utility__", true);

    // The frame reached from the world: its realm in the world, made on
    // first need - its own global, the frame's DOM.
    try expect(utility,
        \\globalThis.kept = document.querySelector('iframe').contentWindow;
        \\kept.worldMark = 'world';
        \\String(kept.document.getElementById('one').textContent) + ':' + String(kept === document.querySelector('iframe').contentWindow)
    , "one:true");
    // The page's view of the frame has no world expando.
    try expect(page, "String(document.querySelector('iframe').contentWindow.worldMark)", "undefined");

    // The frame navigates; the world's proxy goes on to its new Window.
    try expect(page, "document.querySelector('iframe').srcdoc = '<p id=two>two</p>'; 'ok'", "ok");
    _ = try browser.runEventLoopBlocking(100);
    try expect(utility,
        \\String(kept === document.querySelector('iframe').contentWindow) + ':' + String(kept.document.getElementById('two') !== null)
    , "true:true");
}
