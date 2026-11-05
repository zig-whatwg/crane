//! Safari through safaridriver (W3C WebDriver): Safari has no headless mode
//! and no way to open a page from its command line that leaves it
//! automatable, so the runner starts safaridriver, makes a session, and sends
//! the session to the page (WebDriver "New Session", "Navigate To", "Delete
//! Session"). One session at a time - safaridriver allows no more.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

/// One HTTP/1.1 request to 127.0.0.1:<port>, on a connection of its own; the
/// response's status and body (owned by `gpa`).
pub fn request(gpa: Allocator, io: Io, port: u16, method: []const u8, path: []const u8, body: ?[]const u8) !Response {
    const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(port) };
    const stream = try address.connect(io, .{ .mode = .stream });
    defer stream.close(io);
    var wbuf: [4096]u8 = undefined;
    var writer = stream.writer(io, &wbuf);
    const w = &writer.interface;
    try w.print("{s} {s} HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nConnection: close\r\n", .{ method, path, port });
    if (body) |b| try w.print("Content-Type: application/json; charset=utf-8\r\nContent-Length: {d}\r\n\r\n{s}", .{ b.len, b }) else try w.writeAll("Content-Length: 0\r\n\r\n");
    try w.flush();
    var rbuf: [64 * 1024]u8 = undefined;
    var reader = stream.reader(io, &rbuf);
    var all: std.ArrayList(u8) = .empty;
    defer all.deinit(gpa);
    while (true) {
        reader.interface.fillMore() catch |err| switch (err) {
            error.EndOfStream => break,
            // A reset after the whole head arrived ends the response too: a
            // peer that closes with our body unread resets the connection.
            else => if (std.mem.indexOf(u8, all.items, "\r\n\r\n") != null) break else return err,
        };
        try all.appendSlice(gpa, reader.interface.buffered());
        reader.interface.toss(reader.interface.buffered().len);
    }
    return parseResponse(gpa, all.items);
}

pub const Response = struct {
    status: u16,
    body: []u8,
};

/// A whole HTTP/1.1 response (Connection: close): status, and the body by
/// Content-Length, or to the end, or de-chunked.
pub fn parseResponse(gpa: Allocator, bytes: []const u8) !Response {
    const head_end = std.mem.indexOf(u8, bytes, "\r\n\r\n") orelse return error.BadResponse;
    const head = bytes[0..head_end];
    if (!std.mem.startsWith(u8, head, "HTTP/1.")) return error.BadResponse;
    const sp = std.mem.indexOfScalar(u8, head, ' ') orelse return error.BadResponse;
    if (head.len < sp + 4) return error.BadResponse;
    const status = std.fmt.parseInt(u16, head[sp + 1 .. sp + 4], 10) catch return error.BadResponse;
    var rest = bytes[head_end + 4 ..];
    var chunked = false;
    var lines = std.mem.splitSequence(u8, head, "\r\n");
    _ = lines.next();
    while (lines.next()) |line| {
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const name = line[0..colon];
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        if (std.ascii.eqlIgnoreCase(name, "content-length")) {
            const n = std.fmt.parseInt(usize, value, 10) catch return error.BadResponse;
            if (n <= rest.len) rest = rest[0..n];
        } else if (std.ascii.eqlIgnoreCase(name, "transfer-encoding") and std.ascii.eqlIgnoreCase(value, "chunked")) chunked = true;
    }
    if (!chunked) return .{ .status = status, .body = try gpa.dupe(u8, rest) };
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    var at: usize = 0;
    while (at < rest.len) {
        const eol = std.mem.indexOfPos(u8, rest, at, "\r\n") orelse break;
        const size_text = rest[at..eol];
        const semi = std.mem.indexOfScalar(u8, size_text, ';') orelse size_text.len;
        const size = std.fmt.parseInt(usize, std.mem.trim(u8, size_text[0..semi], " "), 16) catch return error.BadResponse;
        if (size == 0) break;
        const start = eol + 2;
        if (start + size > rest.len) return error.BadResponse;
        try out.appendSlice(gpa, rest[start .. start + size]);
        at = start + size + 2;
    }
    return .{ .status = status, .body = try out.toOwnedSlice(gpa) };
}

/// The value.sessionId of a New Session response.
pub fn sessionId(arena: Allocator, body: []const u8) ![]const u8 {
    const v = try std.json.parseFromSliceLeaky(std.json.Value, arena, body, .{});
    const value = v.object.get("value") orelse return error.NoSession;
    if (value != .object) return error.NoSession;
    const id = value.object.get("sessionId") orelse return error.NoSession;
    if (id != .string) return error.NoSession;
    return id.string;
}

