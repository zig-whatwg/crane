//! The benchmark's HTTP server: tests/perf/ as static files on 127.0.0.1,
//! the loopback resources the fetch workloads read, and the mark endpoint
//! through which every page reports (docs/performance.md, "The harness").
//!
//! Every response is cross-origin isolated (COOP same-origin, COEP
//! require-corp, CORP same-origin): `crossOriginIsolated` then holds in every
//! engine that implements it, which gives performance.now() its finest
//! resolution (HTML "coarsen time": 5 us isolated, 100 us otherwise, in
//! Chrome; Firefox and Safari likewise coarsen less when isolated), so a
//! sample's clock is not the noise. Nothing is cached (`no-store`): every
//! launch starts from a fresh profile anyway, and a page load measures the
//! network path every time.
//!
//! Routes:
//!   GET  /<path>                a file under the root; a `.gz` or `.br` file
//!                               as it is stored, with Content-Encoding gzip
//!                               or br (tests/perf/encoded/: bodies each engine
//!                               decodes)
//!   GET  /__perf/bytes?n=N      N bytes of text (loopback fetch, streams)
//!   GET  /__perf/json?n=N       a JSON array of N records
//!   POST /__perf/mark           a page's mark: the body goes to the sink,
//!                               which answers once it has sampled the engine
//!   GET  /favicon.ico           204, so no engine logs a 404 for it

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

/// Where marks go: the runner, which reads the engine's process set when a
/// mark arrives and answers after it has (so a page awaiting the answer is
/// idle while it is read).
pub const Sink = struct {
    ctx: *anyopaque,
    onMark: *const fn (ctx: *anyopaque, body: []const u8) void,
};

pub const Options = struct {
    root: []const u8,
    /// 0: the kernel picks.
    port: u16 = 0,
    sink: ?Sink = null,
};

/// The largest body /__perf/bytes serves, and the largest mark accepted.
pub const max_bytes = 64 * 1024 * 1024;
pub const max_mark = 4 * 1024 * 1024;

