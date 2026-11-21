//! The remote end's HTTP side: a request head, the checks Chrome makes
//! before serving one, and the responses of its JSON endpoints.
//!
//! Chromium content/browser/devtools/devtools_http_handler.cc (BSD-3):
//! `DevToolsHttpHandler::OnHttpRequest` serves /json/version, /json/list (=
//! /json) and /json/protocol; `OnWebSocketRequest` upgrades
//! /devtools/browser/<id> and /devtools/page/<id>. Before either it checks
//! the Host header (`RequestIsSafeToServe`: an IP address or "localhost", so
//! a DNS rebinding attack's page cannot reach the port), and since Chrome 111
//! a WebSocket upgrade carrying an Origin header is refused unless
//! --remote-allow-origins allows that origin. The messages here are
//! Chrome's.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// The largest request head read (Chrome's HttpServer reads up to 1 MiB of
/// head; a CDP client's is a few hundred bytes).
pub const max_head_bytes: usize = 64 * 1024;

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

/// A parsed request head; slices point into the bytes it was parsed from.
pub const Request = struct {
    method: []const u8,
    /// The request target, query included.
    target: []const u8,
    headers: []const Header,
    /// Bytes of the head, CRLFCRLF included: what follows is the body or,
    /// after an upgrade, WebSocket frames.
    head_len: usize,

    /// The first header named `name` (ASCII case-insensitive), if any.
    pub fn header(self: *const Request, name: []const u8) ?[]const u8 {
        for (self.headers) |h| if (std.ascii.eqlIgnoreCase(h.name, name)) return h.value;
        return null;
    }

    /// The path, without the query.
    pub fn path(self: *const Request) []const u8 {
        const end = std.mem.indexOfAny(u8, self.target, "?#") orelse self.target.len;
        return self.target[0..end];
    }

    /// Whether a header's comma-separated list holds `token` (ASCII
    /// case-insensitive): "Connection: keep-alive, Upgrade".
    pub fn headerHasToken(self: *const Request, name: []const u8, token: []const u8) bool {
        for (self.headers) |h| {
            if (!std.ascii.eqlIgnoreCase(h.name, name)) continue;
            var it = std.mem.tokenizeScalar(u8, h.value, ',');
            while (it.next()) |part| {
                if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, part, " \t"), token)) return true;
            }
        }
        return false;
    }

    /// RFC 6455 4.2.1: a GET with "Upgrade: websocket" and "Connection:
    /// Upgrade".
    pub fn isWebSocketUpgrade(self: *const Request) bool {
        return std.mem.eql(u8, self.method, "GET") and
            self.headerHasToken("upgrade", "websocket") and
            self.headerHasToken("connection", "upgrade");
    }
};

pub const ParseResult = union(enum) {
    /// The head is not complete yet: read more.
    incomplete,
    request: Request,
    /// Not HTTP/1.x, or the head is too long: answer 400 and close.
    bad,
};

/// Parse the request head at the start of `bytes`. Headers are allocated
/// from `arena`.
pub fn parseRequest(arena: Allocator, bytes: []const u8) Allocator.Error!ParseResult {
    const end = std.mem.indexOf(u8, bytes, "\r\n\r\n") orelse {
        return if (bytes.len > max_head_bytes) .bad else .incomplete;
    };
    if (end > max_head_bytes) return .bad;
    const head = bytes[0..end];
    var lines = std.mem.splitSequence(u8, head, "\r\n");
    const request_line = lines.next() orelse return .bad;
    var parts = std.mem.tokenizeScalar(u8, request_line, ' ');
    const method = parts.next() orelse return .bad;
    const target = parts.next() orelse return .bad;
    const version = parts.next() orelse return .bad;
    if (parts.next() != null or !std.mem.startsWith(u8, version, "HTTP/1.")) return .bad;
    var headers: std.ArrayList(Header) = .empty;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return .bad;
        try headers.append(arena, .{
            .name = std.mem.trim(u8, line[0..colon], " \t"),
            .value = std.mem.trim(u8, line[colon + 1 ..], " \t"),
        });
    }
    return .{ .request = .{
        .method = method,
        .target = target,
        .headers = try headers.toOwnedSlice(arena),
        .head_len = end + 4,
    } };
}

/// devtools_http_handler.cc `RequestIsSafeToServe`: no Host header, or one
/// whose host is an IP address or a localhost name ("localhost",
/// "*.localhost", net::IsLocalHostname).
pub fn hostIsSafe(host_header: ?[]const u8) bool {
    const value = host_header orelse return true;
    if (value.len == 0) return true;
    const host = hostPart(value);
    if (host.len == 0) return false;
    if (host[0] == '[') return std.mem.endsWith(u8, host, "]"); // an IPv6 literal
    if (isIpv4(host)) return true;
    const lower_buf_len = 256;
    if (host.len > lower_buf_len) return false;
    var lower: [lower_buf_len]u8 = undefined;
    const name = std.ascii.lowerString(lower[0..host.len], host);
    const trimmed = std.mem.trimEnd(u8, name, ".");
    return std.mem.eql(u8, trimmed, "localhost") or std.mem.endsWith(u8, trimmed, ".localhost");
}

