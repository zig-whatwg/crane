//! The manager's message and client paths, across threads but without an
//! engine: ServiceWorker.postMessage's message reaches the worker's host
//! once Run Service Worker answers, Client.postMessage's reaches the client's
//! realm as a task, and Clients' matchAll() and get() gather each window
//! client's data on its own loop before the worker's realm hears the answer.
//! The realms are the test's endpoints; the "realm" thread is the test's.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const sw = @import("service_worker");
const Manager = sw.Manager;
const manager_mod = sw.manager;
const registry = sw.registry;

/// A manager with a host that counts the messages it is handed.
const Harness = struct {
    manager: Manager,
    messages: std.atomic.Value(u32) = .init(0),

    fn of(manager: *Manager) *Harness {
        return @fieldParentPtr("manager", manager);
    }
};

const counting_host: manager_mod.Host = .{
    .fetch = fakeFetch,
    .start = fakeStart,
    .dispatch = fakeDispatch,
    .post_message = countingPostMessage,
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
    manager.report(.{ .evaluated = .{ .worker = start.worker_id, .ok = true } });
    return .{ .link = null };
}

fn fakeDispatch(manager: *Manager, _: manager_mod.Started, _: registry.LifecycleEvent, op: u64) void {
    manager.report(.{ .lifecycle_done = .{ .op = op, .failed = false } });
}

fn countingPostMessage(manager: *Manager, _: manager_mod.Started, message: *manager_mod.WorkerMessage, worker_id: u64, generation: u64) void {
    message.destroy();
    _ = Harness.of(manager).messages.fetchAdd(1, .seq_cst);
    manager.report(.{ .message_done = .{ .worker = worker_id, .generation = generation } });
}

/// A realm, as the test plays it: what it heard, and its window data.
const TestEndpoint = struct {
    endpoint: manager_mod.Endpoint,
    allocator: std.mem.Allocator,
    log: std.ArrayListUnmanaged([]u8) = .empty,
    focused: bool = false,

    fn create(allocator: std.mem.Allocator, sink: *runtime.TaskSink) TestEndpoint {
        return .{
            .endpoint = .{ .sink = sink, .deliver = deliver, .window_data = windowData, .realm = @ptrCast(sink) },
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
            .client_message => |m| std.fmt.allocPrint(self.allocator, "message from {d} at {s}", .{ m.?.source.?.id, m.?.origin }),
            .resolve_clients => |m| blk: {
                var text: std.ArrayListUnmanaged(u8) = .empty;
                defer text.deinit(self.allocator);
                text.print(self.allocator, "clients {d}:", .{m.clients.len}) catch return;
                for (m.clients) |client| {
                    text.print(self.allocator, " {s}{s}", .{ @tagName(client.kind), if (client.window != null and client.window.?.focused) "(focused)" else "" }) catch return;
                }
                break :blk self.allocator.dupe(u8, text.items);
            },
            .resolve_client => |m| if (m.client) |client|
                std.fmt.allocPrint(self.allocator, "client {s}", .{@tagName(client.kind)})
            else
                std.fmt.allocPrint(self.allocator, "client undefined", .{}),
            .reject => |m| std.fmt.allocPrint(self.allocator, "reject {s}", .{@tagName(m.kind)}),
            else => std.fmt.allocPrint(self.allocator, "{s}", .{@tagName(delivery.*)}),
        } catch return;
        self.log.append(self.allocator, line) catch self.allocator.free(line);
    }

    fn windowData(endpoint: *manager_mod.Endpoint, allocator: std.mem.Allocator) ?manager_mod.WindowData {
        _ = allocator;
        const self: *TestEndpoint = @fieldParentPtr("endpoint", endpoint);
        return .{ .visible = true, .focused = self.focused };
    }

    fn heard(self: *const TestEndpoint, line: []const u8) bool {
        for (self.log.items) |item| if (std.mem.eql(u8, item, line)) return true;
        return false;
    }
};

/// Run what reaches `sink`, as a realm's loop would, until `endpoint` heard
/// `line` or `budget_ms` passed.
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

