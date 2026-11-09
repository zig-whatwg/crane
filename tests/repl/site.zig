//! The browser console tests' local site: a loopback HTTP server answering a
//! fixed set of pages - links, a form, a redirect, a 404, a page that counts
//! its loads, JSON, cookies, a WAV - so the console is driven against a real
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
        try page.write(&content.writer, .{ .body = body, .cookie = cookie, .target = target, .head = head });
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
    /// The request line and headers.
    head: []const u8 = "",
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
        .{ .path = "/metadata.html", .page = .{ .make = &fetchMetadataEcho } },
        // A page that opens a same-origin popup and listens for its load on
        // the Window open() returned.
        .{ .path = "/opener.html", .page = .{ .body = "<!doctype html><title>opener</title><script>const p = window.open('/popup.html'); p.onload = () => { document.title = 'popup: ' + p.document.title; };</script>" } },
        // The same from a frame of ANOTHER origin (localhost, where the page
        // is 127.0.0.1): the frame's popup is of the frame's origin, and the
        // frame posts what it saw to its parent.
        .{ .path = "/cross-origin-frame-opener.html", .page = .{ .body = "<!doctype html><title>frame opener</title><script>addEventListener('message', (e) => { document.title = e.data; }); const f = document.createElement('iframe'); f.src = location.protocol + '//localhost:' + location.port + '/opener-frame.html'; document.documentElement.append(f);</script>" } },
        .{ .path = "/opener-frame.html", .page = .{ .body = "<!doctype html><title>opener frame</title><script>const p = window.open('/popup.html'); p.onload = () => { parent.postMessage('popup: ' + p.document.title, '*'); };</script>" } },
        // A page that counts its loads, and the navigation API's navigate
        // events it hears before each reload, in its session storage.
        // Window timers as tasks (loadpath1_timer_task_test.zig): each page's
        // script runs as a WPT page's does, in the commit of a navigation
        // whose response came over the network, and sets `done` at the end.
        .{ .path = "/timer-order.html", .page = .{ .body = "<!doctype html><details id=d></details><script>globalThis.log = []; d.ontoggle = () => log.push('toggle'); d.open = true; setTimeout(() => { log.push('timeout'); setTimeout(() => { globalThis.done = true; }, 0); }, 0);</script>" } },
        .{ .path = "/timer-clear-queued.html", .page = .{ .body = "<!doctype html><details id=d></details><script>globalThis.log = []; let id = 0; d.ontoggle = () => { clearTimeout(id); log.push('cleared'); }; d.open = true; id = setTimeout(() => log.push('cleared timer ran'), 0); setTimeout(() => setTimeout(() => { globalThis.done = true; }, 0), 0);</script>" } },
        .{ .path = "/timer-interval.html", .page = .{ .body = "<!doctype html><script>globalThis.log = []; let n = 0; const id = setInterval(() => { log.push('tick' + (++n)); if (n === 3) { clearInterval(id); setTimeout(() => setTimeout(() => { globalThis.done = true; }, 5), 5); } }, 0);</script>" } },
        .{ .path = "/timer-frame-queued.html", .page = .{ .body = "<!doctype html><details id=d></details><script>globalThis.log = []; const f = document.body.appendChild(document.createElement('iframe')); const w = f.contentWindow; d.ontoggle = () => { f.remove(); log.push('removed'); }; d.open = true; w.setTimeout(() => log.push('detached timer ran'), 0); setTimeout(() => setTimeout(() => { globalThis.done = true; }, 0), 0);</script>" } },
        // A zero-delay timer's task is queued at the call (Chromium, Gecko):
        // before the details toggle task queued after it.
        .{ .path = "/timer-call-order.html", .page = .{ .body = "<!doctype html><details id=d></details><script>globalThis.log = []; d.ontoggle = () => log.push('toggle'); setTimeout(() => log.push('timeout'), 0); d.open = true; setTimeout(() => setTimeout(() => { globalThis.done = true; }, 0), 0);</script>" } },
        // Timer ids: one space for the timers queued at the call and the
        // ones armed, each cleared by its own id.
        .{ .path = "/timer-ids.html", .page = .{ .body = "<!doctype html><script>globalThis.log = []; const ran = (name) => () => log.push(name); const a = setTimeout(ran('a'), 0), b = setTimeout(ran('b'), 5), c = setTimeout(ran('c'), 0), i = setInterval(ran('i'), 0), j = setInterval(ran('j'), 5); log.push(String(new Set([a, b, c, i, j]).size === 5 && [a, b, c, i, j].every((id) => id > 0))); clearTimeout(b); clearTimeout(c); clearInterval(i); clearInterval(j); setTimeout(() => setTimeout(() => { globalThis.done = true; }, 10), 10);</script>" } },
        // window.close()'s definitely-close is a task queued at the call:
        // after the zero-delay timer set before it (testharness.js's
        // load-time setTimeout(0), prompt-and-unload-script-closeable).
        .{ .path = "/timer-close-opener.html", .page = .{ .body = "<!doctype html><script>globalThis.log = []; globalThis.finish = () => setTimeout(() => setTimeout(() => { globalThis.done = true; }, 5), 5); window.open('/timer-close-popup.html');</script>" } },
        .{ .path = "/timer-close-popup.html", .page = .{ .body = "<!doctype html><script>onload = () => { setTimeout(() => opener.log.push('timeout'), 0); close(); }; onunload = () => { opener.log.push('unload'); opener.finish(); };</script>" } },
        .{ .path = "/timer-detached-frame.html", .page = .{ .body = "<!doctype html><div id=content style='display: none'></div><script>globalThis.log = []; function frame(detach) { const f = document.getElementById('content').appendChild(document.createElement('iframe')); const w = f.contentWindow; if (detach) f.remove(); return w; } const attached = frame(false), detached = frame(true); attached.setTimeout(() => log.push('attached'), 0); detached.setTimeout(() => log.push('detached'), 0); setTimeout(() => setTimeout(() => { globalThis.done = true; }, 0), 0);</script>" } },
        // The navigation API's entries (loadpath1_navigation_api_test.zig):
        // an entry handed out during the parse is its document's entry; a
        // frame's javascript: URL document is of its initiator's origin.
        .{ .path = "/nav-same-document.html", .page = .{ .body = "<!doctype html><script>globalThis.log = []; const entry = navigation.currentEntry; log.push('parse ' + entry.sameDocument); onload = () => setTimeout(() => { log.push('load ' + entry.sameDocument, 'current ' + (navigation.currentEntry === entry)); globalThis.done = true; }, 0);</script>" } },
        .{ .path = "/nav-javascript-url.html", .page = .{ .body = "<!doctype html><iframe id=i src='/b.html'></iframe><script>globalThis.log = []; onload = () => { const before = i.contentWindow.navigation.currentEntry.key; i.onload = () => { const w = i.contentWindow; log.push(String(w.navigation.entries().length), String(w.navigation.currentEntry !== null && w.navigation.currentEntry.key === before)); globalThis.done = true; }; i.src = \"javascript:'<p>new'\"; };</script>" } },
        // A frame's navigation that replaces one still delaying its
        // container's load (loadpath1_load_delay_test.zig, nav-cancelation-
        // 2.sub.html's shape): the page's frame's frame starts on a slow
        // response, and the page navigates it again to another.
        .{ .path = "/navc-page.html", .page = .{ .body = "<!doctype html><iframe id=c src='/navc-child.html'></iframe><script>globalThis.log = []; c.onload = () => log.push('child load'); onload = () => { log.push('load'); setTimeout(() => setTimeout(() => { globalThis.done = true; }, 10), 10); }; addEventListener('message', (e) => { if (e.data !== 'created') return log.push(e.data); frames[0].frames[0].location.href = '/slow?second'; log.push('navigated'); });</script>" } },
        .{ .path = "/navc-child.html", .page = .{ .body = "<!doctype html><iframe src='/slow?first'></iframe><script>document.querySelector('iframe').onload = () => parent.postMessage('grandchild load', '*'); parent.postMessage('created', '*');</script>" } },
        .{ .path = "/slow", .page = .{ .make = &slow } },
        .{ .path = "/reload.html", .page = .{ .body = "<!doctype html><title>reload</title><script>sessionStorage.loads = (+sessionStorage.loads || 0) + 1; navigation.onnavigate = (e) => { sessionStorage.navigates = (sessionStorage.navigates || '') + e.navigationType + ','; }; document.title = 'loads ' + sessionStorage.loads + ' navigates [' + (sessionStorage.navigates || '') + ']';</script>" } },
        // Half a second of silence as WAV linear PCM (wptcfg_media_decoding_test.zig).
        .{ .path = "/tone.wav", .page = .{ .content_type = "audio/wav", .body = tone_wav } },
    };
    for (pages) |entry| if (std.mem.eql(u8, entry.path, path)) return entry.page;
    return .{ .status = 404, .body = "<!doctype html><title>Not Found</title>" };
}

