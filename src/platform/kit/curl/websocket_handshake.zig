//! The WebSocket opening handshake over HTTP/1.1 (RFC 6455 section 4.1),
//! for kit/curl's WebSocket transport, which owns the protocol on the
//! connection curl makes (websocket_frames.zig says why): the request, the
//! response head read as the browsers read an HTTP/1 head, and the client's
//! checks of it.
//!
//! The request carries the fields libcurl's upgrade sent (lib/ws.c
//! Curl_ws_request, lib/http.c), so a server sees what it saw before the
//! transport framed for itself: Host, User-Agent, `Accept: */*` (Fetch's
//! "fetch" step 12 default), Upgrade, Connection, Sec-WebSocket-Version and
//! Sec-WebSocket-Key, then the caller's fields (Origin, Sec-WebSocket-Protocol,
//! Cookie: policy above the platform), then Basic credentials from the URL as
//! libcurl sent them.

const std = @import("std");

/// RFC 6455 1.3's GUID.
pub const guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

/// A Sec-WebSocket-Key: 16 random bytes, base64-encoded (4.1, client step 7).
pub const Key = [24]u8;

pub fn keyFrom(random: [16]u8) Key {
    var out: Key = undefined;
    _ = std.base64.standard.Encoder.encode(&out, &random);
    return out;
}

/// The Sec-WebSocket-Accept a server answers `key` with (4.2.2, step 5.4).
pub fn acceptFor(key: []const u8) [28]u8 {
    var sha = std.crypto.hash.Sha1.init(.{});
    sha.update(key);
    sha.update(guid);
    var digest: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    sha.final(&digest);
    var out: [28]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&out, &digest);
    return out;
}

pub const Field = struct {
    name: []const u8,
    value: []const u8,
};

/// Where the request goes: the WebSocket URL's parts (4.1, client steps 2-4).
pub const Target = struct {
    /// The host as the URL serializes it (an IPv6 address in brackets).
    host: []const u8,
    /// Null for the scheme's default port (80 for ws:, 443 for wss:).
    port: ?u16,
    /// "/" path ["?" query] (WebSockets' "resource name").
    resource: []const u8,
};

/// Append the opening handshake request to `out`. `authorization` is a
/// whole `Basic ...` value, sent unless a caller field is an Authorization.
pub fn writeRequest(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    target: Target,
    key: []const u8,
    user_agent: ?[]const u8,
    authorization: ?[]const u8,
    fields: []const Field,
) std.mem.Allocator.Error!void {
    var w: std.Io.Writer.Allocating = .fromArrayList(allocator, out);
    defer out.* = w.toArrayList();
    const writer = &w.writer;
    writeAll(writer, target, key, user_agent, authorization, fields) catch return error.OutOfMemory;
}

fn writeAll(writer: *std.Io.Writer, target: Target, key: []const u8, user_agent: ?[]const u8, authorization: ?[]const u8, fields: []const Field) std.Io.Writer.Error!void {
    try writer.print("GET {s} HTTP/1.1\r\n", .{target.resource});
    if (target.port) |port| {
        try writer.print("Host: {s}:{d}\r\n", .{ target.host, port });
    } else try writer.print("Host: {s}\r\n", .{target.host});
    if (user_agent) |value| try writer.print("User-Agent: {s}\r\n", .{value});
    try writer.writeAll("Accept: */*\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\n");
    try writer.print("Sec-WebSocket-Key: {s}\r\n", .{key});
    var has_authorization = false;
    for (fields) |field| {
        if (std.ascii.eqlIgnoreCase(field.name, "Authorization")) has_authorization = true;
        try writer.print("{s}: {s}\r\n", .{ field.name, field.value });
    }
    if (authorization) |value| if (!has_authorization) try writer.print("Authorization: {s}\r\n", .{value});
    try writer.writeAll("\r\n");
}

/// Where the response head ends: the index just past its empty line, or
/// null while it has not all arrived. A line may end in CRLF or a lone LF
/// (RFC 9112 2.2: a recipient MAY recognize LF alone; so do Chrome's
/// HttpUtil::LocateEndOfHeaders and Firefox's nsHttpTransaction).
pub fn headEnd(bytes: []const u8) ?usize {
    var i: usize = 0;
    while (std.mem.indexOfScalarPos(u8, bytes, i, '\n')) |lf| {
        const next = lf + 1;
        if (next < bytes.len and bytes[next] == '\n') return next + 1;
        if (next + 1 < bytes.len and bytes[next] == '\r' and bytes[next + 1] == '\n') return next + 2;
        i = next;
    }
    return null;
}

