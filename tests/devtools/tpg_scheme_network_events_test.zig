//! Network events for the schemes Fetch answers without the network, as
//! Chrome sends them (lane tpg; Chrome for Testing 157.0.8103.78, a CDP
//! probe over --remote-debugging-pipe, 2026-11-22):
//! - a data: or file: navigation goes through Fetch, so the Browser's fetch
//!   observer hears it: requestWillBeSent (type Document, requestId ==
//!   loaderId), responseReceived, loadingFinished - or loadingFailed for a
//!   data: URL the processor rejects or a file that is not there;
//! - Network.Response.protocol is the URL's scheme for a response that did
//!   not come over HTTP: "data", "file";
//! - a data: script, stylesheet or image is static data Blink serves from
//!   its memory cache: requestServedFromCache before responseReceived, and
//!   loadingFinished's encodedDataLength 0; fetch() of a data: URL is not;
//! - a file: document's subresources and the document itself carry their
//!   status and headers - Content-Type and Last-Modified - as DevTools sees
//!   the response before Fetch filters it;
//! - who may load a file: URL: a file: document may (its frame loads), a
//!   page that is not one may not (its frame's request fails).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");

const BrowserHost = browser_mod.BrowserHost;
const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

/// One Network event, its fields copied into the test's arena.
const Event = struct {
    method: []const u8,
    request_id: []const u8,
    loader_id: []const u8 = "",
    type: []const u8 = "",
    url: []const u8 = "",
    protocol: []const u8 = "",
    status: i64 = -1,
    mime_type: []const u8 = "",
    last_modified: bool = false,
    encoded_length: f64 = -1,
};

const Page = struct {
    host: *BrowserHost,
    server: *devtools.Server,
    client: *cdp.Client,
    session: []u8,
    allocator: std.mem.Allocator,

    fn open(allocator: std.mem.Allocator) !Page {
        const host = try BrowserHost.start(allocator, .{});
        errdefer host.stop();
        _ = try host.createTab(.{});
        const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
        errdefer server.stop();
        var path_buffer: [96]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buffer, "/devtools/browser/{s}", .{server.browser_id.slice()});
        const client = try cdp.Client.openWebSocket(allocator, server.port, path, null);
        errdefer client.close();
        const listed = try client.call("Target.getTargets", "{}", "");
        defer listed.deinit();
        // The tab this test made: the newest page target.
        var newest: ?[]const u8 = null;
        for (cdp.at(listed.value, "result.targetInfos").?.array.items) |info| {
            if (std.mem.eql(u8, cdp.stringAt(info, "type").?, "page")) newest = cdp.stringAt(info, "targetId").?;
        }
        var params_buffer: [160]u8 = undefined;
        const attached = try client.call("Target.attachToTarget", try std.fmt.bufPrint(&params_buffer, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{newest orelse return error.NoPageTarget}), "");
        defer attached.deinit();
        const session = try allocator.dupe(u8, cdp.stringAt(attached.value, "result.sessionId").?);
        errdefer allocator.free(session);
        for ([_][]const u8{ "Page.enable", "Network.enable" }) |m| {
            const r = try client.call(m, "{}", session);
            r.deinit();
        }
        return .{ .host = host, .server = server, .client = client, .session = session, .allocator = allocator };
    }

    fn close(self: *Page) void {
        self.allocator.free(self.session);
        self.client.close();
        self.server.stop();
        self.host.stop();
    }

    fn navigate(self: *Page, url: []const u8) !void {
        var params: std.ArrayList(u8) = .empty;
        defer params.deinit(self.allocator);
        try params.print(self.allocator, "{{\"url\":{f}}}", .{std.json.fmt(url, .{})});
        const r = try self.client.call("Page.navigate", params.items, self.session);
        r.deinit();
    }

    fn evaluate(self: *Page, expression: []const u8) !void {
        var params: std.ArrayList(u8) = .empty;
        defer params.deinit(self.allocator);
        try params.print(self.allocator, "{{\"expression\":{f},\"awaitPromise\":true}}", .{std.json.fmt(expression, .{})});
        const r = try self.client.call("Runtime.evaluate", params.items, self.session);
        r.deinit();
    }

    /// Network events, in arrival order, until `count` of them have ended
    /// (loadingFinished or loadingFailed).
    fn eventsUntilEnded(self: *Page, arena: std.mem.Allocator, count: usize) ![]Event {
        var events: std.ArrayList(Event) = .empty;
        var ended: usize = 0;
        while (ended < count) {
            const parsed = try self.client.nextEventOf(&.{ "Network.requestWillBeSent", "Network.requestServedFromCache", "Network.responseReceived", "Network.loadingFinished", "Network.loadingFailed" });
            defer parsed.deinit();
            const v = parsed.value;
            const method = cdp.stringAt(v, "method").?;
            var e: Event = .{ .method = try arena.dupe(u8, method), .request_id = try arena.dupe(u8, cdp.stringAt(v, "params.requestId").?) };
            if (cdp.stringAt(v, "params.loaderId")) |l| e.loader_id = try arena.dupe(u8, l);
            if (cdp.stringAt(v, "params.type")) |t| e.type = try arena.dupe(u8, t);
            if (cdp.stringAt(v, "params.request.url")) |u| e.url = try arena.dupe(u8, u);
            if (cdp.at(v, "params.response")) |response| {
                e.url = try arena.dupe(u8, cdp.stringAt(response, "url").?);
                e.protocol = try arena.dupe(u8, cdp.stringAt(response, "protocol") orelse "");
                e.status = cdp.at(response, "status").?.integer;
                e.mime_type = try arena.dupe(u8, cdp.stringAt(response, "mimeType").?);
                if (cdp.at(response, "headers")) |h| {
                    var it = h.object.iterator();
                    while (it.next()) |entry| if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, "last-modified")) {
                        e.last_modified = true;
                    };
                }
            }
            if (std.mem.eql(u8, method, "Network.loadingFinished")) e.encoded_length = switch (cdp.at(v, "params.encodedDataLength").?) {
                .integer => |n| @floatFromInt(n),
                .float => |f| f,
                else => -1,
            };
            if (std.mem.eql(u8, method, "Network.loadingFinished") or std.mem.eql(u8, method, "Network.loadingFailed")) ended += 1;
            try events.append(arena, e);
        }
        return events.items;
    }
};

