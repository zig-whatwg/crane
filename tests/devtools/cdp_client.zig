//! A small Chrome DevTools Protocol client for the remote end's tests: HTTP
//! requests, the WebSocket opening handshake and frames (RFC 6455 client
//! role: masked frames), the pipe's NUL-delimited messages, and CDP calls
//! that wait for their response while keeping the events that arrive
//! between (what Puppeteer's Connection and Playwright's CRConnection do).
//!
//! Over loopback TCP through std.Io.net, and over a pipe pair the test makes.

const std = @import("std");
const io = std.testing.io;
const Allocator = std.mem.Allocator;

pub const HttpResponse = struct {
    allocator: Allocator,
    status: u16,
    /// The whole response, head and body.
    raw: []u8,
    body: []const u8,

    pub fn deinit(self: *HttpResponse) void {
        self.allocator.free(self.raw);
    }
};

fn connect(port: u16) !std.Io.net.Stream {
    const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(port) };
    return address.connect(io, .{ .mode = .stream });
}

/// One HTTP/1.1 request; the server closes the connection after it.
/// `headers` are whole lines ("Host: 127.0.0.1").
pub fn httpGet(allocator: Allocator, port: u16, path: []const u8, headers: []const []const u8) !HttpResponse {
    const stream = try connect(port);
    defer stream.close(io);
    var write_buffer: [1024]u8 = undefined;
    var writer = stream.writer(io, &write_buffer);
    try writer.interface.print("GET {s} HTTP/1.1\r\n", .{path});
    for (headers) |h| try writer.interface.print("{s}\r\n", .{h});
    try writer.interface.writeAll("\r\n");
    try writer.interface.flush();

    var read_buffer: [64 * 1024]u8 = undefined;
    var reader = stream.reader(io, &read_buffer);
    var raw: std.ArrayList(u8) = .empty;
    errdefer raw.deinit(allocator);
    while (true) {
        reader.interface.fillMore() catch break;
        const got = reader.interface.buffered();
        try raw.appendSlice(allocator, got);
        reader.interface.toss(got.len);
    }
    const owned = try raw.toOwnedSlice(allocator);
    return .{ .allocator = allocator, .status = parseStatus(owned), .raw = owned, .body = bodyOf(owned) };
}

fn parseStatus(raw: []const u8) u16 {
    if (raw.len < 12) return 0;
    return std.fmt.parseInt(u16, raw[9..12], 10) catch 0;
}

fn bodyOf(raw: []const u8) []const u8 {
    const end = std.mem.indexOf(u8, raw, "\r\n\r\n") orelse return "";
    return raw[end + 4 ..];
}

