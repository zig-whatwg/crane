//! /json/list's target descriptors as Chrome's DevToolsHttpHandler writes
//! them (lane cdpd1; content/browser/devtools/devtools_http_handler.cc
//! SerializeDescriptor and GetFrontendURLInternal): both URLs name the host
//! the request was sent to, and devtoolsFrontendUrl is the remote DevTools
//! front end of the pinned protocol's Chrome - what chrome://inspect opens.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");

const BrowserHost = browser_mod.BrowserHost;
const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

test "/json/list gives each page its devtoolsFrontendUrl (kRemoteUrlPattern at the pinned revision) and its WebSocket URL on the request's host" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    _ = try host.createTab(.{});
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();

    var host_header_buffer: [64]u8 = undefined;
    const host_header = try std.fmt.bufPrint(&host_header_buffer, "Host: localhost:{d}", .{server.port});
    var list: cdp.HttpResponse = undefined;
    var tries: usize = 0;
    while (true) : (tries += 1) {
        list = try cdp.httpGet(allocator, server.port, "/json/list", &.{host_header});
        if (std.mem.indexOf(u8, list.body, "\"type\": \"page\"") != null or tries == 50) break;
        list.deinit();
        @import("platform").sleepThread(20 * std.time.ns_per_ms);
    }
    defer list.deinit();
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, list.body, .{});
    defer parsed.deinit();
    const page = parsed.value.array.items[0].object;
    const id = page.get("id").?.string;
    var expected_buffer: [256]u8 = undefined;
    const expected_frontend = try std.fmt.bufPrint(&expected_buffer, "https://chrome-devtools-frontend.appspot.com/serve_rev/@{s}/inspector.html?ws=localhost:{d}/devtools/page/{s}", .{ devtools.server_frontend_revision, server.port, id });
    try testing.expectEqualStrings(expected_frontend, page.get("devtoolsFrontendUrl").?.string);
    var ws_buffer: [128]u8 = undefined;
    const expected_ws = try std.fmt.bufPrint(&ws_buffer, "ws://localhost:{d}/devtools/page/{s}", .{ server.port, id });
    try testing.expectEqualStrings(expected_ws, page.get("webSocketDebuggerUrl").?.string);
    // The keys come in Chrome's (base::Value::Dict's sorted) order.
    const description_at = std.mem.indexOf(u8, list.body, "\"description\"").?;
    const frontend_at = std.mem.indexOf(u8, list.body, "\"devtoolsFrontendUrl\"").?;
    const id_at = std.mem.indexOf(u8, list.body, "\"id\"").?;
    try testing.expect(description_at < frontend_at and frontend_at < id_at);
}