/// The first event named `method` for a request whose requestWillBeSent
/// URL starts with `url_prefix`.
fn eventFor(events: []const Event, url_prefix: []const u8, method: []const u8) ?Event {
    var id: ?[]const u8 = null;
    for (events) |e| if (std.mem.eql(u8, e.method, "Network.requestWillBeSent") and std.mem.startsWith(u8, e.url, url_prefix)) {
        id = e.request_id;
        break;
    };
    const request_id = id orelse return null;
    for (events) |e| if (std.mem.eql(u8, e.method, method) and std.mem.eql(u8, e.request_id, request_id)) return e;
    return null;
}

fn indexOf(events: []const Event, url_prefix: []const u8, method: []const u8) ?usize {
    const wanted = eventFor(events, url_prefix, method) orelse return null;
    for (events, 0..) |e, i| if (std.mem.eql(u8, e.method, method) and std.mem.eql(u8, e.request_id, wanted.request_id)) return i;
    return null;
}

test "a data: document's Network events: Document request, protocol data; its data: script is served from the memory cache" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();

    try page.navigate("data:text/html,<script src='data:text/javascript,window.x=1'></script><p>doc</p>");
    const events = try page.eventsUntilEnded(arena_state.allocator(), 2);

    const doc = eventFor(events, "data:text/html", "Network.requestWillBeSent") orelse return error.NoDocumentRequest;
    try testing.expectEqualStrings("Document", doc.type);
    try testing.expectEqualStrings(doc.request_id, doc.loader_id);
    const doc_response = eventFor(events, "data:text/html", "Network.responseReceived") orelse return error.NoDocumentResponse;
    try testing.expectEqualStrings("data", doc_response.protocol);
    try testing.expectEqual(@as(i64, 200), doc_response.status);
    try testing.expectEqualStrings("text/html", doc_response.mime_type);
    try testing.expect(eventFor(events, "data:text/html", "Network.loadingFinished") != null);
    try testing.expect(eventFor(events, "data:text/html", "Network.requestServedFromCache") == null);

    const script = eventFor(events, "data:text/javascript", "Network.requestWillBeSent") orelse return error.NoScriptRequest;
    try testing.expectEqualStrings("Script", script.type);
    const cached_at = indexOf(events, "data:text/javascript", "Network.requestServedFromCache") orelse return error.NotServedFromCache;
    const response_at = indexOf(events, "data:text/javascript", "Network.responseReceived") orelse return error.NoScriptResponse;
    try testing.expect(cached_at < response_at);
    try testing.expectEqualStrings("data", events[response_at].protocol);
    try testing.expectEqual(@as(f64, 0), (eventFor(events, "data:text/javascript", "Network.loadingFinished") orelse return error.NoScriptEnd).encoded_length);
}

