//! The remote end's transport (CDP part 1 phase P3; lane cdpt): the HTTP
//! endpoints and their Host/Origin checks (Chromium devtools_http_handler.cc
//! RequestIsSafeToServe, the --remote-allow-origins check), the WebSocket
//! opening handshake and framing (RFC 6455), the browser target's routing and
//! crdtp's error answers, and the pipe transport (devtools_pipe_handler.cc:
//! NUL-delimited messages on two descriptors).
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");

const BrowserHost = browser_mod.BrowserHost;
const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

const Fixture = struct {
    host: *BrowserHost,
    server: *devtools.Server,

    fn start(allocator: std.mem.Allocator, options: struct { origins: []const []const u8 = &.{} }) !Fixture {
        const host = try BrowserHost.start(allocator, .{});
        errdefer host.stop();
        _ = try host.createTab(.{});
        const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host, .allowed_origins = options.origins });
        return .{ .host = host, .server = server };
    }

    fn stop(self: *Fixture) void {
        self.server.stop();
        self.host.stop();
    }

    fn browserPath(self: *const Fixture, buffer: []u8) []const u8 {
        return std.fmt.bufPrint(buffer, "/devtools/browser/{s}", .{self.server.browser_id.slice()}) catch unreachable;
    }
};

test "/json/version names Crane (decision D4), the protocol version and the browser's WebSocket" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var fixture = try Fixture.start(allocator, .{});
    defer fixture.stop();

    var response = try cdp.httpGet(allocator, fixture.server.port, "/json/version", &.{"Host: 127.0.0.1"});
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response.body, .{});
    defer parsed.deinit();
    try testing.expectEqualStrings("Crane/0.1", cdp.stringAt(parsed.value, "Browser").?);
    try testing.expectEqualStrings("1.3", cdp.stringAt(parsed.value, "Protocol-Version").?);
    var url_buffer: [160]u8 = undefined;
    try testing.expectEqualStrings(fixture.server.browserUrl(&url_buffer), cdp.stringAt(parsed.value, "webSocketDebuggerUrl").?);
}

test "/json/list lists the page targets with their WebSocket URLs; /json/protocol serves both pinned files" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var fixture = try Fixture.start(allocator, .{});
    defer fixture.stop();

    // The first tab reaches the registry through the Browser's host events.
    var list: cdp.HttpResponse = undefined;
    var tries: usize = 0;
    while (true) : (tries += 1) {
        list = try cdp.httpGet(allocator, fixture.server.port, "/json/list", &.{"Host: localhost"});
        if (std.mem.indexOf(u8, list.body, "\"type\": \"page\"") != null or tries == 50) break;
        list.deinit();
        @import("platform").sleepThread(20 * std.time.ns_per_ms);
    }
    defer list.deinit();
    try testing.expectEqual(@as(u16, 200), list.status);
    try testing.expect(std.mem.indexOf(u8, list.body, "/devtools/page/") != null);

    var proto = try cdp.httpGet(allocator, fixture.server.port, "/json/protocol", &.{"Host: 127.0.0.1"});
    defer proto.deinit();
    try testing.expectEqual(@as(u16, 200), proto.status);
    // A browser_protocol domain and a js_protocol domain, in one object.
    try testing.expect(std.mem.indexOf(u8, proto.body, "\"domain\": \"Page\"") != null);
    try testing.expect(std.mem.indexOf(u8, proto.body, "\"domain\": \"Runtime\"") != null);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, proto.body, .{});
    parsed.deinit();
}

test "a Host that is not an IP address or localhost is refused (DNS rebinding), with Chrome's message" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var fixture = try Fixture.start(allocator, .{});
    defer fixture.stop();

    var response = try cdp.httpGet(allocator, fixture.server.port, "/json/version", &.{"Host: evil.example:9222"});
    defer response.deinit();
    try testing.expectEqual(@as(u16, 500), response.status);
    try testing.expectEqualStrings(devtools.http.host_refused_message, response.body);
}

test "a WebSocket upgrade with an Origin the server does not allow is refused with 403; an allowed one is served" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var fixture = try Fixture.start(allocator, .{ .origins = &.{"http://localhost:3000"} });
    defer fixture.stop();
    var path_buffer: [96]u8 = undefined;
    const path = fixture.browserPath(&path_buffer);

    const refused = try cdp.Client.openWebSocket(allocator, fixture.server.port, path, "http://evil.example");
    defer refused.close();
    try testing.expectEqual(@as(u16, 403), refused.upgrade_status);

    const allowed = try cdp.Client.openWebSocket(allocator, fixture.server.port, path, "http://localhost:3000");
    defer allowed.close();
    try testing.expectEqual(@as(u16, 101), allowed.upgrade_status);
}