/// A canonical 44-byte RIFF/WAVE header - PCM (format 1), mono, 8,000 Hz,
/// 8-bit, so 8,000 bytes a second - and 4,000 bytes of silence (0x80):
/// exactly half a second.
const tone_wav: []const u8 = "RIFF\xc4\x0f\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x40\x1f\x00\x00\x40\x1f\x00\x00\x01\x00\x08\x00data\xa0\x0f\x00\x00" ++ &@as([4000]u8, @splat(0x80));

/// The form's submission: what was posted.
fn submitted(out: *std.Io.Writer, request: Request) std.Io.Writer.Error!void {
    try out.print("<!doctype html><title>submitted</title><pre id=posted>{s}</pre>", .{request.body});
}

/// A page that navigates itself to /b.html from a timer, `?ms` after it
/// loads (`/later.html?50`).
/// An empty page answered after a second (overlapping-navigations-and-
/// traversals/resources/slow.py's shape, its two seconds halved).
fn slow(out: *std.Io.Writer, request: Request) std.Io.Writer.Error!void {
    _ = request;
    std.Io.sleep(std.testing.io, .fromMilliseconds(1000), .awake) catch {};
    try out.writeAll("<!doctype html><title>slow</title>");
}

fn later(out: *std.Io.Writer, request: Request) std.Io.Writer.Error!void {
    const ms = if (std.mem.indexOfScalar(u8, request.target, '?')) |q| request.target[q + 1 ..] else "50";
    try out.print("<!doctype html><title>later</title><script>setTimeout(() => {{ location.href = '/b.html'; }}, {s});</script>", .{ms});
}

/// The request's Fetch Metadata headers, as the page's text:
/// "<Sec-Fetch-Mode>|<Sec-Fetch-Dest>" ("-" for one not sent).
fn fetchMetadataEcho(out: *std.Io.Writer, request: Request) std.Io.Writer.Error!void {
    const mode = Site.headerValue(request.head, "sec-fetch-mode") orelse "-";
    const dest = Site.headerValue(request.head, "sec-fetch-dest") orelse "-";
    try out.print("<!doctype html><title>metadata</title><pre id=metadata>{s}|{s}</pre>", .{ mode, dest });
}

/// The cookies the request carried, as the page's text.
fn cookieEcho(out: *std.Io.Writer, request: Request) std.Io.Writer.Error!void {
    try out.print("<!doctype html><title>cookies</title><pre id=sent>{s}</pre>", .{request.cookie});
}