test "fetch() of a data: URL is not served from the cache, and its loadingFinished counts its body" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();

    try page.navigate("data:text/html,<p>doc</p>");
    _ = try page.eventsUntilEnded(arena_state.allocator(), 1);
    try page.evaluate("fetch('data:text/plain,abc').then(r => r.text())");
    const events = try page.eventsUntilEnded(arena_state.allocator(), 1);
    try testing.expect(eventFor(events, "data:text/plain,abc", "Network.requestServedFromCache") == null);
    const response = eventFor(events, "data:text/plain,abc", "Network.responseReceived") orelse return error.NoResponse;
    try testing.expectEqualStrings("data", response.protocol);
    try testing.expectEqual(@as(f64, 3), (eventFor(events, "data:text/plain,abc", "Network.loadingFinished") orelse return error.NoEnd).encoded_length);
}

test "a data: URL the processor rejects is a navigation's loadingFailed" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var page = try Page.open(gpa.allocator());
    defer page.close();
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();

    try page.navigate("data:no-comma");
    const events = try page.eventsUntilEnded(arena_state.allocator(), 1);
    const request = eventFor(events, "data:no-comma", "Network.requestWillBeSent") orelse return error.NoRequest;
    try testing.expectEqualStrings("Document", request.type);
    const failed = eventFor(events, "data:no-comma", "Network.loadingFailed") orelse return error.NotFailed;
    try testing.expectEqualStrings("Document", failed.type);
}

test "a file: document and its subresources: protocol file, their status and headers, Last-Modified among them; a missing file fails" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "page.html", .data = "<!doctype html><script src='sub.js'></script><iframe src='frame.html'></iframe><p>file</p>" });
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "sub.js", .data = "window.sub = 1;" });
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "frame.html", .data = "<!doctype html><p>frame</p>" });
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", allocator);
    defer allocator.free(base);
    const url = try std.fmt.allocPrint(allocator, "file://{s}/page.html", .{base});
    defer allocator.free(url);
    const missing = try std.fmt.allocPrint(allocator, "file://{s}/missing.html", .{base});
    defer allocator.free(missing);

    var page = try Page.open(allocator);
    defer page.close();
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();

    try page.navigate(url);
    // The document, its script and its frame - a file: document's frame
    // may load a file: URL.
    const events = try page.eventsUntilEnded(arena_state.allocator(), 3);
    const doc = eventFor(events, url, "Network.requestWillBeSent") orelse return error.NoDocumentRequest;
    try testing.expectEqualStrings("Document", doc.type);
    try testing.expectEqualStrings(doc.request_id, doc.loader_id);
    const prefix = url[0 .. url.len - "page.html".len];
    for ([_][]const u8{ "page.html", "sub.js", "frame.html" }) |name| {
        const target = try std.mem.concat(arena_state.allocator(), u8, &.{ prefix, name });
        const response = eventFor(events, target, "Network.responseReceived") orelse {
            std.debug.print("no response for {s}\n", .{target});
            return error.NoResponse;
        };
        try testing.expectEqualStrings("file", response.protocol);
        try testing.expectEqual(@as(i64, 200), response.status);
        try testing.expect(response.last_modified);
        try testing.expect(eventFor(events, target, "Network.requestServedFromCache") == null);
    }
    const script_url = try std.mem.concat(arena_state.allocator(), u8, &.{ prefix, "sub.js" });
    try testing.expectEqualStrings("text/javascript", eventFor(events, script_url, "Network.responseReceived").?.mime_type);

    try page.navigate(missing);
    const after = try page.eventsUntilEnded(arena_state.allocator(), 1);
    try testing.expect(eventFor(after, missing, "Network.loadingFailed") != null);
}

test "a page that is not a file: document cannot load a file: URL in its frame" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "secret.html", .data = "<!doctype html><p>local</p>" });
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", allocator);
    defer allocator.free(base);
    const target = try std.fmt.allocPrint(allocator, "file://{s}/secret.html", .{base});
    defer allocator.free(target);
    const markup = try std.fmt.allocPrint(allocator, "data:text/html,<iframe src='{s}'></iframe>", .{target});
    defer allocator.free(markup);

    var page = try Page.open(allocator);
    defer page.close();
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();

    try page.navigate(markup);
    // The data: document, then its frame's request for the file - refused:
    // Blink's SecurityOrigin::CanDisplay ("Not allowed to load local
    // resource"); scheme fetch "file" gives a request whose initiator may
    // not load local resources a network error.
    const events = try page.eventsUntilEnded(arena_state.allocator(), 2);
    try testing.expect(eventFor(events, target, "Network.loadingFailed") != null);
    try testing.expect(eventFor(events, target, "Network.responseReceived") == null);
}
