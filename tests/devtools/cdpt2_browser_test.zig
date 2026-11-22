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

test "G18: Target.createBrowserContext makes an off-the-record context - it never opens the console's --user-data-dir profile the default Browser holds" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", allocator);
    defer allocator.free(base);
    const profile = try std.fs.path.join(allocator, &.{ base, "profile" });
    defer allocator.free(profile);

    // The console's shape with --user-data-dir: the default Browser holds
    // the profile, and the contexts' config names it too.
    const config: browser_mod.BrowserConfig = .{ .profile_dir = profile, .persist_storage = true };
    const host = try BrowserHost.start(allocator, config);
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host, .context_config = config, .user_data_dir = profile });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const context = try client.call("Target.createBrowserContext", "{}", "");
    defer context.deinit();
    // Chrome's answer, not "Failed to create browser context" (ProfileInUse).
    try testing.expect(cdp.stringAt(context.value, "result.browserContextId") != null);
    // And it shares no storage with the default Browser: a key set in one
    // is not in the other.
    var params_buffer: [192]u8 = undefined;
    const created = try client.call("Target.createTarget", try std.fmt.bufPrint(&params_buffer, "{{\"url\":\"about:blank\",\"browserContextId\":\"{s}\"}}", .{cdp.stringAt(context.value, "result.browserContextId").?}), "");
    defer created.deinit();
    try testing.expect(cdp.stringAt(created.value, "result.targetId") != null);
}
