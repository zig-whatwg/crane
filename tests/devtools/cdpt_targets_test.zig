//! The browser target's Target domain (CDP part 1 phase P3; lane cdpt):
//! discovery, auto-attach and its waitForDebuggerOnStart throttle, flat
//! sessions, tab and page targets, browser contexts - against the sequences
//! the punted suites' runners send (tmp/plans/cdp1-evidence/seq-svelte.txt,
//! seq-vue-e2e-one.txt) and Chrome's TargetHandler
//! (content/browser/devtools/protocol/target_handler.cc).
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");

const BrowserHost = browser_mod.BrowserHost;
const LeakChecked = std.heap.DebugAllocator(.{ .thread_safe = true });

fn connectBrowser(allocator: std.mem.Allocator, server: *devtools.Server) !*cdp.Client {
    var path_buffer: [96]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buffer, "/devtools/browser/{s}", .{server.browser_id.slice()});
    const client = try cdp.Client.openWebSocket(allocator, server.port, path, null);
    if (client.upgrade_status != 101) return error.UpgradeRefused;
    return client;
}

test "setDiscoverTargets announces the existing tab's tab and page targets; a page target's id is a 32-hex frame id" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    // Puppeteer's discovery: every target ([{}] includes tabs).
    const discover = try client.call("Target.setDiscoverTargets", "{\"discover\":true,\"filter\":[{}]}", "");
    defer discover.deinit();
    var saw_tab = false;
    var saw_page = false;
    while (!(saw_tab and saw_page)) {
        const created = try client.waitEvent("Target.targetCreated");
        defer created.deinit();
        const kind = cdp.stringAt(created.value, "params.targetInfo.type").?;
        if (std.mem.eql(u8, kind, "tab")) saw_tab = true;
        if (std.mem.eql(u8, kind, "page")) {
            saw_page = true;
            const id = cdp.stringAt(created.value, "params.targetInfo.targetId").?;
            try testing.expectEqual(@as(usize, 32), id.len);
            try testing.expect(devtools.ids.parseFrameId(id) != null);
            try testing.expectEqualStrings("about:blank", cdp.stringAt(created.value, "params.targetInfo.url").?);
        }
    }
}

test "Playwright's launch: setAutoAttach attaches the existing page, not waiting; a created target is attached, waiting, before createTarget answers" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const version = try client.call("Browser.getVersion", "{}", "");
    version.deinit();
    const auto = try client.call("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true}", "");
    auto.deinit();
    const existing = try client.waitEvent("Target.attachedToTarget");
    defer existing.deinit();
    try testing.expectEqualStrings("page", cdp.stringAt(existing.value, "params.targetInfo.type").?);
    try testing.expect(!cdp.at(existing.value, "params.waitingForDebugger").?.bool);

    // A context and a page in it (seq-svelte.txt #22-#24).
    const context = try client.call("Target.createBrowserContext", "{\"disposeOnDetach\":true}", "");
    defer context.deinit();
    const context_id = cdp.stringAt(context.value, "result.browserContextId").?;
    var params_buffer: [160]u8 = undefined;
    const params = try std.fmt.bufPrint(&params_buffer, "{{\"url\":\"about:blank\",\"browserContextId\":\"{s}\"}}", .{context_id});
    const created = try client.call("Target.createTarget", params, "");
    defer created.deinit();
    const target_id = cdp.stringAt(created.value, "result.targetId").?;
    // Its attachedToTarget came first (queued while the call waited).
    const attached = try client.waitEvent("Target.attachedToTarget");
    defer attached.deinit();
    try testing.expectEqualStrings(target_id, cdp.stringAt(attached.value, "params.targetInfo.targetId").?);
    try testing.expect(cdp.at(attached.value, "params.waitingForDebugger").?.bool);
    try testing.expectEqualStrings(context_id, cdp.stringAt(attached.value, "params.targetInfo.browserContextId").?);
    const session_id = cdp.stringAt(attached.value, "params.sessionId").?;

    // The page session: Target.* answered by the browser target, the rest
    // by the page's Browser thread.
    const info = try client.call("Target.getTargetInfo", "{}", session_id);
    defer info.deinit();
    try testing.expectEqualStrings(target_id, cdp.stringAt(info.value, "result.targetInfo.targetId").?);
    const run = try client.call("Runtime.runIfWaitingForDebugger", "{}", session_id);
    run.deinit();
    const window = try client.call("Browser.getWindowForTarget", "{}", session_id);
    defer window.deinit();
    try testing.expect(cdp.at(window.value, "result.windowId") != null);

    // Disposing the context: the page's session detaches, the target goes.
    var dispose_buffer: [96]u8 = undefined;
    const dispose = try client.call("Target.disposeBrowserContext", try std.fmt.bufPrint(&dispose_buffer, "{{\"browserContextId\":\"{s}\"}}", .{context_id}), "");
    dispose.deinit();
    const detached = try client.waitEvent("Target.detachedFromTarget");
    defer detached.deinit();
    try testing.expectEqualStrings(session_id, cdp.stringAt(detached.value, "params.sessionId").?);
}

