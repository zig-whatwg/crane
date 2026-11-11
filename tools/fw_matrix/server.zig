//! The static HTTP server a run serves a framework's tree with, on
//! 127.0.0.1: the role the project's own test server plays for its static
//! files (jquery-test-runner, web-test-runner), nothing more - no response a
//! test asserts on is invented here. A path below the root answers its file;
//! a directory its index.html; anything else 404. PHP is never run: a `.php`
//! path answers 404 saying so (jQuery's mock.php actions are ruling R4's
//! "needs the project's test server", and those tests are not run).
//!
//! The shape is tools/perf_bench/server.zig's (a thread per connection,
//! keep-alive, a stop that wakes its accept), without its cross-origin
//! isolation headers: the projects' own servers send none, and htmx's page
//! loads its test libraries from unpkg.com, which COEP require-corp would
//! block.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Options = struct {
    root: []const u8,
    /// 0: the kernel picks.
    port: u16 = 0,
};

/// The largest file served.
pub const max_file = 256 * 1024 * 1024;

pub const Server = struct {
    gpa: Allocator,
    io: Io,
    root: Io.Dir,
    listener: Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    active: std.atomic.Value(u32) = .init(0),
    requests: std.atomic.Value(u64) = .init(0),

    pub fn start(gpa: Allocator, io: Io, options: Options) !*Server {
        const self = try gpa.create(Server);
        errdefer gpa.destroy(self);
        var root = try Io.Dir.cwd().openDir(io, options.root, .{});
        errdefer root.close(io);
        const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(options.port) };
        self.* = .{
            .gpa = gpa,
            .io = io,
            .root = root,
            .listener = try address.listen(io, .{ .reuse_address = true }),
        };
        errdefer self.listener.deinit(io);
        self.thread = try std.Thread.spawn(.{}, acceptLoop, .{self});
        return self;
    }

    pub fn port(self: *const Server) u16 {
        return self.listener.socket.address.getPort();
    }

    /// Stop accepting (a connection of its own wakes the accept), join the
    /// accept thread, close the listener, and wait for the connections
    /// being answered.
    pub fn stop(self: *Server) void {
        self.stopping.store(true, .release);
        const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(self.port()) };
        const wake: ?Io.net.Stream = address.connect(self.io, .{ .mode = .stream }) catch null;
        self.thread.?.join();
        self.listener.deinit(self.io);
        if (wake) |w| w.close(self.io);
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.root.close(self.io);
        self.gpa.destroy(self);
    }

    fn acceptLoop(self: *Server) void {
        while (!self.stopping.load(.acquire)) {
            const stream = self.listener.accept(self.io) catch continue;
            if (self.stopping.load(.acquire)) {
                stream.close(self.io);
                break;
            }
            _ = self.active.fetchAdd(1, .acq_rel);
            const t = std.Thread.spawn(.{}, serveConnection, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(self.io);
                continue;
            };
            t.detach();
        }
    }

    fn serveConnection(self: *Server, stream: Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(self.io);
        // A page URL carries the exclusion filter in its query: heads of
        // tens of kilobytes.
        const in_buf = self.gpa.alloc(u8, 128 * 1024) catch return;
        defer self.gpa.free(in_buf);
        var out_buf: [16 * 1024]u8 = undefined;
        var reader = stream.reader(self.io, in_buf);
        var writer = stream.writer(self.io, &out_buf);
        var http: std.http.Server = .init(&reader.interface, &writer.interface);
        while (!self.stopping.load(.acquire)) {
            var request = http.receiveHead() catch return;
            _ = self.requests.fetchAdd(1, .monotonic);
            const keep_alive = request.head.keep_alive;
            self.answer(&request) catch return;
            if (!keep_alive) return;
        }
    }

    const no_store = [_]std.http.Header{.{ .name = "cache-control", .value = "no-store" }};

    fn answer(self: *Server, request: *std.http.Server.Request) !void {
        const target = try self.gpa.dupe(u8, request.head.target);
        defer self.gpa.free(target);
        const path = target[0 .. std.mem.indexOfAny(u8, target, "?#") orelse target.len];
        if (request.head.method != .GET and request.head.method != .HEAD) return self.respondText(request, .method_not_allowed, "method not allowed: a static server\n");
        if (std.mem.eql(u8, path, "/favicon.ico")) return request.respond("", .{ .status = .no_content, .extra_headers = &no_store });
        var decoded_buf: [4096]u8 = undefined;
        const rel = decodePath(path, &decoded_buf) orelse return self.respondText(request, .not_found, "not found\n");
        if (std.mem.endsWith(u8, rel, ".php")) return self.respondText(request, .not_found, "not found: PHP is not run here (the project's test server is not built: ruling R4)\n");
        return self.serveFile(request, rel);
    }

    fn serveFile(self: *Server, request: *std.http.Server.Request, rel: []const u8) !void {
        const file_path = if (rel.len == 0 or rel[rel.len - 1] == '/')
            try std.fmt.allocPrint(self.gpa, "{s}index.html", .{rel})
        else
            try self.gpa.dupe(u8, rel);
        defer self.gpa.free(file_path);
        const bytes = self.root.readFileAlloc(self.io, file_path, self.gpa, .limited(max_file)) catch |err| switch (err) {
            error.IsDir => {
                const index = try std.fmt.allocPrint(self.gpa, "{s}/index.html", .{file_path});
                defer self.gpa.free(index);
                const b = self.root.readFileAlloc(self.io, index, self.gpa, .limited(max_file)) catch return self.respondText(request, .not_found, "not found\n");
                defer self.gpa.free(b);
                return self.respondBytes(request, b, "text/html; charset=utf-8");
            },
            else => return self.respondText(request, .not_found, "not found\n"),
        };
        defer self.gpa.free(bytes);
        return self.respondBytes(request, bytes, contentType(file_path));
    }

    /// RFC 9110 6.6.1: an origin server with a clock sends Date (jQuery's
    /// "jQuery.ajax() - HEAD requests" asserts one; its own test server,
    /// Node's http module, sends it).
    fn now(self: *Server, buf: *[29]u8) []const u8 {
        const secs = Io.Timestamp.now(self.io, .real).toSeconds();
        return httpDate(buf, @intCast(@max(0, secs)));
    }

    fn respondBytes(self: *Server, request: *std.http.Server.Request, bytes: []const u8, content_type: []const u8) !void {
        var date: [29]u8 = undefined;
        const hs = [_]std.http.Header{ no_store[0], .{ .name = "content-type", .value = content_type }, .{ .name = "date", .value = self.now(&date) } };
        return request.respond(bytes, .{ .extra_headers = &hs });
    }

    fn respondText(self: *Server, request: *std.http.Server.Request, status: std.http.Status, text: []const u8) !void {
        var date: [29]u8 = undefined;
        const hs = [_]std.http.Header{ no_store[0], .{ .name = "content-type", .value = "text/plain; charset=utf-8" }, .{ .name = "date", .value = self.now(&date) } };
        return request.respond(text, .{ .status = status, .extra_headers = &hs });
    }
};

