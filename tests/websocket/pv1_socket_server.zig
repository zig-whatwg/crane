//! One loopback WebSocket peer for lifetime tests. No external WPT server.
const std = @import("std");
const io = std.testing.io;

pub const Server = struct {
    listener: std.Io.net.Server,
    thread: ?std.Thread = null,
    close_code: std.atomic.Value(u16) = .init(0),
    ended: std.atomic.Value(bool) = .init(false),
    failure: ?anyerror = null,

    pub fn start(self: *Server) !void {
        const address: std.Io.net.IpAddress = .{ .ip4 = .loopback(0) };
        self.* = .{ .listener = try address.listen(io, .{ .reuse_address = true }) };
        errdefer self.listener.deinit(io);
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
    }

    pub fn url(self: *const Server, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "ws://127.0.0.1:{d}/echo", .{self.listener.socket.address.getPort()});
    }

    /// The Browser must end first, closing any accepted socket.
    pub fn stop(self: *Server) void {
        self.listener.deinit(io);
        if (self.thread) |thread| thread.join();
    }

    fn serve(self: *Server) void {
        defer self.ended.store(true, .release);
        self.answer() catch |err| {
            self.failure = err;
        };
    }

    fn answer(self: *Server) !void {
        // stop closes the listener; accept reads its own copy.
        var listener = self.listener;
        const stream = try listener.accept(io);
        defer stream.close(io);
        var input: [8192]u8 = undefined;
        var reader = stream.reader(io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const header_end = std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n").? + 4;
        const headers = try reader.interface.take(header_end);
        var key: ?[]const u8 = null;
        var lines = std.mem.splitSequence(u8, headers, "\r\n");
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(line[0..colon], "Sec-WebSocket-Key")) key = std.mem.trim(u8, line[colon + 1 ..], " \t");
        }
        // RFC6455 4.2.2: Accept authenticates this opening handshake.
        var hash = std.crypto.hash.Sha1.init(.{});
        hash.update(key orelse return error.NoKey);
        hash.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
        var digest: [20]u8 = undefined;
        hash.final(&digest);
        var encoded: [28]u8 = undefined;
        const accept = std.base64.standard.Encoder.encode(&encoded, &digest);
        var output: [0]u8 = .{};
        var writer = stream.writer(io, &output);
        try writer.interface.print("HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Accept: {s}\r\n\r\n", .{accept});
        try writer.interface.flush();
        while (true) {
            const first = try reader.interface.takeByte();
            const second = try reader.interface.takeByte();
            // Tests send short, complete client frames (RFC6455 5.2/5.3).
            if (first & 0x80 == 0 or second & 0x80 == 0 or second & 0x7f > 125) return error.UnexpectedTestFrame;
            const len: usize = second & 0x7f;
            var mask: [4]u8 = undefined;
            try reader.interface.readSliceAll(&mask);
            var payload: [125]u8 = undefined;
            try reader.interface.readSliceAll(payload[0..len]);
            for (payload[0..len], 0..) |*byte, i| byte.* ^= mask[i % 4];
            const opcode = first & 0xf;
            if (opcode != 1 and opcode != 8) return error.UnexpectedTestOpcode;
            if (opcode == 8) self.close_code.store(if (len >= 2) std.mem.readInt(u16, payload[0..2], .big) else 1005, .release);
            // A disappearing Browser can close TCP before reading our echo.
            writer.interface.writeAll(&.{ first, @intCast(len) }) catch |err| {
                if (opcode == 8) return;
                return err;
            };
            writer.interface.writeAll(payload[0..len]) catch |err| {
                if (opcode == 8) return;
                return err;
            };
            writer.interface.flush() catch |err| {
                if (opcode == 8) return;
                return err;
            };
            if (opcode == 8) return;
        }
    }
};