pub const Server = struct {
    gpa: Allocator,
    io: Io,
    root: Io.Dir,
    listener: Io.net.Server,
    sink: ?Sink,
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
            .sink = options.sink,
        };
        errdefer self.listener.deinit(io);
        self.thread = try std.Thread.spawn(.{}, acceptLoop, .{self});
        return self;
    }

    pub fn port(self: *const Server) u16 {
        return self.listener.socket.address.getPort();
    }

    /// Stop accepting, wake the accept thread with a connection of its own,
    /// join it, then close the listener (in that order: an accept() on a
    /// closed descriptor is a bug - tests/support/loopback_listener.zig), and
    /// wait for the connections being answered.
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
        var in_buf: [16 * 1024]u8 = undefined;
        var out_buf: [16 * 1024]u8 = undefined;
        var reader = stream.reader(self.io, &in_buf);
        var writer = stream.writer(self.io, &out_buf);
        var http: std.http.Server = .init(&reader.interface, &writer.interface);
        // Keep-alive: one request after another until the client closes.
        while (!self.stopping.load(.acquire)) {
            var request = http.receiveHead() catch return;
            _ = self.requests.fetchAdd(1, .monotonic);
            // Read before answering: answering invalidates the head.
            const keep_alive = request.head.keep_alive;
            self.answer(&request) catch return;
            // A client that asked to close (`Connection: close`) gets its
            // end of stream after the answer, not a read that waits forever.
            if (!keep_alive) return;
        }
    }

    const isolation = [_]std.http.Header{
        .{ .name = "cross-origin-opener-policy", .value = "same-origin" },
        .{ .name = "cross-origin-embedder-policy", .value = "require-corp" },
        .{ .name = "cross-origin-resource-policy", .value = "same-origin" },
        .{ .name = "cache-control", .value = "no-store" },
    };

    fn headers(comptime content_type: ?[]const u8) []const std.http.Header {
        if (content_type) |ct| return &(isolation ++ [_]std.http.Header{.{ .name = "content-type", .value = ct }});
        return &isolation;
    }

    fn answer(self: *Server, request: *std.http.Server.Request) !void {
        // The target's bytes are invalidated once the body is read: copy.
        var target_buf: [2048]u8 = undefined;
        if (request.head.target.len > target_buf.len) return respondStatus(request, .uri_too_long);
        const target = target_buf[0..request.head.target.len];
        @memcpy(target, request.head.target);
        const qmark = std.mem.indexOfScalar(u8, target, '?');
        const path = target[0 .. qmark orelse target.len];
        const query = if (qmark) |q| target[q + 1 ..] else "";

        if (request.head.method == .POST and std.mem.eql(u8, path, "/__perf/mark")) {
            if (request.head.expect != null) return respondStatus(request, .expectation_failed);
            var body_buf: [4096]u8 = undefined;
            const body_reader = request.readerExpectNone(&body_buf);
            const body = body_reader.allocRemaining(self.gpa, .limited(max_mark)) catch return respondStatus(request, .payload_too_large);
            defer self.gpa.free(body);
            if (self.sink) |sink| sink.onMark(sink.ctx, body);
            return request.respond("{}", .{ .extra_headers = comptime headers("application/json") });
        }
        if (request.head.method != .GET and request.head.method != .HEAD) return respondStatus(request, .method_not_allowed);
        if (std.mem.eql(u8, path, "/favicon.ico")) return request.respond("", .{ .status = .no_content, .extra_headers = comptime headers(null) });
        if (std.mem.eql(u8, path, "/__perf/bytes")) {
            const n = queryInt(query, "n") orelse return respondStatus(request, .bad_request);
            if (n > max_bytes) return respondStatus(request, .bad_request);
            return self.streamBytes(request, n);
        }
        if (std.mem.eql(u8, path, "/__perf/json")) {
            const n = queryInt(query, "n") orelse return respondStatus(request, .bad_request);
            if (n > 1_000_000) return respondStatus(request, .bad_request);
            const json = try jsonRecords(self.gpa, n);
            defer self.gpa.free(json);
            return request.respond(json, .{ .extra_headers = comptime headers("application/json") });
        }
        return self.serveFile(request, path);
    }

    /// `n` bytes of a repeating line of text, written in 64 KiB pieces.
    fn streamBytes(self: *Server, request: *std.http.Server.Request, n: u64) !void {
        _ = self;
        var buf: [64 * 1024]u8 = undefined;
        var body = try request.respondStreaming(&buf, .{
            .content_length = n,
            .respond_options = .{ .extra_headers = comptime headers("text/plain; charset=utf-8") },
        });
        var piece: [64 * 1024]u8 = undefined;
        fillText(&piece);
        var left = n;
        while (left > 0) {
            const k: usize = @intCast(@min(left, piece.len));
            try body.writer.writeAll(piece[0..k]);
            left -= k;
        }
        try body.end();
    }

    fn serveFile(self: *Server, request: *std.http.Server.Request, path: []const u8) !void {
        const rel = safeRelative(path) orelse return respondStatus(request, .not_found);
        const file_path = if (rel.len == 0 or rel[rel.len - 1] == '/') try std.fmt.allocPrint(self.gpa, "{s}index.html", .{rel}) else try self.gpa.dupe(u8, rel);
        defer self.gpa.free(file_path);
        const bytes = self.root.readFileAlloc(self.io, file_path, self.gpa, .limited(64 * 1024 * 1024)) catch return respondStatus(request, .not_found);
        defer self.gpa.free(bytes);
        // A precompressed file: its type is the name's without the coding's
        // extension, and the coding is sent for the engine to undo.
        const coding = contentEncoding(file_path);
        const typed_path = if (coding != null) file_path[0 .. file_path.len - std.fs.path.extension(file_path).len] else file_path;
        var hs: [isolation.len + 2]std.http.Header = undefined;
        @memcpy(hs[0..isolation.len], &isolation);
        hs[isolation.len] = .{ .name = "content-type", .value = contentType(typed_path) };
        var count: usize = isolation.len + 1;
        if (coding) |c| {
            hs[count] = .{ .name = "content-encoding", .value = c };
            count += 1;
        }
        return request.respond(bytes, .{ .extra_headers = hs[0..count] });
    }

    fn respondStatus(request: *std.http.Server.Request, status: std.http.Status) !void {
        return request.respond(status.phrase() orelse "", .{ .status = status, .extra_headers = comptime headers("text/plain; charset=utf-8") });
    }
};

/// A request path made relative to the root, or null when it would leave it
/// (`..`, a backslash, a NUL) or is percent-encoded (no page here needs it).
pub fn safeRelative(path: []const u8) ?[]const u8 {
    if (path.len == 0 or path[0] != '/') return null;
    const rel = path[1..];
    if (std.mem.indexOf(u8, rel, "..") != null) return null;
    for (rel) |c| if (c == '\\' or c == 0 or c == '%') return null;
    if (rel.len > 0 and rel[0] == '/') return null;
    return rel;
}