/// A request path, percent-decoded, made relative to the root; null when it
/// would leave the root (a `..` or `.` segment, an empty one, a backslash, a
/// NUL), is not a path, or does not fit `buf`.
pub fn decodePath(path: []const u8, buf: []u8) ?[]const u8 {
    if (path.len == 0 or path[0] != '/') return null;
    var n: usize = 0;
    var i: usize = 1;
    while (i < path.len) : (i += 1) {
        if (n == buf.len) return null;
        var c = path[i];
        if (c == '%') {
            if (i + 2 >= path.len) return null;
            c = std.fmt.parseInt(u8, path[i + 1 .. i + 3], 16) catch return null;
            i += 2;
        }
        if (c == 0 or c == '\\') return null;
        buf[n] = c;
        n += 1;
    }
    const rel = buf[0..n];
    var it = std.mem.splitScalar(u8, rel, '/');
    var index: usize = 0;
    while (it.next()) |seg| : (index += 1) {
        if (std.mem.eql(u8, seg, "..") or std.mem.eql(u8, seg, ".")) return null;
        // An empty segment is allowed only as the last (a directory's slash).
        if (seg.len == 0 and it.peek() != null) return null;
    }
    return rel;
}

/// RFC 9110 5.6.7 IMF-fixdate: "Sun, 06 Nov 1994 08:49:37 GMT".
pub fn httpDate(buf: *[29]u8, unix_seconds: u64) []const u8 {
    const es: std.time.epoch.EpochSeconds = .{ .secs = unix_seconds };
    const day = es.getEpochDay();
    const yd = day.calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();
    const days = [_][]const u8{ "Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed" }; // 1970-01-01 was a Thursday
    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    return std.fmt.bufPrint(buf, "{s}, {d:0>2} {s} {d} {d:0>2}:{d:0>2}:{d:0>2} GMT", .{
        days[day.day % 7], @as(u32, md.day_index) + 1, months[@backingInt(md.month) - 1], yd.year, ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute(),
    }) catch unreachable;
}

pub fn contentType(path: []const u8) []const u8 {
    const ext = std.fs.path.extension(path);
    const types = [_][2][]const u8{
        .{ ".html", "text/html; charset=utf-8" },
        .{ ".htm", "text/html; charset=utf-8" },
        .{ ".xhtml", "application/xhtml+xml" },
        .{ ".js", "text/javascript; charset=utf-8" },
        .{ ".cjs", "text/javascript; charset=utf-8" },
        .{ ".mjs", "text/javascript; charset=utf-8" },
        .{ ".css", "text/css; charset=utf-8" },
        .{ ".json", "application/json" },
        .{ ".map", "application/json" },
        .{ ".xml", "application/xml" },
        .{ ".svg", "image/svg+xml" },
        .{ ".txt", "text/plain; charset=utf-8" },
        .{ ".png", "image/png" },
        .{ ".gif", "image/gif" },
        .{ ".jpg", "image/jpeg" },
        .{ ".jpeg", "image/jpeg" },
        .{ ".ico", "image/x-icon" },
        .{ ".woff", "font/woff" },
        .{ ".woff2", "font/woff2" },
        .{ ".wasm", "application/wasm" },
    };
    for (types) |t| if (std.ascii.eqlIgnoreCase(ext, t[0])) return t[1];
    return "application/octet-stream";
}