/// The host of a Host header value: without its port.
fn hostPart(value: []const u8) []const u8 {
    if (value[0] == '[') {
        const close = std.mem.indexOfScalar(u8, value, ']') orelse return value;
        return value[0 .. close + 1];
    }
    const colon = std.mem.lastIndexOfScalar(u8, value, ':') orelse return value;
    return value[0..colon];
}

fn isIpv4(host: []const u8) bool {
    var it = std.mem.splitScalar(u8, host, '.');
    var count: usize = 0;
    while (it.next()) |part| {
        if (part.len == 0 or part.len > 3) return false;
        _ = std.fmt.parseInt(u8, part, 10) catch return false;
        count += 1;
    }
    return count == 4;
}

pub const host_refused_message = "Host header is specified and is not an IP address or localhost.";

/// devtools_http_handler.cc `OnWebSocketRequest`'s Origin check: an upgrade
/// with an Origin header is served only when --remote-allow-origins lists
/// that origin or "*".
pub fn originAllowed(origin: ?[]const u8, allowed: []const []const u8) bool {
    const value = origin orelse return true;
    for (allowed) |entry| {
        if (std.mem.eql(u8, entry, "*")) return true;
        if (std.ascii.eqlIgnoreCase(std.mem.trimEnd(u8, entry, "/"), std.mem.trimEnd(u8, value, "/"))) return true;
    }
    return false;
}

/// Chrome's 403 body for a refused origin. OWNED by the caller.
pub fn originRefusedMessage(allocator: Allocator, origin: []const u8) Allocator.Error![]u8 {
    return std.fmt.allocPrint(allocator, "Rejected an incoming WebSocket connection from the {s} origin. " ++
        "Use the command line flag --remote-allow-origins={s} to allow connections from this origin " ++
        "or --remote-allow-origins=* to allow all origins.", .{ origin, origin });
}

/// A whole response with `Connection: close`. OWNED by the caller.
pub fn response(allocator: Allocator, status: u16, content_type: []const u8, body: []const u8) Allocator.Error![]u8 {
    const reason = switch (status) {
        200 => "OK",
        400 => "Bad Request",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        500 => "Internal Server Error",
        else => "Error",
    };
    return std.fmt.allocPrint(allocator, "HTTP/1.1 {d} {s}\r\n" ++
        "Content-Type: {s}\r\n" ++
        "Content-Length: {d}\r\n" ++
        "Connection: close\r\n\r\n{s}", .{ status, reason, content_type, body.len, body });
}

pub const json_type = "application/json; charset=UTF-8";
pub const text_type = "text/html";

test "parseRequest: a WebSocket upgrade, waiting for the whole head first" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const raw = "GET /devtools/browser/ABC HTTP/1.1\r\nHost: 127.0.0.1:9222\r\nUpgrade: websocket\r\nConnection: keep-alive, Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n";
    try std.testing.expect((try parseRequest(arena.allocator(), raw[0 .. raw.len - 2])) == .incomplete);
    const request = (try parseRequest(arena.allocator(), raw)).request;
    try std.testing.expectEqualStrings("/devtools/browser/ABC", request.path());
    try std.testing.expect(request.isWebSocketUpgrade());
    try std.testing.expectEqualStrings("13", request.header("sec-websocket-version").?);
    try std.testing.expectEqual(raw.len, request.head_len);
}

test "hostIsSafe: IP addresses and localhost names only (DNS rebinding)" {
    try std.testing.expect(hostIsSafe(null));
    try std.testing.expect(hostIsSafe("127.0.0.1:9222"));
    try std.testing.expect(hostIsSafe("localhost:9222"));
    try std.testing.expect(hostIsSafe("LOCALHOST"));
    try std.testing.expect(hostIsSafe("foo.localhost:1"));
    try std.testing.expect(hostIsSafe("[::1]:9222"));
    try std.testing.expect(!hostIsSafe("evil.example:9222"));
    try std.testing.expect(!hostIsSafe("localhost.evil.example"));
    try std.testing.expect(!hostIsSafe("1.2.3:80"));
}

test "originAllowed: none, a listed origin, or *" {
    try std.testing.expect(originAllowed(null, &.{}));
    try std.testing.expect(!originAllowed("http://evil.example", &.{}));
    try std.testing.expect(originAllowed("http://localhost:3000", &.{"http://localhost:3000"}));
    try std.testing.expect(originAllowed("http://anything", &.{"*"}));
}
