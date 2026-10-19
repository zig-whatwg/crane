//! Handle Fetch and clients at creation, through the manager, across
//! threads but without an engine: a controlled client's request reaches the
//! service worker's host and its answer the fetching side; a navigation's
//! reserved client is made by Handle Fetch and adopted by the realm that
//! comes of it - or discarded - with the get() that waited for it answered;
//! and a thread blocked in a synchronous fetch still has its window clients'
//! data answered. The realms are the test's endpoints; the service worker is
//! the test, answering the dispatches the host is handed.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const fetch = @import("fetch");
const sw = @import("service_worker");
const Manager = sw.Manager;
const manager_mod = sw.manager;
const registry = sw.registry;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;

/// A manager whose host keeps each fetch dispatch for the test to answer.
const Harness = struct {
    manager: Manager,
    mutex: std.Io.Mutex = .init,
    dispatches: std.ArrayListUnmanaged(Kept) = .empty,

    const Kept = struct { dispatch: *manager_mod.FetchDispatch, worker: u64, generation: u64 };

    fn of(manager: *Manager) *Harness {
        return @fieldParentPtr("manager", manager);
    }

    /// The next dispatch the host was handed, waiting up to `budget_ms`.
    fn nextDispatch(self: *Harness, budget_ms: u64) !Kept {
        var waited: u64 = 0;
        while (waited < budget_ms) : (waited += 5) {
            {
                std.Io.Threaded.mutexLock(&self.mutex);
                defer std.Io.Threaded.mutexUnlock(&self.mutex);
                if (self.dispatches.items.len > 0) return self.dispatches.orderedRemove(0);
            }
            sleepMs(5);
        }
        return error.Timeout;
    }

    /// As the worker's thread does once the event is no longer active.
    fn done(self: *Harness, kept: Kept) void {
        self.manager.report(.{ .fetch_done = .{ .worker = kept.worker, .generation = kept.generation } });
    }

    fn deinit(self: *Harness) void {
        for (self.dispatches.items) |kept| kept.dispatch.fail();
        self.dispatches.deinit(self.manager.allocator);
    }
};

fn sleepMs(ms: u64) void {
    std.Io.Threaded.global_single_threaded.io().sleep(.fromNanoseconds(@intCast(ms * std.time.ns_per_ms)), .awake) catch {};
}

const keeping_host: manager_mod.Host = .{
    .fetch = fakeFetch,
    .start = fakeStart,
    .dispatch = fakeDispatch,
    .post_message = dropPostMessage,
    .dispatch_fetch = keepDispatchFetch,
};

fn fakeFetch(manager: *Manager, plan: *const registry.FetchPlan) registry.FetchOutcome {
    var outcome: registry.FetchOutcome = .{ .has_updated_resources = true, .checked_network = true };
    const allocator = manager.allocator;
    const url = allocator.dupe(u8, plan.script_url) catch return .{ .failure = .network };
    const body = allocator.dupe(u8, "x") catch return .{ .failure = .network };
    const content_type = allocator.dupe(u8, "text/javascript") catch return .{ .failure = .network };
    outcome.resources.append(allocator, .{ .url = url, .body = body, .content_type = content_type }) catch return .{ .failure = .network };
    return outcome;
}

fn fakeStart(manager: *Manager, start: *const manager_mod.WorkerStart) anyerror!manager_mod.Started {
    manager.report(.{ .evaluated = .{ .worker = start.worker_id, .ok = true, .handles_fetch = true } });
    return .{ .link = null };
}

fn fakeDispatch(manager: *Manager, _: manager_mod.Started, _: registry.LifecycleEvent, op: u64) void {
    manager.report(.{ .lifecycle_done = .{ .op = op, .failed = false } });
}

fn dropPostMessage(manager: *Manager, _: manager_mod.Started, message: *manager_mod.WorkerMessage, worker_id: u64, generation: u64) void {
    message.destroy();
    manager.report(.{ .message_done = .{ .worker = worker_id, .generation = generation } });
}

fn keepDispatchFetch(manager: *Manager, _: manager_mod.Started, dispatch: *manager_mod.FetchDispatch, worker_id: u64, generation: u64) void {
    const harness = Harness.of(manager);
    std.Io.Threaded.mutexLock(&harness.mutex);
    defer std.Io.Threaded.mutexUnlock(&harness.mutex);
    harness.dispatches.append(manager.allocator, .{ .dispatch = dispatch, .worker = worker_id, .generation = generation }) catch {
        dispatch.fail();
        manager.report(.{ .fetch_done = .{ .worker = worker_id, .generation = generation } });
    };
}