test "the browser target answers Browser.getVersion; an unknown method and an unknown session get crdtp's errors" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var fixture = try Fixture.start(allocator, .{});
    defer fixture.stop();
    var path_buffer: [96]u8 = undefined;
    const client = try cdp.Client.openWebSocket(allocator, fixture.server.port, fixture.browserPath(&path_buffer), null);
    defer client.close();
    try testing.expectEqual(@as(u16, 101), client.upgrade_status);

    const version = try client.call("Browser.getVersion", "{}", "");
    defer version.deinit();
    try testing.expectEqualStrings("Crane/0.1", cdp.stringAt(version.value, "result.product").?);
    try testing.expectEqualStrings("1.3", cdp.stringAt(version.value, "result.protocolVersion").?);

    const unknown = try client.call("Foo.bar", "{}", "");
    defer unknown.deinit();
    try testing.expectEqual(@as(i64, -32601), cdp.at(unknown.value, "error.code").?.integer);
    try testing.expectEqualStrings("'Foo.bar' wasn't found", cdp.stringAt(unknown.value, "error.message").?);

    // A page domain on the browser session is no command of the browser target.
    const page = try client.call("Page.enable", "{}", "");
    defer page.deinit();
    try testing.expectEqual(@as(i64, -32601), cdp.at(page.value, "error.code").?.integer);

    const no_session = try client.call("Browser.getVersion", "{}", "0123456789ABCDEF0123456789ABCDEF");
    defer no_session.deinit();
    try testing.expectEqual(@as(i64, -32001), cdp.at(no_session.value, "error.code").?.integer);
    try testing.expectEqualStrings("Session with given id not found.", cdp.stringAt(no_session.value, "error.message").?);

    const bad_params = try client.call("Target.attachToTarget", "{\"flatten\":true}", "");
    defer bad_params.deinit();
    try testing.expectEqual(@as(i64, -32602), cdp.at(bad_params.value, "error.code").?.integer);
}

test "framing: a message split into fragments with a ping between them is one message; the ping is answered" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var fixture = try Fixture.start(allocator, .{});
    defer fixture.stop();
    var path_buffer: [96]u8 = undefined;
    const client = try cdp.Client.openWebSocket(allocator, fixture.server.port, fixture.browserPath(&path_buffer), null);
    defer client.close();

    const message = "{\"id\":7,\"method\":\"Browser.getVersion\"}";
    const first = try cdp.maskedFrame(allocator, 0x01, message[0..10]);
    defer allocator.free(first);
    const ping = try cdp.maskedFrame(allocator, 0x89, "hi");
    defer allocator.free(ping);
    const last = try cdp.maskedFrame(allocator, 0x80, message[10..]);
    defer allocator.free(last);
    try client.sendRaw(first);
    try client.sendRaw(ping);
    try client.sendRaw(last);
    // The pong comes first, as a raw frame; the receive loop reads text.
    const reply = (try client.receive()).?;
    defer allocator.free(reply);
    // "hi" - the pong's payload - or the response, whichever the reader
    // returned first; the response must come.
    if (std.mem.eql(u8, reply, "hi")) {
        const response = (try client.receive()).?;
        defer allocator.free(response);
        try testing.expect(std.mem.indexOf(u8, response, "\"id\":7") != null);
    } else try testing.expect(std.mem.indexOf(u8, reply, "\"id\":7") != null);
}

test "an unmasked client frame fails the connection with 1002 (RFC 6455 5.1)" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var fixture = try Fixture.start(allocator, .{});
    defer fixture.stop();
    var path_buffer: [96]u8 = undefined;
    const client = try cdp.Client.openWebSocket(allocator, fixture.server.port, fixture.browserPath(&path_buffer), null);
    defer client.close();
    try client.sendRaw(&.{ 0x81, 0x02, '{', '}' });
    try testing.expectError(error.Closed, client.receive());
    try testing.expectEqual(@as(?u16, 1002), client.last_close);
}

test "the pipe transport: NUL-delimited messages on two descriptors (--remote-debugging-pipe, decision D8)" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();

    var to_server: [2]std.c.fd_t = undefined;
    var from_server: [2]std.c.fd_t = undefined;
    try testing.expectEqual(@as(c_int, 0), std.c.pipe(&to_server));
    try testing.expectEqual(@as(c_int, 0), std.c.pipe(&from_server));
    const server = try devtools.Server.start(allocator, .{
        .pipe = .{ .read_fd = to_server[0], .write_fd = from_server[1] },
        .default_host = host,
    });
    defer server.stop();
    const client = try cdp.Client.openPipe(allocator, from_server[0], to_server[1]);
    defer client.close();

    const version = try client.call("Browser.getVersion", "{}", "");
    defer version.deinit();
    try testing.expectEqualStrings("Crane/0.1", cdp.stringAt(version.value, "result.product").?);
    const unknown = try client.call("Nope.nope", "{}", "");
    defer unknown.deinit();
    try testing.expectEqual(@as(i64, -32601), cdp.at(unknown.value, "error.code").?.integer);
}

test "Browser.close is answered, then the server asks the embedder to end" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var fixture = try Fixture.start(allocator, .{});
    defer fixture.stop();
    var path_buffer: [96]u8 = undefined;
    const client = try cdp.Client.openWebSocket(allocator, fixture.server.port, fixture.browserPath(&path_buffer), null);
    defer client.close();
    const closed = try client.call("Browser.close", "{}", "");
    defer closed.deinit();
    try testing.expect(cdp.at(closed.value, "result") != null);
    fixture.server.waitUntilClosed();
    try testing.expect(fixture.server.isClosed());
}
