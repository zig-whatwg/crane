//! Lane rep2: a dedicated worker's script is fetched without blocking its
//! owner, after its constructor returns.
//!
//! HTML "run a worker" runs in parallel with the Worker constructor: the
//! constructor returns, the owner's event loop goes on running tasks, and
//! the script's fetch completes later. WebKit's Worker::create starts
//! WorkerScriptLoader::loadAsynchronously and returns; Blink's
//! DedicatedWorker::Start starts the loader and returns. Crane fetched the
//! script with a blocking fetch inside the constructor, so a ReportingObserver
//! registered right after `new Worker()` missed the worker's COEP report
//! (html/cross-origin-embedder-policy/reporting-to-frame-owner.https.html),
//! and a slow script stalled its page.
//!
//! The server holds the worker's script until the test lets it go, so each
//! test sees the owner while the fetch is in flight: its tasks run,
//! terminate() ends the fetch (no thread, no event, nothing left), and the
//! end of the owner's realm cancels the fetch and lets the Worker go.
//!
//! Each test runs a whole Browser on a thread of its own (a Browser's agent
//! belongs to the thread that made it), on std.testing.allocator.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const html = @import("html");
const dom = @import("dom");
const clock = @import("clock");
const LoopbackListener = @import("loopback_listener").LoopbackListener;
const helpers = @import("edges_node_holders_helpers.zig");