fn runPosted(sink: *runtime.TaskSink, allocator: std.mem.Allocator) !void {
    var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer posted.deinit(allocator);
    try sink.takeAll(&posted, allocator);
    for (posted.items) |task| task.run(task.data);
}

/// Register a service worker at https://example.com/ for `page` and run its
/// realm until it is activated: its id.
fn activate(manager: *Manager, sink: *runtime.TaskSink, page: *TestEndpoint, page_environment: u64) !u64 {
    try manager.schedule(.{
        .job_type = .register,
        .storage_key = "https://example.com",
        .scope_url = "https://example.com/",
        .script_url = "https://example.com/sw.js",
        .client = .{ .environment = page_environment, .promise = 1 },
        .referrer = "https://example.com/page.html",
    });
    try drainUntil(sink, page, "worker_state", 10_000);
    var waited: u64 = 0;
    while (waited < 10_000) : (waited += 10) {
        var match = (try manager.match(page.allocator, "https://example.com", "https://example.com/page.html")) orelse continue;
        defer match.deinit(page.allocator);
        if (match.active) |active| if (active.state == .activated) return active.id;
        sink.waitForWork(10 * std.time.ns_per_ms);
        try runPosted(sink, page.allocator);
    }
    return error.Timeout;
}

fn workerMessage(allocator: std.mem.Allocator, environment: u64) !*manager_mod.WorkerMessage {
    const message = try allocator.create(manager_mod.WorkerMessage);
    message.* = .{
        .allocator = allocator,
        .message = null,
        .origin = try allocator.dupe(u8, "https://example.com"),
        .source = .{ .client = .{
            .environment = environment,
            .id = @splat('0'),
            .url = try allocator.dupe(u8, "https://example.com/page.html"),
            .kind = .window,
            .window = .{},
        } },
    };
    return message;
}

fn clientMessage(allocator: std.mem.Allocator) !*manager_mod.ClientMessage {
    const message = try allocator.create(manager_mod.ClientMessage);
    message.* = .{ .allocator = allocator, .message = null, .origin = try allocator.dupe(u8, "https://example.com") };
    return message;
}

fn eventsInFlight(manager: *Manager, worker_id: u64) u32 {
    std.Io.Threaded.mutexLock(&manager.mutex);
    defer std.Io.Threaded.mutexUnlock(&manager.mutex);
    const worker = manager.registry.findWorker(worker_id) orelse return 0;
    return worker.events_in_flight;
}

test "a message to a service worker reaches its host once the worker runs, and is done after" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var page = TestEndpoint.create(allocator, sink);
    defer page.deinit();

    var harness: Harness = .{ .manager = Manager.init(allocator) };
    harness.manager.host = &counting_host;
    defer harness.manager.deinit();
    const manager = &harness.manager;

    const page_environment = try manager.addEnvironment(.{
        .kind = .window,
        .origin = "https://example.com",
        .creation_url = "https://example.com/page.html",
        .endpoint = &page.endpoint,
    });
    const worker_id = try activate(manager, sink, &page, page_environment);

    manager.postToWorker(worker_id, try workerMessage(allocator, page_environment));
    var waited: u64 = 0;
    while (harness.messages.load(.seq_cst) == 0 or eventsInFlight(manager, worker_id) != 0) : (waited += 10) {
        if (waited > 10_000) return error.Timeout;
        sink.waitForWork(10 * std.time.ns_per_ms);
        try runPosted(sink, allocator);
    }
    try testing.expectEqual(@as(u32, 1), harness.messages.load(.seq_cst));

    // A message to a worker that is not there is dropped, with what it
    // carries (the debug allocator checks).
    manager.postToWorker(worker_id + 1000, try workerMessage(allocator, page_environment));
    manager.removeEnvironment(page_environment);
}