/// A realm, as the test plays it.
const TestEndpoint = struct {
    endpoint: manager_mod.Endpoint,
    allocator: std.mem.Allocator,
    log: std.ArrayListUnmanaged([]u8) = .empty,
    /// How many times its data was read at once (a blocked thread's).
    read_now: std.atomic.Value(u32) = .init(0),

    fn create(allocator: std.mem.Allocator, sink: *runtime.TaskSink, realm: *const anyopaque) TestEndpoint {
        return .{
            .endpoint = .{ .sink = sink, .deliver = deliver, .window_data = windowData, .window_data_now = windowDataNow, .realm = realm },
            .allocator = allocator,
        };
    }

    fn deinit(self: *TestEndpoint) void {
        for (self.log.items) |line| self.allocator.free(line);
        self.log.deinit(self.allocator);
    }

    fn deliver(endpoint: *manager_mod.Endpoint, delivery: *manager_mod.Delivery) void {
        const self: *TestEndpoint = @fieldParentPtr("endpoint", endpoint);
        const line = switch (delivery.*) {
            .resolve_clients => |m| std.fmt.allocPrint(self.allocator, "clients {d}", .{m.clients.len}),
            .resolve_client => |m| if (m.client) |client|
                std.fmt.allocPrint(self.allocator, "client {s}", .{client.url})
            else
                std.fmt.allocPrint(self.allocator, "client undefined", .{}),
            .resolve_preload_state => |m| std.fmt.allocPrint(self.allocator, "preload {d} {} {s}", .{ m.promise, m.enabled, m.header_value }),
            .resolve_undefined => |m| std.fmt.allocPrint(self.allocator, "undefined {d}", .{m.promise}),
            .reject => |m| std.fmt.allocPrint(self.allocator, "reject {d} {s}", .{ m.promise, @tagName(m.kind) }),
            else => std.fmt.allocPrint(self.allocator, "{s}", .{@tagName(delivery.*)}),
        } catch return;
        self.log.append(self.allocator, line) catch self.allocator.free(line);
    }

    fn windowData(_: *manager_mod.Endpoint, _: std.mem.Allocator) ?manager_mod.WindowData {
        return .{};
    }

    fn windowDataNow(endpoint: *manager_mod.Endpoint, _: std.mem.Allocator) ?manager_mod.WindowData {
        const self: *TestEndpoint = @fieldParentPtr("endpoint", endpoint);
        _ = self.read_now.fetchAdd(1, .seq_cst);
        return .{};
    }

    fn heard(self: *const TestEndpoint, line: []const u8) bool {
        for (self.log.items) |item| if (std.mem.eql(u8, item, line)) return true;
        return false;
    }
};

fn runPosted(sink: *runtime.TaskSink, allocator: std.mem.Allocator) !void {
    var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer posted.deinit(allocator);
    try sink.takeAll(&posted, allocator);
    for (posted.items) |task| task.run(task.data);
}

fn drainUntil(sink: *runtime.TaskSink, endpoint: *TestEndpoint, line: []const u8, budget_ms: u64) !void {
    var waited: u64 = 0;
    while (!endpoint.heard(line)) {
        if (waited >= budget_ms) {
            std.debug.print("never heard \"{s}\"; heard:\n", .{line});
            for (endpoint.log.items) |item| std.debug.print("  {s}\n", .{item});
            return error.Timeout;
        }
        sink.waitForWork(10 * std.time.ns_per_ms);
        waited += 10;
        try runPosted(sink, endpoint.allocator);
    }
}

/// Register a service worker at https://example.com/ for the environment
/// `page_environment` and run `sink` until it is activated: its id.
fn activate(manager: *Manager, sink: *runtime.TaskSink, allocator: std.mem.Allocator, page_environment: u64) !u64 {
    try manager.schedule(.{
        .job_type = .register,
        .storage_key = "https://example.com",
        .scope_url = "https://example.com/",
        .script_url = "https://example.com/sw.js",
        .client = .{ .environment = page_environment, .promise = 1 },
        .referrer = "https://example.com/page.html",
    });
    var waited: u64 = 0;
    while (waited < 10_000) : (waited += 10) {
        sink.waitForWork(10 * std.time.ns_per_ms);
        try runPosted(sink, allocator);
        var match = (try manager.match(allocator, "https://example.com", "https://example.com/page.html")) orelse continue;
        defer match.deinit(allocator);
        if (match.active) |active| if (active.state == .activated) return active.id;
    }
    return error.Timeout;
}

/// clients.claim() for the worker, as its thread would ask.
fn claim(manager: *Manager, worker_id: u64) !void {
    std.Io.Threaded.mutexLock(&manager.mutex);
    defer std.Io.Threaded.mutexUnlock(&manager.mutex);
    try manager.registry.claim(worker_id);
}

fn controllerOf(manager: *Manager, environment_id: u64) u64 {
    std.Io.Threaded.mutexLock(&manager.mutex);
    defer std.Io.Threaded.mutexUnlock(&manager.mutex);
    const environment = manager.registry.findEnvironment(environment_id) orelse return 0;
    const worker = environment.active_worker orelse return 0;
    return worker.id;
}