/// A CDP connection: a WebSocket, or a pipe pair.
pub const Client = struct {
    allocator: Allocator,
    transport: Transport,
    read_buffer: [64 * 1024]u8 = undefined,
    /// Bytes read and not yet consumed.
    pending: std.ArrayList(u8) = .empty,
    /// Messages that arrived while a call waited: events, other responses.
    queued: std.ArrayList([]u8) = .empty,
    next_id: i64 = 1,
    /// The status of the upgrade's response (101 when it was accepted).
    upgrade_status: u16 = 0,
    /// The status code of the server's close frame, once one came.
    last_close: ?u16 = null,

    pub const Transport = union(enum) {
        socket: std.Io.net.Stream,
        pipe: struct { read_fd: std.c.fd_t, write_fd: std.c.fd_t },
    };

    /// Open a WebSocket to `path`, with an Origin header when given.
    pub fn openWebSocket(allocator: Allocator, port: u16, path: []const u8, origin: ?[]const u8) !*Client {
        const self = try allocator.create(Client);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .transport = .{ .socket = try connect(port) } };
        errdefer self.transport.socket.close(io);
        var request: std.ArrayList(u8) = .empty;
        defer request.deinit(allocator);
        try request.print(allocator, "GET {s} HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" ++
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n", .{ path, port });
        if (origin) |o| try request.print(allocator, "Origin: {s}\r\n", .{o});
        try request.appendSlice(allocator, "\r\n");
        try self.writeAll(request.items);
        // The response head.
        while (std.mem.indexOf(u8, self.pending.items, "\r\n\r\n") == null) {
            if (!try self.readMore()) break;
        }
        self.upgrade_status = parseStatus(self.pending.items);
        if (std.mem.indexOf(u8, self.pending.items, "\r\n\r\n")) |end| self.consume(end + 4);
        return self;
    }

    /// A client of the pipe transport: it writes to `write_fd` and reads
    /// from `read_fd`.
    pub fn openPipe(allocator: Allocator, read_fd: std.c.fd_t, write_fd: std.c.fd_t) !*Client {
        const self = try allocator.create(Client);
        self.* = .{ .allocator = allocator, .transport = .{ .pipe = .{ .read_fd = read_fd, .write_fd = write_fd } } };
        return self;
    }

    pub fn close(self: *Client) void {
        switch (self.transport) {
            .socket => |s| s.close(io),
            .pipe => |p| {
                _ = std.c.close(p.write_fd);
                _ = std.c.close(p.read_fd);
            },
        }
        for (self.queued.items) |m| self.allocator.free(m);
        self.queued.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn writeAll(self: *Client, bytes: []const u8) !void {
        switch (self.transport) {
            .socket => |s| {
                var buffer: [4096]u8 = undefined;
                var writer = s.writer(io, &buffer);
                try writer.interface.writeAll(bytes);
                try writer.interface.flush();
            },
            .pipe => |p| {
                var rest = bytes;
                while (rest.len > 0) {
                    const n = std.c.write(p.write_fd, rest.ptr, rest.len);
                    if (n <= 0) return error.WriteFailed;
                    rest = rest[@intCast(n)..];
                }
            },
        }
    }

    /// Read what has arrived; false at the end of the stream.
    fn readMore(self: *Client) !bool {
        const n: usize = switch (self.transport) {
            .socket => |s| blk: {
                var reader = s.reader(io, &self.read_buffer);
                reader.interface.fillMore() catch break :blk 0;
                const got = reader.interface.buffered();
                try self.pending.appendSlice(self.allocator, got);
                break :blk got.len;
            },
            .pipe => |p| blk: {
                const got = std.c.read(p.read_fd, &self.read_buffer, self.read_buffer.len);
                if (got <= 0) break :blk 0;
                try self.pending.appendSlice(self.allocator, self.read_buffer[0..@intCast(got)]);
                break :blk @intCast(got);
            },
        };
        return n != 0;
    }

    fn consume(self: *Client, n: usize) void {
        const rest = self.pending.items.len - n;
        std.mem.copyForwards(u8, self.pending.items[0..rest], self.pending.items[n..]);
        self.pending.shrinkRetainingCapacity(rest);
    }

    /// Send one message: a masked text frame (RFC 6455 5.1: a client masks
    /// every frame), or the message and a NUL on the pipe.
    pub fn sendText(self: *Client, text: []const u8) !void {
        switch (self.transport) {
            .pipe => {
                try self.writeAll(text);
                try self.writeAll("\x00");
            },
            .socket => {
                const frame = try maskedFrame(self.allocator, 0x81, text);
                defer self.allocator.free(frame);
                try self.writeAll(frame);
            },
        }
    }

    /// Send raw bytes on the socket (malformed-frame tests).
    pub fn sendRaw(self: *Client, bytes: []const u8) !void {
        try self.writeAll(bytes);
    }

    /// The next message, OWNED; null when the connection ended. A close
    /// frame is `error.Closed`, its code in `last_close`.
    pub fn receive(self: *Client) !?[]u8 {
        if (self.queued.items.len > 0) return self.queued.orderedRemove(0);
        return self.receiveFromWire();
    }

    fn receiveFromWire(self: *Client) !?[]u8 {
        while (true) {
            switch (self.transport) {
                .pipe => if (std.mem.indexOfScalar(u8, self.pending.items, 0)) |end| {
                    const message = try self.allocator.dupe(u8, self.pending.items[0..end]);
                    self.consume(end + 1);
                    return message;
                },
                .socket => if (try self.takeFrame()) |message| return message,
            }
            if (!try self.readMore()) return null;
        }
    }

    /// A whole server frame from `pending` (unmasked), if one is there.
    fn takeFrame(self: *Client) !?[]u8 {
        const data = self.pending.items;
        if (data.len < 2) return null;
        const opcode = data[0] & 0x0F;
        var length: usize = data[1] & 0x7F;
        var offset: usize = 2;
        if (length == 126) {
            if (data.len < 4) return null;
            length = std.mem.readInt(u16, data[2..4], .big);
            offset = 4;
        } else if (length == 127) {
            if (data.len < 10) return null;
            length = @intCast(std.mem.readInt(u64, data[2..10], .big));
            offset = 10;
        }
        if (data.len < offset + length) return null;
        const payload = try self.allocator.dupe(u8, data[offset .. offset + length]);
        self.consume(offset + length);
        if (opcode == 0x8) {
            self.last_close = if (payload.len >= 2) std.mem.readInt(u16, payload[0..2], .big) else null;
            self.allocator.free(payload);
            return error.Closed;
        }
        return payload;
    }

    /// Send a command and wait for its response, keeping what arrives
    /// before it. `params` is a JSON object's text ("{}" when none);
    /// `session_id` empty for the browser session. The response is OWNED by
    /// the caller (`deinit`).
    pub fn call(self: *Client, method: []const u8, params: []const u8, session_id: []const u8) !std.json.Parsed(std.json.Value) {
        const id = self.next_id;
        self.next_id += 1;
        var message: std.ArrayList(u8) = .empty;
        defer message.deinit(self.allocator);
        try message.print(self.allocator, "{{\"id\":{d},\"method\":\"{s}\",\"params\":{s}", .{ id, method, params });
        if (session_id.len > 0) try message.print(self.allocator, ",\"sessionId\":\"{s}\"", .{session_id});
        try message.appendSlice(self.allocator, "}");
        try self.sendText(message.items);
        while (true) {
            const text = (try self.receiveFromWire()) orelse return error.ConnectionClosed;
            const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, text, .{}) catch {
                self.allocator.free(text);
                return error.InvalidMessage;
            };
            const is_answer = if (parsed.value.object.get("id")) |v| v == .integer and v.integer == id else false;
            if (is_answer) {
                self.allocator.free(text);
                return parsed;
            }
            parsed.deinit();
            try self.queued.append(self.allocator, text);
        }
    }

    /// The next event named `method` (among those queued, then on the
    /// wire), OWNED by the caller; earlier messages stay queued.
    pub fn waitEvent(self: *Client, method: []const u8) !std.json.Parsed(std.json.Value) {
        var i: usize = 0;
        while (i < self.queued.items.len) : (i += 1) {
            if (isEvent(self.queued.items[i], method)) {
                const text = self.queued.orderedRemove(i);
                defer self.allocator.free(text);
                return std.json.parseFromSlice(std.json.Value, self.allocator, text, .{});
            }
        }
        while (true) {
            const text = (try self.receiveFromWire()) orelse return error.ConnectionClosed;
            if (isEvent(text, method)) {
                defer self.allocator.free(text);
                return std.json.parseFromSlice(std.json.Value, self.allocator, text, .{});
            }
            try self.queued.append(self.allocator, text);
        }
    }

    /// The next event named any of `methods`, in arrival order (among those
    /// queued, then on the wire), OWNED by the caller: what an order test
    /// reads. Other messages stay queued.
    pub fn nextEventOf(self: *Client, methods: []const []const u8) !std.json.Parsed(std.json.Value) {
        var i: usize = 0;
        while (i < self.queued.items.len) : (i += 1) {
            for (methods) |m| if (isEvent(self.queued.items[i], m)) {
                const text = self.queued.orderedRemove(i);
                defer self.allocator.free(text);
                return std.json.parseFromSlice(std.json.Value, self.allocator, text, .{});
            };
        }
        while (true) {
            const text = (try self.receiveFromWire()) orelse return error.ConnectionClosed;
            for (methods) |m| if (isEvent(text, m)) {
                defer self.allocator.free(text);
                return std.json.parseFromSlice(std.json.Value, self.allocator, text, .{});
            };
            try self.queued.append(self.allocator, text);
        }
    }

    fn isEvent(text: []const u8, method: []const u8) bool {
        var needle_buffer: [128]u8 = undefined;
        const needle = std.fmt.bufPrint(&needle_buffer, "\"method\":\"{s}\"", .{method}) catch return false;
        return std.mem.indexOf(u8, text, needle) != null and std.mem.indexOf(u8, text, "\"id\":") == null;
    }
};