test "Client.postMessage reaches the client's realm as a task; to a client that has gone, nothing" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var page = TestEndpoint.create(allocator, sink);
    defer page.deinit();

    var harness: Harness = .{ .manager = Manager.init(allocator) };
    harness.manager.host = &counting_host;
    defer harness.manager.deinit();
    const manager = &harness.manager;

    const page_environment = try manager.addEnvironment(.{
        .kind = .window,
        .origin = "https://example.com",
        .creation_url = "https://example.com/page.html",
        .endpoint = &page.endpoint,
    });
    const worker_id = try activate(manager, sink, &page, page_environment);

    manager.postToClient(page_environment, worker_id, try clientMessage(allocator));
    const expected = try std.fmt.allocPrint(allocator, "message from {d} at https://example.com", .{worker_id});
    defer allocator.free(expected);
    try drainUntil(sink, &page, expected, 10_000);

    manager.removeEnvironment(page_environment);
    manager.postToClient(page_environment, worker_id, try clientMessage(allocator));
    try runPosted(sink, allocator);
}

test "matchAll gathers each window client's data on its loop, then answers the worker's realm: windows first" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var page = TestEndpoint.create(allocator, sink);
    defer page.deinit();
    var dedicated = TestEndpoint.create(allocator, sink);
    defer dedicated.deinit();
    var frame = TestEndpoint.create(allocator, sink);
    defer frame.deinit();
    frame.focused = true;
    var worker_realm = TestEndpoint.create(allocator, sink);
    defer worker_realm.deinit();
    // A window whose loop has ended: its data task is discarded, and it is
    // not enumerable.
    const gone_sink = try runtime.TaskSink.create(allocator);
    defer gone_sink.release();
    var gone = TestEndpoint.create(allocator, gone_sink);
    defer gone.deinit();

    var harness: Harness = .{ .manager = Manager.init(allocator) };
    harness.manager.host = &counting_host;
    defer harness.manager.deinit();
    const manager = &harness.manager;

    const page_environment = try manager.addEnvironment(.{ .kind = .window, .origin = "https://example.com", .creation_url = "https://example.com/page.html", .endpoint = &page.endpoint });
    const worker_id = try activate(manager, sink, &page, page_environment);
    const dedicated_environment = try manager.addEnvironment(.{ .kind = .dedicated_worker, .origin = "https://example.com", .creation_url = "https://example.com/w.js", .endpoint = &dedicated.endpoint });
    const frame_environment = try manager.addEnvironment(.{ .kind = .window, .origin = "https://example.com", .creation_url = "https://example.com/frame.html", .endpoint = &frame.endpoint });
    const gone_environment = try manager.addEnvironment(.{ .kind = .window, .origin = "https://example.com", .creation_url = "https://example.com/gone.html", .endpoint = &gone.endpoint });
    const sw_environment = try manager.addEnvironment(.{ .kind = .service_worker, .origin = "https://example.com", .creation_url = "https://example.com/sw.js", .service_worker_id = worker_id, .endpoint = &worker_realm.endpoint });
    gone_sink.close();

    // Nothing is controlled: the default matches nothing.
    try manager.matchAll(sw_environment, worker_id, false, .window, 1);
    try drainUntil(sink, &worker_realm, "clients 0:", 10_000);

    // Every client: the focused window first, then the other windows in
    // creation order, then the worker client.
    try manager.matchAll(sw_environment, worker_id, true, .all, 2);
    try drainUntil(sink, &worker_realm, "clients 3: window(focused) window dedicated_worker", 10_000);

    // Only windows.
    try manager.matchAll(sw_environment, worker_id, true, .window, 3);
    try drainUntil(sink, &worker_realm, "clients 2: window(focused) window", 10_000);

    // get(id): a worker client at once, a window client after its data, and
    // an unknown id undefined.
    const dedicated_id = manager.clientIdOf(dedicated_environment).?;
    try manager.getClient(sw_environment, worker_id, &dedicated_id, 4);
    try drainUntil(sink, &worker_realm, "client dedicated_worker", 10_000);
    const frame_id = manager.clientIdOf(frame_environment).?;
    try manager.getClient(sw_environment, worker_id, &frame_id, 5);
    try drainUntil(sink, &worker_realm, "client window", 10_000);
    try manager.getClient(sw_environment, worker_id, "no-such-client", 6);
    try drainUntil(sink, &worker_realm, "client undefined", 10_000);

    for ([_]u64{ page_environment, dedicated_environment, frame_environment, gone_environment, sw_environment }) |id| manager.removeEnvironment(id);
}
