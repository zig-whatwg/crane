//! An isolated world's timers (engine section 4.2a; src/browser/
//! isolated_worlds.zig): they are its Window's - one map of active timers,
//! whatever world calls, as Blink's DOMTimerCoordinator is the window's - and
//! they run IN the world that set them: a string TimerHandler is compiled in
//! the world's realm, and a callback's this is the world's WindowProxy
//! (Blink's ScheduledAction keeps the caller's ScriptState). A world realm's
//! end takes its own timers, and only its own.
//!
//! Written for the CDP test pass (the user's directive of 2026-11-21 5:48 PM
//! ET: implement now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const runtime = @import("runtime");

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

test "a world's string TimerHandler compiles and runs in the world, and its callbacks see the world's window" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;
    const page = ctx.realm orelse return error.NoRealm;
    const world = try browser_mod.isolated_worlds.createIsolatedWorld(page, 1, "__timers__", false);

    try expect(page, "globalThis.marker = 'page'; 'ok'", "ok");
    try expect(world,
        \\globalThis.marker = 'world';
        \\setTimeout("globalThis.fromString = marker + ':' + String(this === globalThis)", 0);
        \\setTimeout(function () { globalThis.fromFunction = String(this === window) + ':' + marker; }, 0);
        \\'ok'
    , "ok");
    _ = try browser.runEventLoopBlocking(100);
    // Compiled and run in the world: the world's global, the world's marker.
    try expect(world, "String(globalThis.fromString) + ' ' + String(globalThis.fromFunction)", "world:true true:world");
    // Nothing of it reached the page's global.
    try expect(page, "typeof fromString + ' ' + typeof fromFunction + ' ' + marker", "undefined undefined page");
}

test "a world's timers are its Window's: one map of ids, cleared from either world" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;
    const page = ctx.realm orelse return error.NoRealm;
    const world = try browser_mod.isolated_worlds.createIsolatedWorld(page, 1, "__timers__", false);

    // Ids from one map: the world's and the page's never collide.
    try expect(world, "globalThis.worldId = setTimeout(() => { globalThis.ran = true; }, 0); String(worldId > 0)", "true");
    try expect(page, "globalThis.pageId = setTimeout(() => {}, 0); 'ok'", "ok");
    var reports: Reports = .{};
    const world_id = blk: {
        const text = try engine.evaluateClassicScriptToString(world, .{ .utf8 = "String(worldId)" }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
        defer testing.allocator.free(text);
        break :blk try std.fmt.parseInt(i32, text, 10);
    };
    var buffer: [96]u8 = undefined;
    const differs = try std.fmt.bufPrint(&buffer, "String(pageId !== {d})", .{world_id});
    try expect(page, differs, "true");
    // The page's clearTimeout clears the world's timer: the Window's map.
    const clear = try std.fmt.bufPrint(&buffer, "clearTimeout({d}); 'ok'", .{world_id});
    try expect(page, clear, "ok");
    _ = try browser.runEventLoopBlocking(100);
    try expect(world, "String(globalThis.ran === true)", "false");
}

test "a world realm's end on navigation takes its timers and leaves the new page's" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;
    const page = ctx.realm orelse return error.NoRealm;
    const world = try browser_mod.isolated_worlds.createIsolatedWorld(page, 1, "__timers__", false);

    try expect(world, "setTimeout(() => {}, 100000); setInterval(() => {}, 100000); 'ok'", "ok");
    // Navigating ends the old realm and its world realms (Blink ClearForNavigation),
    // cancelling the old world's timers cleanly while the new page's timers run.
    try ctx.loadHTML("<!doctype html><body>next</body>", .{ .base_url = "about:blank" });
    const next_page = ctx.realm orelse return error.NoRealm;
    try expect(next_page, "globalThis.pageRan = false; setTimeout(() => { globalThis.pageRan = true; }, 0); 'ok'", "ok");
    _ = try browser.runEventLoopBlocking(100);
    try expect(next_page, "String(pageRan)", "true");
}