fn clientMessage(allocator: std.mem.Allocator) !*manager_mod.ClientMessage {
    const message = try allocator.create(manager_mod.ClientMessage);
    message.* = .{ .allocator = allocator, .message = null, .origin = try allocator.dupe(u8, "https://example.com") };
    return message;
}

fn testResponse(allocator: std.mem.Allocator, status: u16) !*InternalResponse {
    const response = try InternalResponse.init(allocator);
    response.status = status;
    return response;
}

const Fixture = struct {
    debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,
    harness: Harness = undefined,
    sink: *runtime.TaskSink = undefined,
    sw_sink: *runtime.TaskSink = undefined,
    page: TestEndpoint = undefined,
    worker_realm: TestEndpoint = undefined,
    page_environment: u64 = 0,
    sw_environment: u64 = 0,
    worker_id: u64 = 0,
    realm_tags: [4]u8 = .{ 0, 0, 0, 0 },

    fn allocator(self: *Fixture) std.mem.Allocator {
        return self.debug_allocator.allocator();
    }

    /// A page with an active worker at its scope, and the worker's own
    /// realm on a loop of its own.
    fn setUp(self: *Fixture) !void {
        const a = self.allocator();
        self.sink = try runtime.TaskSink.create(a);
        self.sw_sink = try runtime.TaskSink.create(a);
        self.page = TestEndpoint.create(a, self.sink, &self.realm_tags[0]);
        self.worker_realm = TestEndpoint.create(a, self.sw_sink, &self.realm_tags[1]);
        self.harness = .{ .manager = Manager.init(a) };
        self.harness.manager.host = &keeping_host;
        const manager = &self.harness.manager;
        self.page_environment = try manager.addEnvironment(.{ .kind = .window, .origin = "https://example.com", .creation_url = "https://example.com/page.html", .endpoint = &self.page.endpoint });
        self.worker_id = try activate(manager, self.sink, a, self.page_environment);
        self.sw_environment = try manager.addEnvironment(.{ .kind = .service_worker, .origin = "https://example.com", .creation_url = "https://example.com/sw.js", .service_worker_id = self.worker_id, .endpoint = &self.worker_realm.endpoint });
    }

    fn tearDown(self: *Fixture) void {
        self.harness.deinit();
        self.harness.manager.deinit();
        self.page.deinit();
        self.worker_realm.deinit();
        self.sink.release();
        self.sw_sink.release();
        std.debug.assert(self.debug_allocator.deinit() == .ok);
    }
};

test "a controlled client's subresource request goes to its service worker, and the answer to the fetching side" {
    var fixture: Fixture = .{};
    try fixture.setUp();
    defer fixture.tearDown();
    const manager = &fixture.harness.manager;
    const a = fixture.allocator();

    // Not controlled: populate request from client gives no route.
    try testing.expect(manager.routeForRealm(fixture.page.endpoint.realm) == null);
    try claim(manager, fixture.worker_id);
    const route = manager.routeForRealm(fixture.page.endpoint.realm).?;
    try testing.expectEqual(fixture.page_environment, route.client);

    const request = try InternalRequest.init(a, "https://example.com/data.txt");
    defer request.deinit();
    request.destination = .empty;
    const started = try route.handle(route.context, request, route.client);
    const call = started.call;
    defer call.release();

    const kept = try fixture.harness.nextDispatch(10_000);
    try testing.expectEqualStrings("https://example.com/data.txt", kept.dispatch.request.currentUrl());
    try testing.expectEqualStrings(&manager.clientIdOf(fixture.page_environment).?, &kept.dispatch.client_id.?);
    try testing.expect(kept.dispatch.resulting_client_id == null);
    // The worker answers with a response.
    kept.dispatch.call.answer(.{ .response = .{ .response = try testResponse(a, 203) } });
    kept.dispatch.destroy();
    fixture.harness.done(kept);

    const answer = call.wait(5_000) orelse return error.TestUnexpectedTimeout;
    try testing.expect(answer == .response);
    defer answer.response.response.deinit();
    try testing.expectEqual(@as(u16, 203), answer.response.response.status);

    // An embed's request is never handled.
    request.destination = .embed;
    try testing.expect(try route.handle(route.context, request, route.client) == .network);
    manager.removeEnvironment(fixture.page_environment);
    manager.removeEnvironment(fixture.sw_environment);
}

