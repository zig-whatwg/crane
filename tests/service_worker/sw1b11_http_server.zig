//! A loopback HTTP server for the partitioned-registration Browser tests
//! (lane sw1-b11). A Browser's manual proxy points at it, so a page, its
//! frames, popups and workers keep their own hosts (http://localhost/...,
//! http://b.localhost/...: secure contexts, two sites) and no real network
//! is involved. Each route answers one path, whatever the host, with a
//! fixed body and `Cache-Control: no-store`. (After tests/html's
//! hc1_http_server.zig, which a test directory of its own cannot import.)
const std = @import("std");

pub const Route = struct {
    path: []const u8,
    body: []const u8 = "",
    content_type: []const u8 = "text/html",
};

pub const Server = struct {
    allocator: std.mem.Allocator,
    server: std.Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    active: std.atomic.Value(u32) = .init(0),
    routes: []const Route,

    pub fn start(allocator: std.mem.Allocator, routes: []const Route) !*Server {
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

    fn serve(self: *Server, listener: std.Io.net.Server) void {
        var server = listener;
        while (!self.stopping.load(.acquire)) {
            const stream = server.accept(std.testing.io) catch continue;
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
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            try reader.interface.fillMore();
        }
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const target = parts.next() orelse return;
        const full_path = if (std.mem.indexOf(u8, target, "://")) |scheme_end| blk: {
            const after = target[scheme_end + 3 ..];
            const slash = std.mem.indexOfScalar(u8, after, '/') orelse break :blk "/";
            break :blk after[slash..];
        } else target;
        const path = full_path[0 .. std.mem.indexOfScalar(u8, full_path, '?') orelse full_path.len];

        var output: [0]u8 = .{};
        var writer = stream.writer(std.testing.io, &output);
        for (self.routes) |route| {
            if (!std.mem.eql(u8, route.path, path)) continue;
            try writer.interface.print("HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", .{ route.content_type, route.body.len });
            try writer.interface.writeAll(route.body);
            try writer.interface.flush();
            return;
        }
        try writer.interface.writeAll("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n");
        try writer.interface.flush();
    }
};