/// A session on Safari through safaridriver on `port`.
pub const Session = struct {
    gpa: Allocator,
    io: Io,
    port: u16,
    id: []const u8,

    /// New Session, retried while safaridriver is still starting (up to
    /// `wait_ms`).
    pub fn create(arena: Allocator, io: Io, port: u16, wait_ms: u32) !Session {
        const caps = "{\"capabilities\":{\"alwaysMatch\":{\"browserName\":\"safari\"}}}";
        var waited: u32 = 0;
        while (true) {
            const r = request(arena, io, port, "POST", "/session", caps) catch |err| {
                if (waited >= wait_ms) return err;
                Io.sleep(io, .fromMilliseconds(100), .awake) catch {};
                waited += 100;
                continue;
            };
            if (r.status != 200) return error.NewSessionFailed;
            return .{ .gpa = arena, .io = io, .port = port, .id = try sessionId(arena, r.body) };
        }
    }

    /// Navigate To: returns once the page has loaded (WebDriver's normal
    /// page load strategy).
    pub fn navigate(self: *const Session, url: []const u8) !void {
        const path = try std.fmt.allocPrint(self.gpa, "/session/{s}/url", .{self.id});
        const body = try std.fmt.allocPrint(self.gpa, "{{\"url\":\"{s}\"}}", .{url});
        const r = try request(self.gpa, self.io, self.port, "POST", path, body);
        if (r.status != 200) return error.NavigateFailed;
    }

    pub fn delete(self: *const Session) void {
        const path = std.fmt.allocPrint(self.gpa, "/session/{s}", .{self.id}) catch return;
        _ = request(self.gpa, self.io, self.port, "DELETE", path, null) catch {};
    }
};

const testing = std.testing;

test "responses: by length, to the end, chunked" {
    const a = try parseResponse(testing.allocator, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}xx");
    defer testing.allocator.free(a.body);
    try testing.expectEqual(@as(u16, 200), a.status);
    try testing.expectEqualStrings("{}", a.body);
    const b = try parseResponse(testing.allocator, "HTTP/1.1 404 Not Found\r\n\r\nnope");
    defer testing.allocator.free(b.body);
    try testing.expectEqual(@as(u16, 404), b.status);
    try testing.expectEqualStrings("nope", b.body);
    const c = try parseResponse(testing.allocator, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n2\r\nde\r\n0\r\n\r\n");
    defer testing.allocator.free(c.body);
    try testing.expectEqualStrings("abcde", c.body);
    try testing.expectError(error.BadResponse, parseResponse(testing.allocator, "garbage"));
}

test "a New Session response's id" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    try testing.expectEqualStrings("ABC-1", try sessionId(arena.allocator(), "{\"value\":{\"sessionId\":\"ABC-1\",\"capabilities\":{}}}"));
    try testing.expectError(error.NoSession, sessionId(arena.allocator(), "{\"value\":{\"error\":\"session not created\"}}"));
}

/// A WebDriver stand-in: answers New Session, Navigate To and Delete Session,
/// recording the paths it saw.
const FakeDriver = struct {
    listener: Io.net.Server,
    seen: [3][64]u8 = undefined,
    seen_len: [3]usize = .{ 0, 0, 0 },
    thread: std.Thread = undefined,

    fn serve(self: *FakeDriver) void {
        const io = testing.io;
        for (0..3) |i| {
            const stream = self.listener.accept(io) catch return;
            defer stream.close(io);
            var in_buf: [8192]u8 = undefined;
            var out_buf: [8192]u8 = undefined;
            var reader = stream.reader(io, &in_buf);
            var writer = stream.writer(io, &out_buf);
            var http: std.http.Server = .init(&reader.interface, &writer.interface);
            var req = http.receiveHead() catch return;
            const t = req.head.target;
            const n = @min(t.len, 64);
            @memcpy(self.seen[i][0..n], t[0..n]);
            self.seen_len[i] = n;
            const body = if (i == 0) "{\"value\":{\"sessionId\":\"S1\",\"capabilities\":{}}}" else "{\"value\":null}";
            req.respond(body, .{ .keep_alive = false, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} }) catch return;
        }
    }
};

test "a session against a WebDriver stand-in: new, navigate, delete" {
    const io = testing.io;
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(0) };
    var fake: FakeDriver = .{ .listener = try address.listen(io, .{ .reuse_address = true }) };
    defer fake.listener.deinit(io);
    fake.thread = try std.Thread.spawn(.{}, FakeDriver.serve, .{&fake});
    const session = try Session.create(arena.allocator(), io, fake.listener.socket.address.getPort(), 1000);
    try testing.expectEqualStrings("S1", session.id);
    try session.navigate("http://127.0.0.1:1/x.html");
    session.delete();
    fake.thread.join();
    try testing.expectEqualStrings("/session", fake.seen[0][0..fake.seen_len[0]]);
    try testing.expectEqualStrings("/session/S1/url", fake.seen[1][0..fake.seen_len[1]]);
    try testing.expectEqualStrings("/session/S1", fake.seen[2][0..fake.seen_len[2]]);
}
