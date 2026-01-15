//! WebDriver HTTP Server
//!
//! Listens for WebDriver protocol requests and routes them to command handlers.

const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;
const protocol = @import("protocol.zig");
const commands = @import("commands.zig");
const SessionManager = @import("session.zig").SessionManager;

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
        const address = try net.Address.parseIp4(self.config.host, self.config.port);

        self.server = try address.listen(.{
            .reuse_address = true,
        });
        defer {
            if (self.server) |*s| s.deinit();
            self.server = null;
        }

        self.running = true;
        std.log.info("WebDriver server listening on {s}:{d}", .{ self.config.host, self.config.port });

        while (self.running) {
            // Accept connection with timeout
            const conn = self.server.?.accept() catch |err| {
                if (err == error.WouldBlock) {
                    std.Thread.sleep(10 * std.time.ns_per_ms);
                    continue;
                }
                std.log.err("Accept error: {}", .{err});
                continue;
            };
            defer conn.stream.close();

            // Handle the request
            self.handleConnection(conn.stream) catch |err| {
                std.log.err("Request handling error: {}", .{err});
            };
        }
    }

    /// Stop the server
    pub fn stop(self: *Server) void {
        self.running = false;
    }

    /// Handle a single HTTP connection
    fn handleConnection(self: *Server, stream: net.Stream) !void {
        var buf: [8192]u8 = undefined;
        var body_buf: [65536]u8 = undefined;

        // Read HTTP request (simple parsing)
        const bytes_read = stream.read(&buf) catch |err| {
            std.log.warn("Failed to read request: {}", .{err});
            return;
        };
        if (bytes_read == 0) return;

        const request_data = buf[0..bytes_read];

        // Parse HTTP request line and headers
        const parsed = parseHttpRequest(request_data) orelse {
            std.log.warn("Failed to parse HTTP request", .{});
            return;
        };

        // Read body if Content-Length header present
        var body: []const u8 = "";
        if (parsed.content_length) |len| {
            if (len > body_buf.len) {
                try self.sendRawResponse(stream, 413, "Request too large");
                return;
            }

            // Body may be partially in the initial read
            const header_end = parsed.header_end;
            const body_in_buf = request_data.len - header_end;

            if (body_in_buf >= len) {
                // Body already fully read
                body = request_data[header_end..][0..len];
            } else {
                // Need to read more body data
                @memcpy(body_buf[0..body_in_buf], request_data[header_end..]);
                const remaining = len - body_in_buf;
                const more_read = stream.read(body_buf[body_in_buf..][0..remaining]) catch |err| {
                    std.log.warn("Failed to read body: {}", .{err});
                    return;
                };
                body = body_buf[0 .. body_in_buf + more_read];
            }
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
            try self.sendRawResponse(stream, 500, "{\"value\":{\"error\":\"unknown error\",\"message\":\"Internal error\"}}");
            return;
        };
        defer self.allocator.free(result.body);

        // Send response
        try self.sendRawResponse(stream, @intFromEnum(result.status), result.body);
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
    fn sendRawResponse(self: *Server, stream: net.Stream, status_code: u16, body: []const u8) !void {
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
        const header = std.fmt.bufPrint(&response_buf, "HTTP/1.1 {d} {s}\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{ status_code, status_text, body.len }) catch return error.BufferOverflow;

        _ = stream.write(header) catch return;
        _ = stream.write(body) catch return;
    }
};
