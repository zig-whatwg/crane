//! The Browser domain and the server's life (lane cdpt2; CDP part 1 gaps 5-7):
//! Browser.getVersion's jsVersion and /json/version's V8-Version are the
//! engine's own version (engine.engineVersion), never its name.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const engine = @import("engine");
const cdp = @import("cdp_client.zig");

const BrowserHost = browser_mod.BrowserHost;
const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

fn connectBrowser(allocator: std.mem.Allocator, server: *devtools.Server) !*cdp.Client {
    var path_buffer: [96]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buffer, "/devtools/browser/{s}", .{server.browser_id.slice()});
    const client = try cdp.Client.openWebSocket(allocator, server.port, path, null);
    if (client.upgrade_status != 101) return error.UpgradeRefused;
    return client;
}

test "Browser.getVersion's jsVersion and /json/version's V8-Version are the engine's own version" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const expected = engine.engineVersion() catch "";

    const client = try connectBrowser(allocator, server);
    defer client.close();
    const version = try client.call("Browser.getVersion", "{}", "");
    defer version.deinit();
    try testing.expectEqualStrings(expected, cdp.stringAt(version.value, "result.jsVersion").?);
    try testing.expect(!std.mem.eql(u8, engine.name, cdp.stringAt(version.value, "result.jsVersion").?));

    var http = try cdp.httpGet(allocator, server.port, "/json/version", &.{});
    defer http.deinit();
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, http.body, .{});
    defer parsed.deinit();
    try testing.expectEqualStrings(expected, parsed.value.object.get("V8-Version").?.string);
}
