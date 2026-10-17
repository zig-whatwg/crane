//! Two realms on two threads using one Browser's service worker manager at
//! once - registering and unregistering in their own scopes, environments
//! coming and going - while its job thread runs every job: the mutex, the
//! job queues, the Deliveries to each realm's own sink and the ends must
//! hold. Each realm thread drains only its own sink, as its loop would.
//! (Debug's hash-map and list safety checks turn a race into a panic.)

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const sw = @import("service_worker");
const Manager = sw.Manager;
const manager_mod = sw.manager;
const registry = sw.registry;

const fake_host: manager_mod.Host = .{
    .fetch = fakeFetch,
    .start = fakeStart,
    .dispatch = fakeDispatch,
    .post_message = fakePostMessage,
    .dispatch_fetch = fallbackDispatchFetch,
};

fn fallbackDispatchFetch(manager: *Manager, _: manager_mod.Started, dispatch: *manager_mod.FetchDispatch, worker_id: u64, generation: u64) void {
    dispatch.call.answer(.fallback);
    dispatch.destroy();
    manager.report(.{ .fetch_done = .{ .worker = worker_id, .generation = generation } });
}

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

/// Every message is handled at once.
fn fakePostMessage(manager: *Manager, _: manager_mod.Started, message: *manager_mod.WorkerMessage, worker_id: u64, generation: u64) void {
    message.destroy();
    manager.report(.{ .message_done = .{ .worker = worker_id, .generation = generation } });
}

fn noWindowData(_: *manager_mod.Endpoint, _: std.mem.Allocator) ?manager_mod.WindowData {
    return null;
}

/// One realm thread's side.
const Realm = struct {
    endpoint: manager_mod.Endpoint,
    resolved: usize = 0,

    fn deliver(endpoint: *manager_mod.Endpoint, delivery: *manager_mod.Delivery) void {
        const self: *Realm = @fieldParentPtr("endpoint", endpoint);
        switch (delivery.*) {
            .resolve_registration, .resolve_boolean => self.resolved += 1,
            else => {},
        }
    }
};

const rounds = 40;

fn realmThread(manager: *Manager, index: usize, failed: *std.atomic.Value(bool)) void {
    run(manager, index) catch {
        failed.store(true, .release);
    };
}

fn run(manager: *Manager, index: usize) !void {
    const allocator = manager.allocator;
    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var realm: Realm = .{ .endpoint = .{ .sink = sink, .deliver = Realm.deliver, .window_data = noWindowData, .window_data_now = noWindowData, .realm = @ptrCast(sink) } };
    var origin_buffer: [64]u8 = undefined;
    const origin = try std.fmt.bufPrint(&origin_buffer, "https://r{d}.example", .{index});
    var page_buffer: [96]u8 = undefined;
    const page = try std.fmt.bufPrint(&page_buffer, "{s}/page.html", .{origin});

    var environment = try manager.addEnvironment(.{ .kind = .window, .origin = origin, .creation_url = page, .endpoint = &realm.endpoint });
    var expected: usize = 0;
    var round: usize = 0;
    while (round < rounds) : (round += 1) {
        var scope_buffer: [128]u8 = undefined;
        const scope = try std.fmt.bufPrint(&scope_buffer, "{s}/s{d}/", .{ origin, round % 4 });
        var script_buffer: [128]u8 = undefined;
        const script = try std.fmt.bufPrint(&script_buffer, "{s}/sw{d}.js", .{ origin, round });
        try manager.schedule(.{ .job_type = .register, .storage_key = origin, .scope_url = scope, .script_url = script, .client = .{ .environment = environment, .promise = round * 2 }, .referrer = page });
        try manager.schedule(.{ .job_type = .unregister, .storage_key = origin, .scope_url = scope, .client = .{ .environment = environment, .promise = round * 2 + 1 }, .referrer = page });
        expected += 2;
        try drain(sink, &realm, expected);
        // Every few rounds the environment ends and another arrives.
        if (round % 7 == 6) {
            manager.removeEnvironment(environment);
            environment = try manager.addEnvironment(.{ .kind = .window, .origin = origin, .creation_url = page, .endpoint = &realm.endpoint });
        }
    }
    manager.removeEnvironment(environment);
    // What was posted to the ended environment finds nothing.
    try runPosted(sink, allocator);
}

fn drain(sink: *runtime.TaskSink, realm: *Realm, expected: usize) !void {
    var waited: usize = 0;
    while (realm.resolved < expected) {
        if (waited > 20_000) return error.Timeout;
        sink.waitForWork(5 * std.time.ns_per_ms);
        waited += 5;
        try runPosted(sink, std.heap.page_allocator);
    }
}

fn runPosted(sink: *runtime.TaskSink, allocator: std.mem.Allocator) !void {
    var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer posted.deinit(allocator);
    try sink.takeAll(&posted, allocator);
    for (posted.items) |task| task.run(task.data);
}

test "two realm threads register and unregister at once through one manager" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    var manager = Manager.init(allocator);
    manager.host = &fake_host;
    defer manager.deinit();

    var failed: std.atomic.Value(bool) = .init(false);
    const a = try std.Thread.spawn(.{}, realmThread, .{ &manager, 0, &failed });
    const b = try std.Thread.spawn(.{}, realmThread, .{ &manager, 1, &failed });
    a.join();
    b.join();
    try testing.expect(!failed.load(.acquire));
}
