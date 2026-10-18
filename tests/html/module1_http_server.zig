//! A loopback HTTP server for the module1 tests. A Browser's manual proxy
//! points at it, so the requested host stays the page's own
//! (http://module1.test/...) and no real network is involved.
//!
//! Each route answers one path with a fixed status, Content-Type and body,
//! and counts the requests it got - which is how a test tells a module map
//! hit (no request) from a refetch. A route can fail its first N requests
//! with a 404 (a failure the module map must not keep), or echo the request's
//! Accept header as its body.
const std = @import("std");

pub const Route = struct {
    path: []const u8,
    content_type: []const u8 = "text/javascript",
    body: []const u8 = "",
    /// The first `fail_first` requests answer 404.
    fail_first: u32 = 0,
    /// The body is the request's Accept header value.
    echo_accept: bool = false,
    /// The body is a JavaScript module whose default export is the
    /// request's Referer header value ("" with none).
    echo_referrer: bool = false,
    /// Milliseconds to wait before answering, so that requests overlap.
    delay_ms: u32 = 0,
};

pub const max_routes = 16;

pub const Server = struct {
    allocator: std.mem.Allocator,
    server: std.Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    /// Connections being answered: stop() waits for them, since each reads
    /// the routes and counters.
    active: std.atomic.Value(u32) = .init(0),
    routes: []const Route,
    counts: [max_routes]std.atomic.Value(u32) = @splat(.init(0)),

    pub fn start(allocator: std.mem.Allocator, routes: []const Route) !*Server {
        std.debug.assert(routes.len <= max_routes);
        const self = try allocator.create(Server);
        errdefer allocator.destroy(self);
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
        var server = try address.listen(std.testing.io, .{ .reuse_address = true });
        errdefer server.deinit(std.testing.io);
        self.* = .{ .allocator = allocator, .server = server, .routes = routes };
        self.thread = try std.Thread.spawn(.{}, serve, .{ self, server });
        return self;
    }

    pub fn stop(self: *Server) void {
        self.stopping.store(true, .release);
        self.server.deinit(std.testing.io);
        self.thread.?.join();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    /// "http://127.0.0.1:<port>", the Browser's proxy. Written into `buffer`.
    pub fn proxyUrl(self: *const Server, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "http://127.0.0.1:{d}", .{self.server.socket.address.getPort()});
    }

    /// How many requests the route for `path` has answered.
    pub fn count(self: *const Server, path: []const u8) u32 {
        for (self.routes, 0..) |route, i| {
            if (std.mem.eql(u8, route.path, path)) return self.counts[i].load(.acquire);
        }
        return 0;
    }

    fn serve(self: *Server, listener: std.Io.net.Server) void {
        // stop() closes the shared socket; accept reads a copy of it.
        var server = listener;
        while (!self.stopping.load(.acquire)) {
            const stream = server.accept(std.testing.io) catch continue;
            // One thread per connection: a delayed answer must not hold the
            // requests behind it.
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, answerAndClose, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            thread.detach();
        }
    }

    fn answerAndClose(self: *Server, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        self.answer(stream) catch {};
    }

    fn answer(self: *Server, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        // The request line and headers.
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            try reader.interface.fillMore();
        }
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const target = parts.next() orelse return;
        // Through a proxy the target is absolute: keep its path and query.
        const path = if (std.mem.indexOf(u8, target, "://")) |scheme_end| blk: {
            const after = target[scheme_end + 3 ..];
            const slash = std.mem.indexOfScalar(u8, after, '/') orelse break :blk "/";
            break :blk after[slash..];
        } else target;

        var output: [0]u8 = .{};
        var writer = stream.writer(std.testing.io, &output);
        for (self.routes, 0..) |route, i| {
            if (!std.mem.eql(u8, route.path, path)) continue;
            const n = self.counts[i].fetchAdd(1, .acq_rel);
            if (route.delay_ms > 0) std.Io.sleep(std.testing.io, .fromMilliseconds(route.delay_ms), .awake) catch {};
            if (n < route.fail_first) return reply(&writer.interface, 404, "text/plain", "not yet");
            if (route.echo_referrer) {
                var module_buf: [1024]u8 = undefined;
                const module = std.fmt.bufPrint(&module_buf, "export default \"{s}\";", .{header(head, "referer") orelse ""}) catch return;
                return reply(&writer.interface, 200, route.content_type, module);
            }
            const body = if (route.echo_accept) header(head, "accept") orelse "" else route.body;
            return reply(&writer.interface, 200, route.content_type, body);
        }
        try reply(&writer.interface, 404, "text/plain", "no such route");
    }

    fn header(head: []const u8, name: []const u8) ?[]const u8 {
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        _ = lines.next();
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (!std.ascii.eqlIgnoreCase(line[0..colon], name)) continue;
            return std.mem.trim(u8, line[colon + 1 ..], " \t");
        }
        return null;
    }

    fn reply(writer: *std.Io.Writer, status: u16, content_type: []const u8, body: []const u8) !void {
        try writer.print("HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", .{
            status,
            if (status == 200) "OK" else "Not Found",
            content_type,
            body.len,
        });
        try writer.writeAll(body);
        try writer.flush();
    }
};