test "a navigation's reserved client is made and controlled by Handle Fetch, then adopted by its realm; get() finds it at once, and its messages wait for it" {
    var fixture: Fixture = .{};
    try fixture.setUp();
    defer fixture.tearDown();
    const manager = &fixture.harness.manager;
    const a = fixture.allocator();

    const reserved = manager.reserveClient(.window, fixture.page_environment, 0, .{ .nested = "https://example.com", .top_level = "https://example.com" }).?;
    const request = try InternalRequest.init(a, "https://example.com/frame.html");
    defer request.deinit();
    request.destination = .iframe;
    request.mode = .navigate;
    request.reserved_client = reserved;
    const route = manager.routeOfReserved();
    const started = try route.handle(route.context, request, 0);
    const call = started.call;
    defer call.release();
    const kept = try fixture.harness.nextDispatch(10_000);
    const resulting = kept.dispatch.resulting_client_id.?;
    // A navigation's fetch event names no client (as every browser does).
    try testing.expect(kept.dispatch.client_id == null);
    try testing.expect(reserved.environment != 0);
    // Step 9.8: the reserved client is controlled from now on.
    try testing.expectEqual(fixture.worker_id, controllerOf(manager, reserved.environment));

    // clients.get(resultingClientId) in the fetch event resolves at once with
    // the reserved client (Firefox's and Safari's answer), and a message to it
    // waits for the realm that adopts it.
    try manager.getClient(fixture.sw_environment, fixture.worker_id, &resulting, 7);
    try drainUntil(fixture.sw_sink, &fixture.worker_realm, "client https://example.com/frame.html", 10_000);
    manager.postToClient(reserved.environment, fixture.worker_id, try clientMessage(a));

    // The worker falls back to the network; the fetch goes on.
    kept.dispatch.call.answer(.fallback);
    kept.dispatch.destroy();
    fixture.harness.done(kept);
    try testing.expect((call.wait(5_000) orelse return error.TestUnexpectedTimeout) == .fallback);

    // The document's realm comes: it adopts the reserved client - its id,
    // its controller - and the waiting get() is answered with it.
    var frame_tag: u8 = 0;
    var frame = TestEndpoint.create(a, fixture.sink, &frame_tag);
    defer frame.deinit();
    const id = try manager.createClient(.{
        .kind = .window,
        .origin = "https://example.com",
        .creation_url = "https://example.com/frame.html?final",
        .secure_context = true,
        .endpoint = &frame.endpoint,
        .reserved = reserved,
    });
    try testing.expectEqualStrings(&resulting, &manager.clientIdOf(id).?);
    try testing.expectEqual(fixture.worker_id, controllerOf(manager, id));
    // The message that waited reaches the realm.
    try drainUntil(fixture.sink, &frame, "client_message", 10_000);
    // get() now: its window data is read on its loop (the page's), then the
    // worker's realm hears the client at its final URL.
    try manager.getClient(fixture.sw_environment, fixture.worker_id, &resulting, 8);
    var waited: u64 = 0;
    while (!fixture.worker_realm.heard("client https://example.com/frame.html?final")) : (waited += 10) {
        if (waited > 10_000) return error.Timeout;
        try runPosted(fixture.sink, a);
        fixture.sw_sink.waitForWork(10 * std.time.ns_per_ms);
        try runPosted(fixture.sw_sink, a);
    }
    manager.removeEnvironment(id);
    manager.removeEnvironment(fixture.page_environment);
    manager.removeEnvironment(fixture.sw_environment);
}

test "a reserved client the document is not of its origin, or that no document comes of, is discarded: a get() for it is undefined" {
    var fixture: Fixture = .{};
    try fixture.setUp();
    defer fixture.tearDown();
    const manager = &fixture.harness.manager;
    const a = fixture.allocator();
    const route = manager.routeOfReserved();

    for ([_]bool{ true, false }) |document_comes| {
        const reserved = manager.reserveClient(.window, fixture.page_environment, 0, .{ .nested = "https://example.com", .top_level = "https://example.com" }).?;
        const request = try InternalRequest.init(a, "https://example.com/redirects.html");
        defer request.deinit();
        request.destination = .iframe;
        request.mode = .navigate;
        request.reserved_client = reserved;
        const call = (try route.handle(route.context, request, 0)).call;
        defer call.release();
        const kept = try fixture.harness.nextDispatch(10_000);
        const resulting = kept.dispatch.resulting_client_id.?;
        // A message to the reserved client waits - and goes with it.
        manager.postToClient(reserved.environment, fixture.worker_id, try clientMessage(a));
        kept.dispatch.call.answer(.fallback);
        kept.dispatch.destroy();
        fixture.harness.done(kept);
        _ = call.wait(5_000) orelse return error.TestUnexpectedTimeout;

        var other_tag: u8 = 0;
        var other = TestEndpoint.create(a, fixture.sink, &other_tag);
        defer other.deinit();
        if (document_comes) {
            // A cross-origin redirect: the document is another origin's.
            const id = try manager.createClient(.{
                .kind = .window,
                .origin = "https://other.example",
                .creation_url = "https://other.example/landed.html",
                .secure_context = true,
                .endpoint = &other.endpoint,
                .reserved = reserved,
            });
            try testing.expect(!std.mem.eql(u8, &resulting, &manager.clientIdOf(id).?));
            try testing.expectEqual(@as(u64, 0), controllerOf(manager, id));
            manager.removeEnvironment(id);
        } else {
            // A 204, a network error, an aborted navigation.
            manager.releaseReserved(reserved);
        }
        try manager.getClient(fixture.sw_environment, fixture.worker_id, &resulting, 9);
        try drainUntil(fixture.sw_sink, &fixture.worker_realm, "client undefined", 10_000);
        for (fixture.worker_realm.log.items) |line| a.free(line);
        fixture.worker_realm.log.clearRetainingCapacity();
    }
    manager.removeEnvironment(fixture.page_environment);
    manager.removeEnvironment(fixture.sw_environment);
}

