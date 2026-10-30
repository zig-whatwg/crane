//! A dedicated worker that ends with fetches in flight - streamed bodies
//! with their readers, an unread Response, an XMLHttpRequest and an
//! EventSource, each still receiving - reports nothing from its realm's
//! end, and nothing of them is left (lane workerteardown1).
//!
//! Its realm's end freed the realm's objects first and swept its fetches
//! after (worker_realm.destroyWorkerRealmIn's `retire`). Each of those
//! objects ended its fetch's body as it was freed, and the fetch reported
//! Resource Timing to the worker's global scope, which the same teardown,
//! in hash order, may already have freed: a SIGSEGV in Instance.stateAs
//! under Performance.performanceOfRealm, and a freed global read in every
//! run (fetch/api/basic/stream-response.any.js [worker]). The worker host
//! now mutes its fetches at the start of the realm's end
//! (WorkerHost.teardownRealm, AgentFetches.stopReporting), as Blink prevents
//! a loader's notifications when its context is destroyed
//! (FetchManager::Loader::Dispose), and the realm frees its global scope
//! after everything else (context_manager.removeContextByKey).
//!
//! This is also the case that terminating the fetch group before the
//! realm's end double-freed: the EventSource's body failure queued a task
//! that a closing worker's loop drops at once, and its drop closed the
//! source - terminating the fetch being terminated.
//!
//! Several fetches, so that most rounds put the global scope ahead of some
//! body in the walk. Each round runs a whole Browser on a thread of its own
//! (tests/html is one executable: a fresh thread has no per-thread state
//! left by others), and testing.allocator reports anything not freed.

const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const clock = @import("clock");

/// Answers every connection with its headers and the start of a body that
/// never finishes, until the test stops it.
const Server = struct {
    socket: std.Io.net.Server,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    active: std.atomic.Value(u32) = .init(0),

    fn start() !*Server {
        const self = try testing.allocator.create(Server);
        errdefer testing.allocator.destroy(self);
        const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
        var socket = try address.listen(testing.io, .{ .reuse_address = true });
        errdefer socket.deinit(testing.io);
        self.* = .{ .socket = socket };
        self.thread = try std.Thread.spawn(.{}, serve, .{ self, socket });
        return self;
    }

    fn stop(self: *Server) void {
        self.stopping.store(true, .release);
        self.socket.deinit(testing.io);
        self.thread.?.join();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        testing.allocator.destroy(self);
    }

    fn port(self: *const Server) u16 {
        return self.socket.socket.address.getPort();
    }

    fn serve(self: *Server, listener: std.Io.net.Server) void {
        var socket = listener;
        while (!self.stopping.load(.acquire)) {
            const stream = socket.accept(testing.io) catch continue;
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, answerAndClose, .{ self, stream }) catch {
                stream.close(testing.io);
                _ = self.active.fetchSub(1, .acq_rel);
                continue;
            };
            thread.detach();
        }
    }

    fn answerAndClose(self: *Server, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(testing.io);
        self.answer(stream) catch {};
    }

    fn answer(self: *Server, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const request = reader.interface.buffered();
        var output: [0]u8 = .{};
        var writer = stream.writer(testing.io, &output);
        if (std.mem.indexOf(u8, request, "GET /events") != null) {
            try writer.interface.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-store\r\nConnection: close\r\n\r\ndata: first\n\n");
        } else {
            try writer.interface.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 1048576\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n");
            const part = @as([16384]u8, @splat('a'));
            try writer.interface.writeAll(&part);
        }
        try writer.interface.flush();
        while (!self.stopping.load(.acquire)) clock.sleep(std.time.ns_per_ms);
    }
};

fn round() !void {
    const server = try Server.start();
    defer server.stop();
    var base_buf: [64]u8 = undefined;
    const base = try std.fmt.bufPrint(&base_buf, "http://127.0.0.1:{d}/", .{server.port()});
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions(base, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = base });
    // The worker starts six fetches and keeps each one receiving: three
    // bodies read through their streams, a Response whose body is never
    // read, an XMLHttpRequest and an EventSource. It says so once each has
    // begun to arrive.
    const script = try std.fmt.allocPrint(testing.allocator,
        \\globalThis.state = 'pending';
        \\const source = `
        \\  const base = '{s}';
        \\  let started = 0;
        \\  const begun = () => {{ if (++started === 6) postMessage('ready'); }};
        \\  const failed = e => postMessage('failed ' + e);
        \\  for (let i = 0; i < 3; i++) {{
        \\    fetch(base + 'body' + i).then(r => {{ self['reader' + i] = r.body.getReader(); return self['reader' + i].read(); }}).then(begun, failed);
        \\  }}
        \\  fetch(base + 'unread').then(r => {{ self.unread = r; begun(); }}, failed);
        \\  const xhr = new XMLHttpRequest();
        \\  self.xhr = xhr;
        \\  let xhrBegun = false;
        \\  xhr.onprogress = () => {{ if (!xhrBegun) {{ xhrBegun = true; begun(); }} }};
        \\  xhr.onerror = () => failed('xhr');
        \\  xhr.open('GET', base + 'xhr');
        \\  xhr.send();
        \\  const events = new EventSource(base + 'events');
        \\  self.events = events;
        \\  let eventsBegun = false;
        \\  events.onmessage = () => {{ if (!eventsBegun) {{ eventsBegun = true; begun(); }} }};
        \\`;
        \\const worker = new Worker(URL.createObjectURL(new Blob([source], {{ type: 'text/javascript' }})));
        \\worker.onmessage = e => {{ state = e.data; }};
        \\worker.onerror = () => {{ state = 'worker error'; }};
    , .{base});
    defer testing.allocator.free(script);
    try page.runScript(script);
    for (0..500) |_| {
        _ = try browser.runEventLoopBlocking(10);
        const state = try page.evaluateScriptToString("state", testing.allocator);
        defer testing.allocator.free(state);
        if (std.mem.eql(u8, state, "pending")) continue;
        try testing.expectEqualStrings("ready", state);
        // Every fetch is still receiving: the Browser ends now (deferred),
        // the worker's realm with it.
        return;
    }
    return error.FetchesDidNotStart;
}

fn onFreshThread() !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            for (0..3) |_| round() catch |err| {
                out.* = err;
                return;
            };
        }
    }.run, .{&result});
    thread.join();
    try result;
}

test "a dedicated worker that ends with fetches still receiving reports nothing from its end, and leaves nothing of them" {
    try onFreshThread();
}
