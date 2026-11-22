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
    // And it runs: a page opens in it.
    var params_buffer: [192]u8 = undefined;
    const created = try client.call("Target.createTarget", try std.fmt.bufPrint(&params_buffer, "{{\"url\":\"about:blank\",\"browserContextId\":\"{s}\"}}", .{cdp.stringAt(context.value, "result.browserContextId").?}), "");
    defer created.deinit();
    try testing.expect(cdp.stringAt(created.value, "result.targetId") != null);
}

/// A page session on `host`'s one tab, on a fresh connection to `server`.
fn attachPage(allocator: std.mem.Allocator, server: *devtools.Server) !struct { client: *cdp.Client, session: []u8 } {
    const client = try connectBrowser(allocator, server);
    errdefer client.close();
    const targets = try client.call("Target.getTargets", "{}", "");
    defer targets.deinit();
    const infos = cdp.at(targets.value, "result.targetInfos").?.array.items;
    if (infos.len == 0) return error.NoTarget;
    var params_buffer: [128]u8 = undefined;
    const attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buffer, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{cdp.stringAt(infos[infos.len - 1], "targetId").?}), "");
    defer attached.deinit();
    return .{ .client = client, .session = try allocator.dupe(u8, cdp.stringAt(attached.value, "result.sessionId").?) };
}

test "gap 6: stopping the server while the page sits in a dialog does not block - the dialog is dismissed, and the Browser runs on" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const tab = try host.createTab(.{});
    const loaded = try host.navigate(allocator, tab, "data:text/html,<script>window.answered='none'</script>", .{ .wait = .complete, .timeout_ms = 10_000 });
    allocator.free(loaded);
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    const page = try attachPage(allocator, server);
    defer allocator.free(page.session);
    const enabled = try page.client.call("Page.enable", "{}", page.session);
    enabled.deinit();
    // A confirm() a moment from now: the Browser thread waits in it.
    const queued = try page.client.call("Runtime.evaluate", "{\"expression\":\"setTimeout(() => { window.answered = String(confirm('stay?')); }, 10); 0\"}", page.session);
    queued.deinit();
    const opening = try page.client.waitEvent("Page.javascriptDialogOpening");
    opening.deinit();
    page.client.close();
    // Returns: the dialog is dismissed (Chrome's PageHandler::Disable answers
    // a pending dialog false), then the remote end uninstalls.
    server.stop();
    const answered = try host.evaluate(allocator, tab, "window.answered", .{}, 10_000);
    defer answered.deinit(allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"false\"}", answered.json);
}

test "gap 6: stopping the server while the debugger has the page paused does not block - the detach resumes it" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const tab = try host.createTab(.{});
    const loaded = try host.navigate(allocator, tab, "data:text/html,<script>window.after='no'</script>", .{ .wait = .complete, .timeout_ms = 10_000 });
    allocator.free(loaded);
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    const page = try attachPage(allocator, server);
    defer allocator.free(page.session);
    const enabled = try page.client.call("Debugger.enable", "{}", page.session);
    enabled.deinit();
    // Not awaited: the evaluation pauses at its `debugger;`.
    const message = try std.fmt.allocPrint(allocator, "{{\"id\":900,\"method\":\"Runtime.evaluate\",\"params\":{{\"expression\":\"setTimeout(() => {{ debugger; window.after = 'yes'; }}, 10); 0\"}},\"sessionId\":\"{s}\"}}", .{page.session});
    defer allocator.free(message);
    try page.client.sendText(message);
    const paused = try page.client.waitEvent("Debugger.paused");
    paused.deinit();
    page.client.close();
    server.stop();
    // Resumed by the detach: the rest of the callback ran.
    const after = try host.evaluate(allocator, tab, "window.after", .{}, 10_000);
    defer after.deinit(allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"yes\"}", after.json);
}