test "a document no fetch went through HTTP for inherits its creator's controller, when same origin" {
    var fixture: Fixture = .{};
    try fixture.setUp();
    defer fixture.tearDown();
    const manager = &fixture.harness.manager;
    const a = fixture.allocator();
    try claim(manager, fixture.worker_id);

    var tags: [2]u8 = .{ 0, 0 };
    var blank = TestEndpoint.create(a, fixture.sink, &tags[0]);
    defer blank.deinit();
    var opaque_like = TestEndpoint.create(a, fixture.sink, &tags[1]);
    defer opaque_like.deinit();
    const blank_id = try manager.createClient(.{ .kind = .window, .origin = "https://example.com", .creation_url = "about:blank", .secure_context = true, .endpoint = &blank.endpoint, .creator = fixture.page_environment });
    try testing.expectEqual(fixture.worker_id, controllerOf(manager, blank_id));
    const other_id = try manager.createClient(.{ .kind = .window, .origin = "https://other.example", .creation_url = "about:blank", .secure_context = true, .endpoint = &opaque_like.endpoint, .creator = fixture.page_environment });
    try testing.expectEqual(@as(u64, 0), controllerOf(manager, other_id));
    for ([_]u64{ blank_id, other_id, fixture.page_environment, fixture.sw_environment }) |id| manager.removeEnvironment(id);
}

test "a thread blocked in a synchronous fetch still has its window clients' data answered" {
    var fixture: Fixture = .{};
    try fixture.setUp();
    defer fixture.tearDown();
    const manager = &fixture.harness.manager;
    const a = fixture.allocator();
    try claim(manager, fixture.worker_id);

    // A matchAll() asked before the page blocks: its window data task waits
    // on the page's loop, which will not run it.
    try manager.matchAll(fixture.sw_environment, fixture.worker_id, true, .window, 11);

    const route = manager.routeForRealm(fixture.page.endpoint.realm).?;
    const request = try InternalRequest.init(a, "https://example.com/sync.txt");
    defer request.deinit();
    const call = (try route.handle(route.context, request, route.client)).call;
    defer call.release();

    // The service worker's side, on its own thread: once the page is
    // blocked, a matchAll() from the fetch handler - and the one asked
    // before - are answered, then the fetch is.
    const Worker = struct {
        fn run(f: *Fixture, m: *Manager) void {
            const kept = f.harness.nextDispatch(10_000) catch return;
            var waited: u64 = 0;
            while (f.page.read_now.load(.seq_cst) == 0 and waited < 10_000) : (waited += 5) sleepMs(5);
            m.matchAll(f.sw_environment, f.worker_id, true, .window, 12) catch {};
            var heard: u32 = 0;
            waited = 0;
            while (heard < 2 and waited < 10_000) : (waited += 10) {
                f.sw_sink.waitForWork(10 * std.time.ns_per_ms);
                runPosted(f.sw_sink, f.allocator()) catch {};
                heard = 0;
                for (f.worker_realm.log.items) |line| {
                    if (std.mem.eql(u8, line, "clients 1")) heard += 1;
                }
            }
            kept.dispatch.call.answer(.fallback);
            kept.dispatch.destroy();
            f.harness.done(kept);
        }
    };
    const thread = try std.Thread.spawn(.{}, Worker.run, .{ &fixture, manager });
    // The page's thread blocks until the worker answers.
    try testing.expect((call.wait(5_000) orelse return error.TestUnexpectedTimeout) == .fallback);
    thread.join();
    try testing.expectEqual(@as(u32, 1), fixture.page.read_now.load(.seq_cst));
    var answered: u32 = 0;
    for (fixture.worker_realm.log.items) |line| {
        if (std.mem.eql(u8, line, "clients 1")) answered += 1;
    }
    try testing.expectEqual(@as(u32, 2), answered);
    // The page's late window data task finds its query gone.
    try runPosted(fixture.sink, a);
    manager.removeEnvironment(fixture.page_environment);
    manager.removeEnvironment(fixture.sw_environment);
}

