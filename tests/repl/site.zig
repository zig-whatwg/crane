//! The browser console tests' local site: a loopback HTTP server answering a
//! fixed set of pages - links, a form, a redirect, a 404, a page that counts
//! its loads, JSON, cookies - so the console is driven against a real
//! network stack (curl, HTTP/1.1) with no outside network. Each request is
//! answered on a thread of its own with `Connection: close`; `requests`
//! counts them.
const std = @import("std");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

pub const Site = struct {
    allocator: std.mem.Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),
    requests: std.atomic.Value(u32) = .init(0),

    pub fn start(allocator: std.mem.Allocator) !*Site {
        const self = try allocator.create(Site);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    /// Stop accepting, join, close - in that order (tests/support/
    /// loopback_listener.zig) - then wait out the requests being answered.
    pub fn stop(self: *Site) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    /// `http://127.0.0.1:<port><path>`, OWNED by `allocator`.
    pub fn url(self: *const Site, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    fn serve(self: *Site) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, answerAndClose, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            thread.detach();
        }
    }

    fn answerAndClose(self: *Site, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        self.answer(stream) catch {};
    }

    fn answer(self: *Site, stream: std.Io.net.Stream) !void {
        _ = self.requests.fetchAdd(1, .monotonic);
        var input: [16384]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const buffered = reader.interface.buffered();
        const head_end = std.mem.indexOf(u8, buffered, "\r\n\r\n").? + 4;
        const head = buffered[0..head_end];
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        const method = parts.next() orelse return;
        const target = parts.next() orelse return;
        const path = if (std.mem.indexOfScalar(u8, target, '?')) |q| target[0..q] else target;
        // A POST's body, by its Content-Length.
        var body: []const u8 = "";
        if (headerValue(head, "content-length")) |length_text| {
            const length = std.fmt.parseUnsigned(usize, length_text, 10) catch 0;
            while (reader.interface.buffered().len < head_end + length) try reader.interface.fillMore();
            body = reader.interface.buffered()[head_end .. head_end + length];
        }
        const cookie = headerValue(head, "cookie") orelse "";

        var output: [4096]u8 = undefined;
        var writer = stream.writer(std.testing.io, &output);
        const out = &writer.interface;
        const page = route(method, path);
        var content: std.Io.Writer.Allocating = .init(self.allocator);
        defer content.deinit();
        try page.write(&content.writer, .{ .body = body, .cookie = cookie, .target = target });
        try out.print("HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n", .{ page.status, reason(page.status), page.content_type, content.written().len });
        if (page.location) |location| try out.print("Location: {s}\r\n", .{location});
        if (page.set_cookie) |set_cookie| try out.print("Set-Cookie: {s}\r\n", .{set_cookie});
        try out.writeAll("\r\n");
        try out.writeAll(content.written());
        try out.flush();
    }

    fn headerValue(head: []const u8, name: []const u8) ?[]const u8 {
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        _ = lines.next();
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " "), name)) continue;
            return std.mem.trim(u8, line[colon + 1 ..], " ");
        }
        return null;
    }

    fn reason(status: u16) []const u8 {
        return switch (status) {
            200 => "OK",
            302 => "Found",
            404 => "Not Found",
            else => "Status",
        };
    }
};

/// What a page is made of.
const Request = struct {
    body: []const u8,
    cookie: []const u8,
    target: []const u8,
};

const Page = struct {
    status: u16 = 200,
    content_type: []const u8 = "text/html",
    location: ?[]const u8 = null,
    set_cookie: ?[]const u8 = null,
    /// A fixed body, or one made from the request.
    body: []const u8 = "",
    make: ?*const fn (out: *std.Io.Writer, request: Request) std.Io.Writer.Error!void = null,

    fn write(self: Page, out: *std.Io.Writer, request: Request) std.Io.Writer.Error!void {
        if (self.make) |make| return make(out, request);
        try out.writeAll(self.body);
    }
};

fn route(method: []const u8, path: []const u8) Page {
    _ = method;
    const pages = [_]struct { path: []const u8, page: Page }{
        .{ .path = "/a.html", .page = .{ .body =
        \\<!doctype html><title>A</title>
        \\<a id=link href="/b.html">to b</a>
        \\<form id=form method=post action="/submit"><input name=q value=hello></form>
        } },
        .{ .path = "/b.html", .page = .{ .body = "<!doctype html><title>B</title><p>b" } },
        .{ .path = "/c.html", .page = .{ .body = "<!doctype html><title>C</title><p>c" } },
        .{ .path = "/popup.html", .page = .{ .body = "<!doctype html><title>Popup</title>" } },
        .{ .path = "/submit", .page = .{ .make = &submitted } },
        .{ .path = "/redirect", .page = .{ .status = 302, .location = "/b.html", .body = "moved" } },
        .{ .path = "/count.html", .page = .{ .body = "<!doctype html><title>count</title><script>sessionStorage.n = (+sessionStorage.n || 0) + 1; document.title = 'count ' + sessionStorage.n;</script>" } },
        .{ .path = "/later.html", .page = .{ .make = &later } },
        .{ .path = "/data.json", .page = .{ .content_type = "application/json", .body = "{\"items\":[\"x\",\"y\"]}" } },
        .{ .path = "/fetch.html", .page = .{ .body = "<!doctype html><title>fetch</title><ul id=out></ul><script>fetch('/data.json').then(r => r.json()).then(d => { for (const item of d.items) document.getElementById('out').append(Object.assign(document.createElement('li'), {textContent: item})); console.log('fetched', d.items.length); });</script>" } },
        .{ .path = "/cookie.html", .page = .{ .set_cookie = "server=1; Path=/", .make = &cookieEcho } },
    };
    for (pages) |entry| if (std.mem.eql(u8, entry.path, path)) return entry.page;
    return .{ .status = 404, .body = "<!doctype html><title>Not Found</title>" };
}

/// The form's submission: what was posted.
fn submitted(out: *std.Io.Writer, request: Request) std.Io.Writer.Error!void {
    try out.print("<!doctype html><title>submitted</title><pre id=posted>{s}</pre>", .{request.body});
}

/// A page that navigates itself to /b.html from a timer, `?ms` after it
/// loads (`/later.html?50`).
fn later(out: *std.Io.Writer, request: Request) std.Io.Writer.Error!void {
    const ms = if (std.mem.indexOfScalar(u8, request.target, '?')) |q| request.target[q + 1 ..] else "50";
    try out.print("<!doctype html><title>later</title><script>setTimeout(() => {{ location.href = '/b.html'; }}, {s});</script>", .{ms});
}

/// The cookies the request carried, as the page's text.
fn cookieEcho(out: *std.Io.Writer, request: Request) std.Io.Writer.Error!void {
    try out.print("<!doctype html><title>cookies</title><pre id=sent>{s}</pre>", .{request.cookie});
}