const testing = std.testing;

test "httpDate: RFC 9110's example, and a leap day" {
    var buf: [29]u8 = undefined;
    try testing.expectEqualStrings("Sun, 06 Nov 1994 08:49:37 GMT", httpDate(&buf, 784111777));
    try testing.expectEqualStrings("Thu, 29 Feb 2024 00:00:00 GMT", httpDate(&buf, 1709164800));
}

test "decodePath: below the root only; percent-decoded" {
    var buf: [256]u8 = undefined;
    try testing.expectEqualStrings("test/index.html", decodePath("/test/index.html", &buf).?);
    try testing.expectEqualStrings("", decodePath("/", &buf).?);
    try testing.expectEqualStrings("test/", decodePath("/test/", &buf).?);
    try testing.expectEqualStrings("test/data/a b.html", decodePath("/test/data/a%20b.html", &buf).?);
    try testing.expectEqual(@as(?[]const u8, null), decodePath("/../etc/passwd", &buf));
    try testing.expectEqual(@as(?[]const u8, null), decodePath("/a/%2e%2e/b", &buf));
    try testing.expectEqual(@as(?[]const u8, null), decodePath("//etc", &buf));
    try testing.expectEqual(@as(?[]const u8, null), decodePath("/a%00", &buf));
    try testing.expectEqual(@as(?[]const u8, null), decodePath("/a%2", &buf));
    try testing.expectEqual(@as(?[]const u8, null), decodePath("a.html", &buf));
    try testing.expectEqualStrings("application/xml", contentType("data/dashboard.xml"));
    try testing.expectEqualStrings("text/javascript; charset=utf-8", contentType("src/htmx.js"));
}

/// One request on a connection of its own; the whole response.
fn fetchRaw(gpa: Allocator, port_number: u16, request: []const u8) ![]u8 {
    const io = testing.io;
    const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(port_number) };
    const stream = try address.connect(io, .{ .mode = .stream });
    defer stream.close(io);
    var wbuf: [1024]u8 = undefined;
    var writer = stream.writer(io, &wbuf);
    try writer.interface.writeAll(request);
    try writer.interface.flush();
    var rbuf: [64 * 1024]u8 = undefined;
    var reader = stream.reader(io, &rbuf);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    while (true) {
        reader.interface.fillMore() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        try out.appendSlice(gpa, reader.interface.buffered());
        reader.interface.toss(reader.interface.buffered().len);
    }
    return out.toOwnedSlice(gpa);
}

test "the server: a file, a directory's index, a long query, PHP refused, POST refused, a 404" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "test/data");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "test/index.html", .data = "<!doctype html><p>hi" });
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "test/data/mock.php", .data = "<?php echo 1;" });
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    const server = try Server.start(testing.allocator, testing.io, .{ .root = root });
    defer server.stop();

    const long_query_bytes: [20000]u8 = @splat('x');
    const long_query = &long_query_bytes;
    const page = try fetchRaw(testing.allocator, server.port(), "GET /test/index.html?module=css&filter=" ++ long_query ++ " HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(page);
    try testing.expect(std.mem.startsWith(u8, page, "HTTP/1.1 200 OK\r\n"));
    try testing.expect(std.mem.indexOf(u8, page, "content-type: text/html; charset=utf-8\r\n") != null);
    try testing.expect(std.mem.indexOf(u8, page, "cross-origin-embedder-policy") == null);
    try testing.expect(std.mem.indexOf(u8, page, " GMT\r\n") != null and std.mem.indexOf(u8, page, "date: ") != null);
    try testing.expect(std.mem.endsWith(u8, page, "<!doctype html><p>hi"));

    const dir = try fetchRaw(testing.allocator, server.port(), "GET /test HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(dir);
    try testing.expect(std.mem.endsWith(u8, dir, "<!doctype html><p>hi"));

    const php = try fetchRaw(testing.allocator, server.port(), "GET /test/data/mock.php?action=json HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(php);
    try testing.expect(std.mem.startsWith(u8, php, "HTTP/1.1 404 Not Found\r\n"));
    try testing.expect(std.mem.indexOf(u8, php, "<?php") == null);

    const post = try fetchRaw(testing.allocator, server.port(), "POST /test/index.html HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(post);
    try testing.expect(std.mem.startsWith(u8, post, "HTTP/1.1 405 Method Not Allowed\r\n"));

    const missing = try fetchRaw(testing.allocator, server.port(), "GET /../secret HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(missing);
    try testing.expect(std.mem.startsWith(u8, missing, "HTTP/1.1 404 Not Found\r\n"));
}