test "navigation preload: the registration's state, set and read through its active worker; none rejects with InvalidStateError" {
    var fixture: Fixture = .{};
    try fixture.setUp();
    defer fixture.tearDown();
    const manager = &fixture.harness.manager;
    const registration_id = blk: {
        var info = (try manager.registrationOfWorker(fixture.allocator(), fixture.worker_id)).?;
        defer info.deinit(fixture.allocator());
        break :blk info.id;
    };
    // getState() of a new registration: disabled, header value `true`.
    manager.navigationPreload(fixture.page_environment, registration_id, .get_state, 1);
    try drainUntil(fixture.sink, &fixture.page, "preload 1 false true", 10_000);
    // enable(), setHeaderValue(), then getState() - from the worker's realm too.
    manager.navigationPreload(fixture.page_environment, registration_id, .enable, 2);
    try drainUntil(fixture.sink, &fixture.page, "undefined 2", 10_000);
    manager.navigationPreload(fixture.sw_environment, registration_id, .{ .set_header_value = "insightful" }, 3);
    try drainUntil(fixture.sw_sink, &fixture.worker_realm, "undefined 3", 10_000);
    manager.navigationPreload(fixture.sw_environment, registration_id, .get_state, 4);
    try drainUntil(fixture.sw_sink, &fixture.worker_realm, "preload 4 true insightful", 10_000);
    manager.navigationPreload(fixture.page_environment, registration_id, .disable, 5);
    try drainUntil(fixture.sink, &fixture.page, "undefined 5", 10_000);
    manager.navigationPreload(fixture.page_environment, registration_id, .get_state, 6);
    try drainUntil(fixture.sink, &fixture.page, "preload 6 false insightful", 10_000);
    // A registration with no active worker (here: none at all) rejects
    // enable(), disable() and setHeaderValue() with an InvalidStateError.
    manager.navigationPreload(fixture.page_environment, registration_id + 1000, .enable, 7);
    try drainUntil(fixture.sink, &fixture.page, "reject 7 invalid_state_error", 10_000);
    manager.navigationPreload(fixture.page_environment, registration_id + 1000, .{ .set_header_value = "x" }, 8);
    try drainUntil(fixture.sink, &fixture.page, "reject 8 invalid_state_error", 10_000);
    manager.removeEnvironment(fixture.page_environment);
    manager.removeEnvironment(fixture.sw_environment);
}

test "Handle Fetch step 15: a GET navigation of a registration with navigation preload enabled carries its header value; a POST, a subresource or a disabled one none" {
    var fixture: Fixture = .{};
    try fixture.setUp();
    defer fixture.tearDown();
    const manager = &fixture.harness.manager;
    const a = fixture.allocator();
    const registration_id = blk: {
        var info = (try manager.registrationOfWorker(a, fixture.worker_id)).?;
        defer info.deinit(a);
        break :blk info.id;
    };
    const Case = struct { method: []const u8, enabled: bool, expect: ?[]const u8 };
    const cases = [_]Case{
        .{ .method = "GET", .enabled = false, .expect = null },
        .{ .method = "GET", .enabled = true, .expect = "hello" },
        .{ .method = "POST", .enabled = true, .expect = null },
    };
    manager.navigationPreload(fixture.page_environment, registration_id, .{ .set_header_value = "hello" }, 1);
    try drainUntil(fixture.sink, &fixture.page, "undefined 1", 10_000);
    for (cases, 0..) |case, i| {
        manager.navigationPreload(fixture.page_environment, registration_id, if (case.enabled) .enable else .disable, 10 + i);
        var line_buffer: [32]u8 = undefined;
        try drainUntil(fixture.sink, &fixture.page, try std.fmt.bufPrint(&line_buffer, "undefined {d}", .{10 + i}), 10_000);
        const reserved = manager.reserveClient(.window, fixture.page_environment, 0, .{ .nested = "https://example.com", .top_level = "https://example.com" }).?;
        const request = try InternalRequest.init(a, "https://example.com/frame.html");
        defer request.deinit();
        request.destination = .iframe;
        request.mode = .navigate;
        try request.setMethod(case.method);
        request.reserved_client = reserved;
        const route = manager.routeOfReserved();
        const call = (try route.handle(route.context, request, 0)).call;
        defer call.release();
        const kept = try fixture.harness.nextDispatch(10_000);
        if (case.expect) |value| {
            try testing.expectEqualStrings(value, kept.dispatch.preload_header.?);
        } else {
            try testing.expect(kept.dispatch.preload_header == null);
        }
        kept.dispatch.call.answer(.fallback);
        kept.dispatch.destroy();
        fixture.harness.done(kept);
        _ = call.wait(5_000) orelse return error.TestUnexpectedTimeout;
        manager.releaseReserved(reserved);
    }
    // A subresource request of a controlled client: never preloaded.
    try claim(manager, fixture.worker_id);
    const route = manager.routeForRealm(fixture.page.endpoint.realm).?;
    const request = try InternalRequest.init(a, "https://example.com/data.txt");
    defer request.deinit();
    const call = (try route.handle(route.context, request, route.client)).call;
    defer call.release();
    const kept = try fixture.harness.nextDispatch(10_000);
    try testing.expect(kept.dispatch.preload_header == null);
    kept.dispatch.call.answer(.fallback);
    kept.dispatch.destroy();
    fixture.harness.done(kept);
    _ = call.wait(5_000) orelse return error.TestUnexpectedTimeout;
    manager.removeEnvironment(fixture.page_environment);
    manager.removeEnvironment(fixture.sw_environment);
}