pub fn contentType(path: []const u8) []const u8 {
    const ext = std.fs.path.extension(path);
    const types = [_][2][]const u8{
        .{ ".html", "text/html; charset=utf-8" },
        .{ ".js", "text/javascript; charset=utf-8" },
        .{ ".mjs", "text/javascript; charset=utf-8" },
        .{ ".css", "text/css; charset=utf-8" },
        .{ ".json", "application/json" },
        .{ ".svg", "image/svg+xml" },
        .{ ".txt", "text/plain; charset=utf-8" },
        .{ ".png", "image/png" },
    };
    for (types) |t| if (std.ascii.eqlIgnoreCase(ext, t[0])) return t[1];
    return "application/octet-stream";
}

/// The content coding a file is stored in, from its last extension: `.gz`
/// gzip, `.br` br (RFC 9110 8.4.1), or none.
pub fn contentEncoding(path: []const u8) ?[]const u8 {
    const ext = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(ext, ".gz")) return "gzip";
    if (std.ascii.eqlIgnoreCase(ext, ".br")) return "br";
    return null;
}

/// The decimal value of `key` in a query string.
pub fn queryInt(query: []const u8, key: []const u8) ?u64 {
    var it = std.mem.splitScalar(u8, query, '&');
    while (it.next()) |pair| {
        const eq = std.mem.indexOfScalar(u8, pair, '=') orelse continue;
        if (!std.mem.eql(u8, pair[0..eq], key)) continue;
        return std.fmt.parseInt(u64, pair[eq + 1 ..], 10) catch null;
    }
    return null;
}

/// A repeating line of printable text (so a TextDecoder has real work).
pub fn fillText(buf: []u8) void {
    const line = "The quick brown fox jumps over the lazy dog 0123456789.\n";
    for (buf, 0..) |*b, i| b.* = line[i % line.len];
}

/// `[{"id":0,"name":"item 0","price":0.5,"tags":["a","b"],"active":true},...]`,
/// the same bytes for the same n.
pub fn jsonRecords(gpa: Allocator, n: u64) ![]u8 {
    var out: Io.Writer.Allocating = .init(gpa);
    errdefer out.deinit();
    const w = &out.writer;
    try w.writeByte('[');
    var i: u64 = 0;
    while (i < n) : (i += 1) {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"name\":\"item {d}\",\"price\":{d}.{d:0>2},\"tags\":[\"t{d}\",\"t{d}\"],\"active\":{s}}}", .{
            i, i, (i * 37) % 1000, (i * 13) % 100, i % 7, i % 11, if (i % 3 == 0) "false" else "true",
        });
    }
    try w.writeByte(']');
    return out.toOwnedSlice();
}

const testing = std.testing;

test "paths: only below the root, never percent-encoded" {
    try testing.expectEqualStrings("a/b.html", safeRelative("/a/b.html").?);
    try testing.expectEqualStrings("", safeRelative("/").?);
    try testing.expectEqual(@as(?[]const u8, null), safeRelative("/../etc/passwd"));
    try testing.expectEqual(@as(?[]const u8, null), safeRelative("/a/%2e%2e/b"));
    try testing.expectEqual(@as(?[]const u8, null), safeRelative("//etc"));
    try testing.expectEqual(@as(?[]const u8, null), safeRelative("a.html"));
}

test "content types and query integers" {
    try testing.expectEqualStrings("text/html; charset=utf-8", contentType("x/y.html"));
    try testing.expectEqualStrings("text/javascript; charset=utf-8", contentType("harness.js"));
    try testing.expectEqualStrings("application/octet-stream", contentType("x.bin"));
    try testing.expectEqualStrings("gzip", contentEncoding("encoded/text-1m.html.gz").?);
    try testing.expectEqualStrings("br", contentEncoding("encoded/text-1m.html.br").?);
    try testing.expectEqual(@as(?[]const u8, null), contentEncoding("encoded/text-1m.html"));
    try testing.expectEqual(@as(?u64, 1024), queryInt("a=1&n=1024", "n"));
    try testing.expectEqual(@as(?u64, null), queryInt("n=x", "n"));
    try testing.expectEqual(@as(?u64, null), queryInt("", "n"));
}