/// Answers each request for a worker script - `postMessage('ran');` - once
/// the test releases it, or when it stops.
const Server = struct {
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),
    /// Requests that have arrived.
    requests: std.atomic.Value(u32) = .init(0),
    /// The test lets the held scripts go.
    released: std.atomic.Value(bool) = .init(false),
    /// A script has been sent.
    answered: std.atomic.Value(bool) = .init(false),
    /// Hold every script until the server stops: a server that never answers.
    never: std.atomic.Value(bool) = .init(false),
    /// When the first request arrived (the platform's monotonic clock, ms).
    first_request_ms: std.atomic.Value(i64) = .init(0),
    /// When a running worker first asked for /started (same clock).
    started_ms: std.atomic.Value(i64) = .init(0),
    /// The worker script asks for /started (`fetch('/started');`) instead
    /// of posting 'ran'.
    reports_start: std.atomic.Value(bool) = .init(false),

    fn start() !*Server {
        const self = try testing.allocator.create(Server);
        errdefer testing.allocator.destroy(self);
        self.* = .{ .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    /// Stop the accept thread, then close the listener
    /// (tests/support/loopback_listener.zig).
    fn stop(self: *Server) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        testing.allocator.destroy(self);
    }

    fn serve(self: *Server) void {
        while (self.listener.accept()) |stream| {
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
        var output_buffer: [0]u8 = .{};
        if (std.mem.startsWith(u8, reader.interface.buffered(), "GET /started")) {
            // A running worker reports in.
            _ = self.started_ms.cmpxchgStrong(0, clock.monotonicMillis(), .acq_rel, .acquire);
            var started_writer = stream.writer(testing.io, &output_buffer);
            try started_writer.interface.writeAll("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n");
            try started_writer.interface.flush();
            return;
        }
        if (std.mem.startsWith(u8, reader.interface.buffered(), "GET /missing")) {
            var missing_writer = stream.writer(testing.io, &output_buffer);
            try missing_writer.interface.writeAll("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n");
            try missing_writer.interface.flush();
            return;
        }
        if (self.requests.fetchAdd(1, .acq_rel) == 0) self.first_request_ms.store(clock.monotonicMillis(), .release);
        // Held until released - at most 5 s, so that a constructor that
        // waits for the script (the bug) ends - or, for a server that never
        // answers, until the server stops.
        const deadline = clock.monotonicMillis() + 5000;
        while (!self.listener.isStopping() and (self.never.load(.acquire) or (!self.released.load(.acquire) and clock.monotonicMillis() < deadline))) clock.sleep(std.time.ns_per_ms);
        if (self.listener.isStopping()) return;
        const script: []const u8 = if (self.reports_start.load(.acquire)) "fetch('/started');" else "postMessage('ran');";
        var writer = stream.writer(testing.io, &output_buffer);
        var head: [192]u8 = undefined;
        try writer.interface.writeAll(try std.fmt.bufPrint(&head, "HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", .{script.len}));
        try writer.interface.writeAll(script);
        try writer.interface.flush();
        self.answered.store(true, .release);
    }
};

const Page = struct {
    server: *Server,
    browser: *browser_mod.Browser,
    base: []u8,

    fn open() !Page {
        return openWith(false);
    }

    /// A page whose server never answers a worker's script.
    fn openNeverAnswering() !Page {
        return openWith(true);
    }

    fn openWith(never: bool) !Page {
        const server = try Server.start();
        server.never.store(never, .release);
        errdefer server.stop();
        const base = try std.fmt.allocPrint(testing.allocator, "http://127.0.0.1:{d}/", .{server.listener.port()});
        errdefer testing.allocator.free(base);
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigateWithOptions(base, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body>", .{ .base_url = base });
        _ = try browser.runEventLoopBlocking(10);
        return .{ .server = server, .browser = browser, .base = base };
    }

    /// The Browser ends first: its realms' fetches end with it, and the
    /// server's held answers end with the server.
    fn close(self: *Page) void {
        self.browser.deinit();
        self.server.stop();
        testing.allocator.free(self.base);
    }

    fn run(self: *Page, script: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        try page.runScript(script);
    }

    fn eval(self: *Page, script: []const u8) ![]u8 {
        const page = self.browser.current_context orelse return error.NoPage;
        return page.evaluateScriptToString(script, testing.allocator);
    }

    /// Run the event loop until the server has `n` requests, at most 2 s.
    fn awaitRequests(self: *Page, n: u32) !void {
        for (0..200) |_| {
            if (self.server.requests.load(.acquire) >= n) return;
            _ = try self.browser.runEventLoopBlocking(10);
        }
        return error.RequestNeverArrived;
    }

    /// Run the event loop until `state` (a JSON array in the page) is
    /// `expected`, at most 3 s; then expect it.
    fn expectState(self: *Page, expected: []const u8) !void {
        for (0..300) |_| {
            const state = try self.eval("JSON.stringify(state)");
            defer testing.allocator.free(state);
            if (std.mem.eql(u8, state, expected)) return;
            _ = try self.browser.runEventLoopBlocking(10);
        }
        const state = try self.eval("JSON.stringify(state)");
        defer testing.allocator.free(state);
        try testing.expectEqualStrings(expected, state);
    }

    fn realm(self: *Page) !runtime.Context {
        return self.browser.getRealm() orelse error.NoRealm;
    }

    /// The window agent's fetches still in flight.
    fn liveFetches(self: *Page) !usize {
        const fetches = dom.agent_fetches.of(try self.realm()) orelse return 0;
        return fetches.live.items.len;
    }

    /// Live slab slots of the Browser whose interface is `name`.
    fn liveOf(self: *Page, name: []const u8) usize {
        var count: usize = 0;
        var live_slots = self.browser.scope.slab.iterateLive();
        while (live_slots.next()) |instance| {
            if (std.mem.eql(u8, instance.vtable.name, name)) count += 1;
        }
        return count;
    }

    /// Collect, and let the tasks a collection queues run, a few times over.
    fn collect(self: *Page) !void {
        for (0..4) |_| {
            try self.run("TestUtils.gc(); TestUtils.gc();");
            _ = try self.browser.runEventLoopBlocking(20);
        }
    }
};

fn ownerRunsTasksWhileScriptLoads() !void {
    var page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.state = [];
        \\globalThis.worker = new Worker('worker.js');
        \\worker.onmessage = e => state.push('message ' + e.data);
        \\worker.onerror = () => state.push('error');
        \\setTimeout(() => state.push('timer'), 0);
    );
    // The constructor returned with the script still held.
    try testing.expect(!page.server.answered.load(.acquire));
    try page.awaitRequests(1);
    // A page task ran while the script is still loading.
    try page.expectState("[\"timer\"]");
    try testing.expect(!page.server.answered.load(.acquire));
    page.server.released.store(true, .release);
    try page.expectState("[\"timer\",\"message ran\"]");
}

test "new Worker() returns before its script arrives, and the page runs tasks while it loads" {
    try helpers.onFreshThread(ownerRunsTasksWhileScriptLoads);
}

fn terminateDuringFetch() !void {
    var page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.state = [];
        \\globalThis.worker = new Worker('worker.js');
        \\worker.onmessage = e => state.push('message ' + e.data);
        \\worker.onerror = () => state.push('error');
    );
    try testing.expect(!page.server.answered.load(.acquire));
    try page.awaitRequests(1);
    try page.run("worker.terminate();");
    // The fetch ended with terminate(): nothing of it is in flight.
    try testing.expectEqual(@as(usize, 0), try page.liveFetches());
    page.server.released.store(true, .release);
    for (0..30) |_| _ = try page.browser.runEventLoopBlocking(10);
    // No thread started, and nothing was fired at the Worker.
    if (html.WorkerRegistry.existingOf(try page.realm())) |registry| {
        try testing.expect(!registry.ownsAny(@ptrCast(try page.realm())));
    }
    try page.expectState("[]");
    // Dropped, the terminated Worker is collected: its hold has ended.
    try page.run("worker = null;");
    try page.collect();
    try testing.expectEqual(@as(usize, 0), page.liveOf("Worker"));
}