/// A realm's router steps, as the test plays them: URL patterns are test
/// suffixes; the cache holds one response for "https://example.com/cached".
const test_router_steps: manager_mod.RouterSteps = .{ .match_url_pattern = testMatchUrl, .cache_match = testCacheMatch };

fn testMatchUrl(_: *manager_mod.Endpoint, pattern: *anyopaque, url: []const u8) bool {
    const suffix: *const []const u8 = @ptrCast(@alignCast(pattern));
    return std.mem.endsWith(u8, url, suffix.*);
}

fn testCacheMatch(_: *manager_mod.Endpoint, allocator: std.mem.Allocator, storage_key: []const u8, cache_name: ?[]const u8, request: *const InternalRequest) ?manager_mod.CacheHit {
    if (!std.mem.eql(u8, storage_key, "https://example.com")) return null;
    if (cache_name) |name| if (!std.mem.eql(u8, name, "v1")) return null;
    if (!std.mem.eql(u8, request.currentUrl(), "https://example.com/cached")) return null;
    const response = testResponse(allocator, 299) catch return null;
    const body = allocator.dupe(u8, "From cache") catch {
        response.deinit();
        return null;
    };
    return .{ .response = response, .body = body };
}

fn noFreePattern(_: *anyopaque, _: std.mem.Allocator) void {}

/// Give the worker `rules` (taken) as addRoutes() would have.
fn setRules(manager: *Manager, worker_id: u64, rules: []sw.router.Rule) !void {
    std.Io.Threaded.mutexLock(&manager.mutex);
    defer std.Io.Threaded.mutexUnlock(&manager.mutex);
    const worker = manager.registry.findWorker(worker_id).?;
    worker.router_rules = try sw.router.Rules.create(manager.allocator, rules, .{ .free = noFreePattern });
}

fn setHandlesFetch(manager: *Manager, worker_id: u64, value: bool) void {
    std.Io.Threaded.mutexLock(&manager.mutex);
    defer std.Io.Threaded.mutexUnlock(&manager.mutex);
    manager.registry.findWorker(worker_id).?.handles_fetch = value;
}

test "Handle Fetch step 13: a matching rule's network source goes to the network; its cache source answers from the cache; fetch-event, and no match, fire the event" {
    var fixture: Fixture = .{};
    try fixture.setUp();
    defer fixture.tearDown();
    const manager = &fixture.harness.manager;
    const a = manager.allocator;
    fixture.page.endpoint.router = &test_router_steps;
    try claim(manager, fixture.worker_id);
    var direct: []const u8 = "/direct.txt";
    const rules = try a.alloc(sw.router.Rule, 3);
    rules[0] = .{ .condition = .{ .url_pattern = @ptrCast(&direct) }, .source = .network };
    rules[1] = .{ .condition = .{ .method = try a.dupe(u8, "GET"), .mode = .cors }, .source = .{ .cache = try a.dupe(u8, "v1") } };
    rules[2] = .{ .condition = .{ .mode = .same_origin }, .source = .fetch_event };
    try setRules(manager, fixture.worker_id, rules);
    const route = manager.routeForRealm(fixture.page.endpoint.realm).?;

    // network: matched by the URL pattern.
    const direct_request = try InternalRequest.init(a, "https://example.com/x/direct.txt");
    defer direct_request.deinit();
    try testing.expect(try route.handle(route.context, direct_request, route.client) == .network);

    // cache: answered at once, from the cache, body and all.
    const cached = try InternalRequest.init(a, "https://example.com/cached");
    defer cached.deinit();
    cached.mode = .cors;
    const call = (try route.handle(route.context, cached, route.client)).call;
    defer call.release();
    const answer = call.take() orelse return error.TestExpectedAnswer;
    try testing.expectEqual(@as(u16, 299), answer.response.response.status);
    const relay = answer.response.body.?;
    const body = try relay.collect(a, 1_000);
    defer a.free(body);
    try testing.expectEqualStrings("From cache", body);
    answer.response.response.deinit();
    relay.release();

    // cache, but the cache has none: the network.
    const missing = try InternalRequest.init(a, "https://example.com/not-cached");
    defer missing.deinit();
    missing.mode = .cors;
    try testing.expect(try route.handle(route.context, missing, route.client) == .network);

    // fetch-event, and no rule at all: the event fires.
    for ([_]fetch.internal.RequestMode{ .same_origin, .no_cors }) |mode| {
        const other = try InternalRequest.init(a, "https://example.com/other");
        defer other.deinit();
        other.mode = mode;
        const event_call = (try route.handle(route.context, other, route.client)).call;
        defer event_call.release();
        const kept = try fixture.harness.nextDispatch(10_000);
        kept.dispatch.call.answer(.fallback);
        kept.dispatch.destroy();
        fixture.harness.done(kept);
        _ = event_call.wait(5_000) orelse return error.TestUnexpectedTimeout;
    }
    manager.removeEnvironment(fixture.page_environment);
    manager.removeEnvironment(fixture.sw_environment);
}