test "json records are valid JSON, the same for the same n" {
    const a = try jsonRecords(testing.allocator, 3);
    defer testing.allocator.free(a);
    const b = try jsonRecords(testing.allocator, 3);
    defer testing.allocator.free(b);
    try testing.expectEqualStrings(a, b);
    const parsed = try std.json.parseFromSlice(std.json.Value, testing.allocator, a, .{});
    defer parsed.deinit();
    try testing.expectEqual(@as(usize, 3), parsed.value.array.items.len);
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

const TestSink = struct {
    got: std.ArrayList(u8) = .empty,
    marks: u32 = 0,
    fn onMark(ctx: *anyopaque, body: []const u8) void {
        const self: *TestSink = @ptrCast(@alignCast(ctx));
        self.got.appendSlice(testing.allocator, body) catch {};
        self.marks += 1;
    }
};

test "the server: a file, isolation headers, loopback bytes, a mark, a 404" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "page.html", .data = "<!doctype html><p>hi" });
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);

    var sink: TestSink = .{};
    defer sink.got.deinit(testing.allocator);
    const server = try Server.start(testing.allocator, testing.io, .{ .root = root, .sink = .{ .ctx = &sink, .onMark = TestSink.onMark } });
    defer server.stop();

    const page = try fetchRaw(testing.allocator, server.port(), "GET /page.html HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(page);
    try testing.expect(std.mem.startsWith(u8, page, "HTTP/1.1 200 OK\r\n"));
    try testing.expect(std.mem.indexOf(u8, page, "cross-origin-embedder-policy: require-corp\r\n") != null);
    try testing.expect(std.mem.indexOf(u8, page, "cross-origin-opener-policy: same-origin\r\n") != null);
    try testing.expect(std.mem.indexOf(u8, page, "content-type: text/html; charset=utf-8\r\n") != null);
    try testing.expect(std.mem.endsWith(u8, page, "<!doctype html><p>hi"));

    const bytes = try fetchRaw(testing.allocator, server.port(), "GET /__perf/bytes?n=100000 HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(bytes);
    try testing.expect(std.mem.indexOf(u8, bytes, "content-length: 100000\r\n") != null);
    const body_at = std.mem.indexOf(u8, bytes, "\r\n\r\n").? + 4;
    try testing.expectEqual(@as(usize, 100000), bytes.len - body_at);

    const mark = try fetchRaw(testing.allocator, server.port(), "POST /__perf/mark HTTP/1.1\r\nHost: x\r\nContent-Length: 17\r\nConnection: close\r\n\r\n{\"type\":\"begin\"}\n");
    defer testing.allocator.free(mark);
    try testing.expect(std.mem.startsWith(u8, mark, "HTTP/1.1 200 OK\r\n"));
    try testing.expect(std.mem.endsWith(u8, mark, "{}"));
    try testing.expectEqual(@as(u32, 1), sink.marks);
    try testing.expectEqualStrings("{\"type\":\"begin\"}\n", sink.got.items);

    const missing = try fetchRaw(testing.allocator, server.port(), "GET /../secret HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(missing);
    try testing.expect(std.mem.startsWith(u8, missing, "HTTP/1.1 404 Not Found\r\n"));
}

test "a .gz or .br file is sent as stored, with its coding and its own type" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "t.html.br", .data = "\x0b\x02\x80hi\x03" });
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "t.html.gz", .data = "gz bytes" });
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    const server = try Server.start(testing.allocator, testing.io, .{ .root = root });
    defer server.stop();
    const br = try fetchRaw(testing.allocator, server.port(), "GET /t.html.br HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(br);
    try testing.expect(std.mem.indexOf(u8, br, "content-encoding: br\r\n") != null);
    try testing.expect(std.mem.indexOf(u8, br, "content-type: text/html; charset=utf-8\r\n") != null);
    try testing.expect(std.mem.endsWith(u8, br, "\x0b\x02\x80hi\x03"));
    const gz = try fetchRaw(testing.allocator, server.port(), "GET /t.html.gz HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(gz);
    try testing.expect(std.mem.indexOf(u8, gz, "content-encoding: gzip\r\n") != null);
    try testing.expect(std.mem.endsWith(u8, gz, "gz bytes"));
}

test "keep-alive: two requests on one connection" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "a.txt", .data = "A" });
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    const server = try Server.start(testing.allocator, testing.io, .{ .root = root });
    defer server.stop();
    const both = try fetchRaw(testing.allocator, server.port(), "GET /a.txt HTTP/1.1\r\nHost: x\r\n\r\nGET /a.txt HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n");
    defer testing.allocator.free(both);
    try testing.expectEqual(@as(usize, 2), std.mem.count(u8, both, "HTTP/1.1 200 OK"));
}