test "terminate() while a worker's script is loading ends the fetch: no thread, no event, and the Worker is collected" {
    try helpers.onFreshThread(terminateDuringFetch);
}

fn realmEndsDuringFetch() !void {
    var page = try Page.open();
    defer page.close();
    const script = try std.fmt.allocPrint(testing.allocator,
        \\globalThis.frame = document.createElement('iframe');
        \\document.body.appendChild(frame);
        \\new frame.contentWindow.Worker('{s}worker.js');
    , .{page.base});
    defer testing.allocator.free(script);
    try page.run(script);
    try testing.expect(!page.server.answered.load(.acquire));
    try page.awaitRequests(1);
    try testing.expectEqual(@as(usize, 1), page.liveOf("Worker"));
    // The frame's realm ends with its fetch in flight: the fetch is
    // cancelled, and the Worker - which only its hold kept - is collected.
    try page.run("frame.remove(); frame = null;");
    _ = try page.browser.runEventLoopBlocking(20);
    try page.collect();
    try testing.expectEqual(@as(usize, 0), try page.liveFetches());
    try testing.expectEqual(@as(usize, 0), page.liveOf("Worker"));
    page.server.released.store(true, .release);
    for (0..20) |_| _ = try page.browser.runEventLoopBlocking(10);
    try testing.expectEqual(@as(usize, 0), page.liveOf("Worker"));
}

test "the end of a Worker's realm while its script is loading cancels the fetch and lets the Worker go" {
    try helpers.onFreshThread(realmEndsDuringFetch);
}

fn startsWhileOwnerRuns() !void {
    var page = try Page.open();
    defer page.close();
    // The script is sent at once, and the worker it starts asks for
    // /started. The owner's script runs for 600 ms after new Worker(): the
    // worker has started meanwhile, in parallel - its script fetched and
    // run without the owner's event loop.
    page.server.released.store(true, .release);
    page.server.reports_start.store(true, .release);
    try page.run(
        \\new Worker('worker.js');
        \\const end = Date.now() + 600;
        \\while (Date.now() < end);
    );
    const returned_ms = clock.monotonicMillis();
    const started = page.server.started_ms.load(.acquire);
    try testing.expect(started != 0);
    try testing.expect(returned_ms - started >= 100);
}

test "a worker starts while its owner's script still runs: its script is fetched in parallel" {
    try helpers.onFreshThread(startsWhileOwnerRuns);
}

fn neverAnsweringWorkersEndPromptly() !void {
    var page = try Page.openNeverAnswering();
    {
        errdefer page.close();
        try page.run(
            \\globalThis.state = [];
            \\globalThis.workers = [];
            \\for (let i = 0; i < 4; i++) {
            \\  const w = new Worker('worker.js?' + i);
            \\  w.onmessage = () => state.push('message');
            \\  w.onerror = () => state.push('error');
            \\  workers.push(w);
            \\}
            \\setTimeout(() => state.push('timer'), 0);
        );
        try page.awaitRequests(4);
        // The owner is never blocked while the workers' fetches wait: a page
        // task runs.
        try page.expectState("[\"timer\"]");
        // One is terminated mid-fetch: nothing is fired at it.
        try page.run("workers[0].terminate();");
        for (0..10) |_| _ = try page.browser.runEventLoopBlocking(10);
        try page.expectState("[\"timer\"]");
    }
    // The Browser ends with three fetches still waiting on a server that
    // never answers: its end - every worker's thread joined - does not wait
    // on the network.
    const t0 = clock.monotonicMillis();
    page.browser.deinit();
    const ended_ms = clock.monotonicMillis() - t0;
    page.server.stop();
    testing.allocator.free(page.base);
    try testing.expect(ended_ms < 1000);
}

test "a Browser whose workers' scripts never arrive ends in under a second, and its page runs tasks meanwhile" {
    try helpers.onFreshThread(neverAnsweringWorkersEndPromptly);
}

fn missingScriptFailsOnce() !void {
    var page = try Page.open();
    defer page.close();
    // The worker's thread fetches a 404: no script, so `error` at the
    // Worker - once, from a task - and the thread ends; what the start held
    // across threads (the request, its relay, the owner's policy copy) is
    // freed on that path too (std.testing.allocator checks).
    try page.run(
        \\globalThis.state = [];
        \\const w = new Worker('missing.js');
        \\w.onmessage = () => state.push('message');
        \\w.onerror = e => state.push('error ' + e.constructor.name);
    );
    try page.expectState("[\"error Event\"]");
    for (0..20) |_| _ = try page.browser.runEventLoopBlocking(10);
    try page.expectState("[\"error Event\"]");
}

test "a worker whose script is a 404 fires error once, from a task, and leaves nothing" {
    try helpers.onFreshThread(missingScriptFailsOnce);
}
