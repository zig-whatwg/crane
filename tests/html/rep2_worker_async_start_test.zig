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
        _ = self.requests.fetchAdd(1, .acq_rel);
        // Held until released - at most 5 s, so that a constructor that
        // waits for the script (the bug) ends.
        const deadline = clock.monotonicMillis() + 5000;
        while (!self.released.load(.acquire) and !self.listener.isStopping() and clock.monotonicMillis() < deadline) clock.sleep(std.time.ns_per_ms);
        if (self.listener.isStopping()) return;
        var output: [0]u8 = .{};
        var writer = stream.writer(testing.io, &output);
        try writer.interface.writeAll("HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: 19\r\nCache-Control: no-store\r\nConnection: close\r\n\r\npostMessage('ran');");
        try writer.interface.flush();
        self.answered.store(true, .release);
    }
};

const Page = struct {
    server: *Server,
    browser: *browser_mod.Browser,
    base: []u8,

    fn open() !Page {
        const server = try Server.start();
        errdefer server.stop();
        const base = try std.fmt.allocPrint(testing.allocator, "http://127.0.0.1:{d}/", .{server.listener.port()});
        errdefer testing.allocator.free(base);
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
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
        var slab = self.browser.scope.slab.slabs;
        while (slab) |each| : (slab = each.next) {
            for (&each.slots) |*slot| {
                const instance: *runtime.Instance = @ptrCast(slot);
                if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
                if (std.mem.eql(u8, instance.vtable.name, name)) count += 1;
            }
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