/// A response head: its status and its fields, slices of the head's bytes.
pub const Head = struct {
    status: u16,
    fields: std.ArrayList(Field) = .empty,

    pub fn deinit(self: *Head, allocator: std.mem.Allocator) void {
        self.fields.deinit(allocator);
    }

    /// The one value of `name`, or null when it is absent or appears more
    /// than once (Chromium's WebSocket handshake fails a repeated Upgrade or
    /// Sec-WebSocket-Accept: net/websockets/websocket_basic_handshake_stream.cc
    /// ValidateHeaderHasSingleValue).
    pub fn single(self: *const Head, name: []const u8) ?[]const u8 {
        var found: ?[]const u8 = null;
        for (self.fields.items) |field| {
            if (!std.ascii.eqlIgnoreCase(field.name, name)) continue;
            if (found != null) return null;
            found = field.value;
        }
        return found;
    }
};

pub const ParseError = error{ InvalidResponse, OutOfMemory };

/// Parse `head` (the bytes up to headEnd), the way the browsers read an
/// HTTP/1 response head: a NUL anywhere fails it (all three, fetch/h1-parsing/
/// resources-with-0x00-in-header); the status line is "HTTP/1.x", a space
/// and three digits; a line with no colon, or whose name is empty or starts
/// with whitespace after a line that was skipped, is skipped (Chrome
/// net/http/http_util.cc HttpUtil::HeadersIterator::GetNext, Firefox
/// nsHttpHeaderArray::ParseHeaderLine); a line starting with whitespace
/// continues the field before it (obs-fold, RFC 9112 5.2; Chrome
/// HttpUtil::AssembleRawHeaders); values are trimmed of spaces and tabs.
/// The fields are slices of `head`, valid while it is.
pub fn parseHead(allocator: std.mem.Allocator, head: []const u8, folded: *std.ArrayList(u8)) ParseError!Head {
    if (std.mem.indexOfScalar(u8, head, 0) != null) return error.InvalidResponse;
    var lines = std.mem.splitScalar(u8, head, '\n');
    const status_line = trimCr(lines.next() orelse return error.InvalidResponse);
    if (status_line.len < 12 or !std.mem.startsWith(u8, status_line, "HTTP/1.") or
        !std.ascii.isDigit(status_line[7]) or status_line[8] != ' ') return error.InvalidResponse;
    const digits = status_line[9..12];
    for (digits) |d| if (!std.ascii.isDigit(d)) return error.InvalidResponse;
    if (status_line.len > 12 and status_line[12] != ' ') return error.InvalidResponse;
    var result: Head = .{ .status = std.fmt.parseInt(u16, digits, 10) catch unreachable };
    errdefer result.deinit(allocator);
    // A field continued by obs-fold lines: its value is rebuilt in `folded`
    // (owned by the caller, kept alive with the head) with one space for
    // each line break.
    var last_kept = false;
    while (lines.next()) |raw| {
        const line = trimCr(raw);
        if (line.len == 0) break;
        if (line[0] == ' ' or line[0] == '\t') {
            if (!last_kept) continue;
            const last = &result.fields.items[result.fields.items.len - 1];
            const more = std.mem.trim(u8, line, " \t");
            const start = folded.items.len;
            try folded.ensureUnusedCapacity(allocator, last.value.len + 1 + more.len);
            folded.appendSliceAssumeCapacity(last.value);
            folded.appendAssumeCapacity(' ');
            folded.appendSliceAssumeCapacity(more);
            last.value = folded.items[start..];
            continue;
        }
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse {
            last_kept = false;
            continue;
        };
        const name = std.mem.trimEnd(u8, line[0..colon], " \t");
        if (name.len == 0) {
            last_kept = false;
            continue;
        }
        try result.fields.append(allocator, .{ .name = name, .value = std.mem.trim(u8, line[colon + 1 ..], " \t") });
        last_kept = true;
    }
    return result;
}

fn trimCr(line: []const u8) []const u8 {
    return if (line.len > 0 and line[line.len - 1] == '\r') line[0 .. line.len - 1] else line;
}

/// RFC 6455 4.1's checks of a response whose status is 101 (the client's
/// steps 2-4; step 5, the extensions, is websocket_deflate.zig's `agree`, as
/// the transport offered them; step 6, the subprotocol, is above the
/// platform): Upgrade is "websocket", Connection has the token "Upgrade", and
/// Sec-WebSocket-Accept is `key`'s.
pub fn accepts(head: *const Head, key: []const u8) bool {
    if (head.status != 101) return false;
    const upgrade = head.single("Upgrade") orelse return false;
    if (!std.ascii.eqlIgnoreCase(upgrade, "websocket")) return false;
    var has_upgrade_token = false;
    for (head.fields.items) |field| {
        if (!std.ascii.eqlIgnoreCase(field.name, "Connection")) continue;
        var tokens = std.mem.splitScalar(u8, field.value, ',');
        while (tokens.next()) |token| {
            if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, token, " \t"), "Upgrade")) has_upgrade_token = true;
        }
    }
    if (!has_upgrade_token) return false;
    const accept = head.single("Sec-WebSocket-Accept") orelse return false;
    return std.mem.eql(u8, accept, &acceptFor(key));
}
