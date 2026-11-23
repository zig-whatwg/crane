//! A loopback HTTP site for lane cdpt2's Network and Fetch tests: JSON, an
//! image, a Basic-auth protected page, and an echo of a POST. One request per
//! connection (`Connection: close`), each answered on a thread of its own,
//! over tests/support/loopback_listener.zig - the shape of cdpr_replay.zig's
//! Site.

const std = @import("std");
const Allocator = std.mem.Allocator;
const LoopbackListener = @import("loopback_listener").LoopbackListener;

pub const json_body = "{\"from\":\"network\"}";
/// A PNG's signature and IHDR start: bytes that are no UTF-8.
pub const image_body = "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR";
/// "u:p", as Basic credentials.
pub const credentials = "Basic dTpw";

pub const Site = struct {
    allocator: Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),

    pub fn start(allocator: Allocator) !*Site {
        const self = try allocator.create(Site);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    pub fn stop(self: *Site) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    /// `http://127.0.0.1:<port><path>`, into `buffer`.
    pub fn url(self: *const Site, buffer: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    fn serve(self: *Site) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, answerAndClose, .{ stream, self }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            thread.detach();
        }
    }

    fn answerAndClose(stream: std.Io.net.Stream, self: *Site) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        answer(stream) catch {};
    }

    fn headerValue(head: []const u8, name: []const u8) ?[]const u8 {
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        _ = lines.next();
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " "), name)) return std.mem.trim(u8, line[colon + 1 ..], " ");
        }
        return null;
    }

    fn answer(stream: std.Io.net.Stream) !void {
        var input: [16384]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const buffered = reader.interface.buffered();
        const head_end = std.mem.indexOf(u8, buffered, "\r\n\r\n").? + 4;
        const head = buffered[0..head_end];
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const target = parts.next() orelse return;
        const path = if (std.mem.indexOfScalar(u8, target, '?')) |q| target[0..q] else target;
        // A POST's body, by its Content-Length.
        var body_storage: [4096]u8 = undefined;
        var request_body: []const u8 = "";
        if (headerValue(head, "content-length")) |text| {
            const length = std.fmt.parseInt(usize, text, 10) catch 0;
            while (reader.interface.buffered().len < head_end + length) try reader.interface.fillMore();
            const all = reader.interface.buffered();
            const n = @min(length, body_storage.len);
            @memcpy(body_storage[0..n], all[head_end .. head_end + n]);
            request_body = body_storage[0..n];
        }
        const Page = struct { status: u16 = 200, reason: []const u8 = "OK", content_type: []const u8 = "text/plain", body: []const u8, extra: []const u8 = "" };
        const page: Page = if (std.mem.eql(u8, path, "/data.json"))
            .{ .content_type = "application/json", .body = json_body }
        else if (std.mem.eql(u8, path, "/image.png"))
            .{ .content_type = "image/png", .body = image_body }
        else if (std.mem.eql(u8, path, "/auth"))
            (if (headerValue(head, "authorization")) |given|
                (if (std.mem.eql(u8, given, credentials)) Page{ .body = "welcome" } else Page{ .status = 401, .reason = "Unauthorized", .body = "denied", .extra = "WWW-Authenticate: Basic realm=\"crane\"\r\n" })
            else
                Page{ .status = 401, .reason = "Unauthorized", .body = "denied", .extra = "WWW-Authenticate: Basic realm=\"crane\"\r\n" })
        else if (std.mem.eql(u8, path, "/echo"))
            .{ .body = request_body }
        else
            .{ .status = 404, .reason = "Not Found", .body = "not found" };
        var output: [8192]u8 = undefined;
        var writer = stream.writer(std.testing.io, &output);
        const out = &writer.interface;
        try out.print("HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nX-Site: cdpt2\r\n{s}Connection: close\r\n\r\n", .{
            page.status, page.reason, page.content_type, page.body.len, page.extra,
        });
        try out.writeAll(page.body);
        try out.flush();
    }
};