/// A client frame with FIN, `first_byte`'s opcode, masked.
pub fn maskedFrame(allocator: Allocator, first_byte: u8, payload: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, first_byte);
    if (payload.len < 126) {
        try out.append(allocator, 0x80 | @as(u8, @intCast(payload.len)));
    } else if (payload.len <= 0xFFFF) {
        try out.append(allocator, 0x80 | 126);
        var len: [2]u8 = undefined;
        std.mem.writeInt(u16, &len, @intCast(payload.len), .big);
        try out.appendSlice(allocator, &len);
    } else {
        try out.append(allocator, 0x80 | 127);
        var len: [8]u8 = undefined;
        std.mem.writeInt(u64, &len, payload.len, .big);
        try out.appendSlice(allocator, &len);
    }
    const mask = [4]u8{ 0x37, 0xfa, 0x21, 0x3d };
    try out.appendSlice(allocator, &mask);
    for (payload, 0..) |b, i| try out.append(allocator, b ^ mask[i % 4]);
    return out.toOwnedSlice(allocator);
}

/// `value`'s string at a dotted path ("result.product"), or null.
pub fn stringAt(value: std.json.Value, path: []const u8) ?[]const u8 {
    const v = at(value, path) orelse return null;
    return switch (v) {
        .string => |s| s,
        else => null,
    };
}

pub fn at(value: std.json.Value, path: []const u8) ?std.json.Value {
    var current = value;
    var it = std.mem.splitScalar(u8, path, '.');
    while (it.next()) |part| {
        current = switch (current) {
            .object => |o| o.get(part) orelse return null,
            else => return null,
        };
    }
    return current;
}