test "Should Skip Event: a worker with no fetch listener is not asked - the network - but its router rules still are" {
    var fixture: Fixture = .{};
    try fixture.setUp();
    defer fixture.tearDown();
    const manager = &fixture.harness.manager;
    const a = manager.allocator;
    fixture.page.endpoint.router = &test_router_steps;
    try claim(manager, fixture.worker_id);
    setHandlesFetch(manager, fixture.worker_id, false);
    const route = manager.routeForRealm(fixture.page.endpoint.realm).?;
    const request = try InternalRequest.init(a, "https://example.com/data.txt");
    defer request.deinit();
    try testing.expect(try route.handle(route.context, request, route.client) == .network);
    // A navigation too - its reserved client controlled all the same.
    const reserved = manager.reserveClient(.window, fixture.page_environment, 0, .{ .nested = "https://example.com", .top_level = "https://example.com" }).?;
    const navigation = try InternalRequest.init(a, "https://example.com/frame.html");
    defer navigation.deinit();
    navigation.destination = .iframe;
    navigation.mode = .navigate;
    navigation.reserved_client = reserved;
    const reserved_route = manager.routeOfReserved();
    try testing.expect(try reserved_route.handle(reserved_route.context, navigation, 0) == .network);
    try testing.expectEqual(fixture.worker_id, controllerOf(manager, reserved.environment));
    manager.releaseReserved(reserved);
    // A cache rule answers without the worker.
    const rules = try a.alloc(sw.router.Rule, 1);
    rules[0] = .{ .condition = .{ .mode = .cors }, .source = .{ .cache = null } };
    try setRules(manager, fixture.worker_id, rules);
    const cached = try InternalRequest.init(a, "https://example.com/cached");
    defer cached.deinit();
    cached.mode = .cors;
    const call = (try route.handle(route.context, cached, route.client)).call;
    defer call.release();
    const answer = call.take() orelse return error.TestExpectedAnswer;
    try testing.expectEqual(@as(u16, 299), answer.response.response.status);
    answer.response.response.deinit();
    if (answer.response.body) |relay| {
        relay.cancel();
        relay.release();
    }
    manager.removeEnvironment(fixture.page_environment);
    manager.removeEnvironment(fixture.sw_environment);
}

test "Handle Fetch step 13.3.4: a race-network-and-fetch-handler rule's GET is handed back to race the network; another method is the fetch event's alone" {
    var fixture: Fixture = .{};
    try fixture.setUp();
    defer fixture.tearDown();
    const manager = &fixture.harness.manager;
    const a = manager.allocator;
    fixture.page.endpoint.router = &test_router_steps;
    try claim(manager, fixture.worker_id);
    const rules = try a.alloc(sw.router.Rule, 1);
    rules[0] = .{ .condition = .{ .mode = .cors }, .source = .race_network_and_fetch_handler };
    try setRules(manager, fixture.worker_id, rules);
    const route = manager.routeForRealm(fixture.page.endpoint.realm).?;

    // GET: the fetch event fires, and the call comes back as a race - the
    // fetching side starts the network beside it (13.3.4.5).
    const raced = try InternalRequest.init(a, "https://example.com/raced");
    defer raced.deinit();
    raced.mode = .cors;
    const call = switch (try route.handle(route.context, raced, route.client)) {
        .race => |c| c,
        else => return error.TestExpectedRace,
    };
    defer call.release();
    const kept = try fixture.harness.nextDispatch(10_000);
    // 13.3.4.6: no navigation preload for a raced request.
    try testing.expect(kept.dispatch.preload_header == null);
    kept.dispatch.call.answer(.fallback);
    kept.dispatch.destroy();
    fixture.harness.done(kept);
    _ = call.wait(5_000) orelse return error.TestUnexpectedTimeout;

    // POST: 13.3.4 is for a GET only - the fetch event answers alone.
    const posted = try InternalRequest.init(a, "https://example.com/raced");
    defer posted.deinit();
    posted.mode = .cors;
    try posted.setMethod("POST");
    const event_call = switch (try route.handle(route.context, posted, route.client)) {
        .call => |c| c,
        else => return error.TestExpectedCall,
    };
    defer event_call.release();
    const posted_kept = try fixture.harness.nextDispatch(10_000);
    posted_kept.dispatch.call.answer(.fallback);
    posted_kept.dispatch.destroy();
    fixture.harness.done(posted_kept);
    _ = event_call.wait(5_000) orelse return error.TestUnexpectedTimeout;
    manager.removeEnvironment(fixture.page_environment);
    manager.removeEnvironment(fixture.sw_environment);
}