test "Puppeteer's launch: auto-attach to tab targets, each tab session attaches its page child" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const auto = try client.call("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true,\"filter\":[{\"type\":\"page\",\"exclude\":true},{}]}", "");
    auto.deinit();
    const tab = try client.waitEvent("Target.attachedToTarget");
    defer tab.deinit();
    try testing.expectEqualStrings("tab", cdp.stringAt(tab.value, "params.targetInfo.type").?);
    const tab_session = cdp.stringAt(tab.value, "params.sessionId").?;

    const child = try client.call("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true,\"filter\":[{}]}", tab_session);
    child.deinit();
    const page = try client.waitEvent("Target.attachedToTarget");
    defer page.deinit();
    try testing.expectEqualStrings("page", cdp.stringAt(page.value, "params.targetInfo.type").?);
    try testing.expectEqualStrings(tab_session, cdp.stringAt(page.value, "sessionId").?);
    const run = try client.call("Runtime.runIfWaitingForDebugger", "{}", tab_session);
    run.deinit();
}

test "attachToTarget makes a second session on a page that has one; detachFromTarget ends only it" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();

    const targets = try client.call("Target.getTargets", "{}", "");
    defer targets.deinit();
    const infos = cdp.at(targets.value, "result.targetInfos").?.array.items;
    try testing.expect(infos.len >= 1);
    const page_id = cdp.stringAt(infos[0], "targetId").?;
    var params_buffer: [128]u8 = undefined;
    const params = try std.fmt.bufPrint(&params_buffer, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{page_id});
    const first = try client.call("Target.attachToTarget", params, "");
    defer first.deinit();
    const second = try client.call("Target.attachToTarget", params, "");
    defer second.deinit();
    const a = cdp.stringAt(first.value, "result.sessionId").?;
    const b = cdp.stringAt(second.value, "result.sessionId").?;
    try testing.expect(!std.mem.eql(u8, a, b));

    var detach_buffer: [96]u8 = undefined;
    const detach = try client.call("Target.detachFromTarget", try std.fmt.bufPrint(&detach_buffer, "{{\"sessionId\":\"{s}\"}}", .{a}), "");
    detach.deinit();
    const gone = try client.call("Security.enable", "{}", a);
    defer gone.deinit();
    try testing.expectEqual(@as(i64, -32001), cdp.at(gone.value, "error.code").?.integer);
    const alive = try client.call("Security.enable", "{}", b);
    defer alive.deinit();
    try testing.expect(cdp.at(alive.value, "result") != null);
}

test "attachToBrowserTarget: a second browser session (Vitest's cdp())" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const client = try connectBrowser(allocator, server);
    defer client.close();
    const attached = try client.call("Target.attachToBrowserTarget", "{}", "");
    defer attached.deinit();
    const session = cdp.stringAt(attached.value, "result.sessionId").?;
    const info = try client.call("Target.getTargetInfo", "{}", session);
    defer info.deinit();
    try testing.expectEqualStrings("browser", cdp.stringAt(info.value, "result.targetInfo.type").?);
}
