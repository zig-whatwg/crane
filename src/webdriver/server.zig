//! WebDriver HTTP Server
//!
//! Listens for WebDriver protocol requests and routes them to command handlers.

const std = @import("std");
const Allocator = std.mem.Allocator;
// Zig 0.16 moved networking onto std.Io: std.net became std.Io.net, and every
// socket call takes the Io. This server uses the process Io (src/platform/host.zig),
// which main adopts from std.start.
const net = std.Io.net;
const host = @import("host");
const protocol = @import("protocol.zig");
const commands = @import("commands.zig");
const SessionManager = @import("session.zig").SessionManager;

/// The largest request head this server reads before giving up.
const max_head_bytes = 8192;
/// The largest request body it accepts; a larger Content-Length gets a 413.
const max_body_bytes = 65536;

/// WebDriver Server Configuration
pub const Config = struct {
    /// Port to listen on (default: 9515)
    port: u16 = 9515,
    /// Host to bind to (default: 127.0.0.1)
    host: []const u8 = "127.0.0.1",
};

/// WebDriver HTTP Server
pub const Server = struct {
    allocator: Allocator,
    config: Config,
    sessions: SessionManager,
    running: bool,
    server: ?net.Server,

    /// Initialize the WebDriver server
    pub fn init(allocator: Allocator, config: Config) Server {
        return .{
            .allocator = allocator,
            .config = config,
            .sessions = SessionManager.init(allocator),
            .running = false,
            .server = null,
        };
    }

    /// Clean up server resources
    pub fn deinit(self: *Server) void {
        self.stop();
        self.sessions.deinit();
    }

    /// Start the server and listen for connections
    pub fn run(self: *Server) !void {
        const io = host.io();
        const address = try net.IpAddress.parseIp4(self.config.host, self.config.port);

        self.server = try address.listen(io, .{
            .reuse_address = true,
        });
        defer {
            if (self.server) |*s| s.deinit(io);
            self.server = null;
        }

        self.running = true;
        std.log.info("WebDriver server listening on {s}:{d}", .{ self.config.host, self.config.port });

        while (self.running) {
            // accept blocks until a client connects.
            const stream = self.server.?.accept(io) catch |err| {
                std.log.err("Accept error: {}", .{err});
                continue;
            };
            defer stream.close(io);

            // Handle the request
            self.handleConnection(io, stream) catch |err| {
                std.log.err("Request handling error: {}", .{err});
            };
        }
    }

    /// Stop the server
    pub fn stop(self: *Server) void {
        self.running = false;
    }

    /// Handle a single HTTP connection
    fn handleConnection(self: *Server, io: std.Io, stream: net.Stream) !void {
        // One buffer for the whole request: the head, then its body. Nothing is
        // consumed from it, so the reader never moves what it holds and the
        // slices parseHttpRequest returns stay valid.
        var buf: [max_head_bytes + max_body_bytes]u8 = undefined;
        var reader = stream.reader(io, &buf);

        // Read until the end of the request head.
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            if (reader.interface.bufferedLen() >= max_head_bytes) {
                std.log.warn("Request head larger than {d} bytes", .{max_head_bytes});
                return;
            }
            reader.interface.fillMore() catch |err| {
                // EndOfStream before a complete head: the client went away.
                if (err != error.EndOfStream) std.log.warn("Failed to read request: {}", .{err});
                return;
            };
        }

        // Parse HTTP request line and headers
        const parsed = parseHttpRequest(reader.interface.buffered()) orelse {
            std.log.warn("Failed to parse HTTP request", .{});
            return;
        };

        // Read body if Content-Length header present
        var body: []const u8 = "";
        if (parsed.content_length) |len| {
            if (len > max_body_bytes) {
                try self.sendRawResponse(io, stream, 413, "Request too large");
                return;
            }
            // The body may be partly or wholly in what was read with the head.
            reader.interface.fill(parsed.header_end + len) catch |err| {
                std.log.warn("Failed to read body: {}", .{err});
                return;
            };
            body = reader.interface.buffered()[parsed.header_end..][0..len];
        }

        // Log request
        std.log.debug("{s} {s}", .{ @tagName(parsed.method), parsed.path });

        // Route to command handler
        const result = commands.handleCommand(.{
            .allocator = self.allocator,
            .sessions = &self.sessions,
            .method = parsed.method,
            .path = parsed.path,
            .body = body,
        }) catch |err| {
            std.log.err("Command handler error: {}", .{err});
            try self.sendRawResponse(io, stream, 500, "{\"value\":{\"error\":\"unknown error\",\"message\":\"Internal error\"}}");
            return;
        };
        defer self.allocator.free(result.body);

        // Send response
        try self.sendRawResponse(io, stream, @backingInt(result.status), result.body);
    }

    /// Parse HTTP request (simple implementation)
    fn parseHttpRequest(data: []const u8) ?struct {
        method: std.http.Method,
        path: []const u8,
        content_length: ?usize,
        header_end: usize,
    } {
        // Find end of headers
        const header_end_marker = "\r\n\r\n";
        const header_end_pos = std.mem.indexOf(u8, data, header_end_marker) orelse return null;
        const header_end = header_end_pos + header_end_marker.len;

        // Parse request line
        const first_line_end = std.mem.indexOf(u8, data, "\r\n") orelse return null;
        const request_line = data[0..first_line_end];

        // Split request line: "METHOD PATH HTTP/1.1"
        var parts = std.mem.splitScalar(u8, request_line, ' ');
        const method_str = parts.next() orelse return null;
        const path = parts.next() orelse return null;

        // Parse method
        const method: std.http.Method = if (std.mem.eql(u8, method_str, "GET"))
            .GET
        else if (std.mem.eql(u8, method_str, "POST"))
            .POST
        else if (std.mem.eql(u8, method_str, "DELETE"))
            .DELETE
        else if (std.mem.eql(u8, method_str, "PUT"))
            .PUT
        else
            return null;

        // Parse Content-Length header
        var content_length: ?usize = null;
        const headers = data[first_line_end + 2 .. header_end_pos];
        var header_lines = std.mem.splitSequence(u8, headers, "\r\n");
        while (header_lines.next()) |line| {
            if (std.ascii.startsWithIgnoreCase(line, "content-length:")) {
                const value = std.mem.trim(u8, line["content-length:".len..], " ");
                content_length = std.fmt.parseInt(usize, value, 10) catch null;
                break;
            }
        }

        return .{
            .method = method,
            .path = path,
            .content_length = content_length,
            .header_end = header_end,
        };
    }

    /// Send raw HTTP response
    fn sendRawResponse(self: *Server, io: std.Io, stream: net.Stream, status_code: u16, body: []const u8) !void {
        _ = self;
        const status_text = switch (status_code) {
            200 => "OK",
            400 => "Bad Request",
            404 => "Not Found",
            413 => "Payload Too Large",
            500 => "Internal Server Error",
            else => "Unknown",
        };

        var response_buf: [256]u8 = undefined;
        var writer = stream.writer(io, &response_buf);
        // A client that has gone away gets nothing more; that is not an error
        // of this server's.
        writer.interface.print("HTTP/1.1 {d} {s}\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{ status_code, status_text, body.len }) catch return;
        writer.interface.writeAll(body) catch return;
        writer.interface.flush() catch return;
    }
};
