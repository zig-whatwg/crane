//! A Browser's service worker manager across threads: a realm's thread
//! schedules a job, the manager's job thread runs it - its fetch and the
//! worker's start answered by a fake host - and the realm hears every step
//! as a Delivery on its own sink, in order. No engine: the endpoint is the
//! test's, and so is the "realm" thread that drains it.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const sw = @import("service_worker");
const Manager = sw.Manager;
const manager_mod = sw.manager;
const registry = sw.registry;

/// A realm's side, as the test plays it: its sink, and what it heard.
const TestEndpoint = struct {
    endpoint: manager_mod.Endpoint,
    allocator: std.mem.Allocator,
    log: std.ArrayListUnmanaged([]u8) = .empty,

    fn create(allocator: std.mem.Allocator, sink: *runtime.TaskSink) TestEndpoint {
        return .{
            .endpoint = .{ .sink = sink, .deliver = deliver, .window_data = noWindowData, .window_data_now = noWindowData, .realm = @ptrCast(sink) },
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
            .resolve_registration => |m| std.fmt.allocPrint(self.allocator, "resolve {s}", .{m.registration.scope_url}),
            .worker_state => |m| std.fmt.allocPrint(self.allocator, "state {s}", .{@tagName(m.state)}),
            .registration_slot => |m| std.fmt.allocPrint(self.allocator, "{s} {s}", .{ @tagName(m.slot), if (m.worker == null) "null" else "set" }),
            .update_found => std.fmt.allocPrint(self.allocator, "updatefound", .{}),
            .ready => |info| std.fmt.allocPrint(self.allocator, "ready {s}", .{info.scope_url}),
            else => std.fmt.allocPrint(self.allocator, "{s}", .{@tagName(delivery.*)}),
        } catch return;
        self.log.append(self.allocator, line) catch self.allocator.free(line);
    }

    fn heard(self: *const TestEndpoint, line: []const u8) bool {
        for (self.log.items) |item| if (std.mem.eql(u8, item, line)) return true;
        return false;
    }

    /// Run what reaches the sink, as the realm's loop would, until `line`
    /// was heard or `budget_ms` passed.
    fn drainUntil(self: *TestEndpoint, sink: *runtime.TaskSink, line: []const u8, budget_ms: u64) !void {
        var waited: u64 = 0;
        while (!self.heard(line)) {
            if (waited >= budget_ms) return error.Timeout;
            sink.waitForWork(10 * std.time.ns_per_ms);
            waited += 10;
            var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
            defer posted.deinit(self.allocator);
            try sink.takeAll(&posted, self.allocator);
            for (posted.items) |task| task.run(task.data);
        }
    }
};

/// The fake host: every fetch finds a changed script, every worker starts
/// at once, every lifecycle event settles at once.
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
    const body = allocator.dupe(u8, "self.oninstall = () => {};") catch return .{ .failure = .network };
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

test "a register job runs on the job thread, and its realm hears Install and Activate in order" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var page = TestEndpoint.create(allocator, sink);
    defer page.deinit();

    var manager = Manager.init(allocator);
    manager.host = &fake_host;
    defer manager.deinit();

    const environment = try manager.addEnvironment(.{
        .kind = .window,
        .origin = "https://example.com",
        .creation_url = "https://example.com/page.html",
        .endpoint = &page.endpoint,
    });
    try manager.schedule(.{
        .job_type = .register,
        .storage_key = "https://example.com",
        .scope_url = "https://example.com/",
        .script_url = "https://example.com/sw.js",
        .client = .{ .environment = environment, .promise = 1 },
        .referrer = "https://example.com/page.html",
    });

    try page.drainUntil(sink, "state activated", 10_000);
    const expected = [_][]const u8{
        "installing set",
        "state installing",
        "resolve https://example.com/",
        "updatefound",
        "waiting set",
        "installing null",
        "state installed",
        "active set",
        "waiting null",
        "state activating",
        "ready https://example.com/",
        "state activated",
    };
    try testing.expectEqual(expected.len, page.log.items.len);
    for (expected, page.log.items) |want, got| try testing.expectEqualStrings(want, got);

    // The registration map has it, and matches the page's URLs under it.
    var match = (try manager.match(allocator, "https://example.com", "https://example.com/deeper/page.html")).?;
    defer match.deinit(allocator);
    try testing.expect(match.active != null);
    try testing.expectEqual(registry.WorkerState.activated, match.active.?.state);

    manager.removeEnvironment(environment);
}

test "an environment that ended hears nothing more, and its unsent deliveries are dropped" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var page = TestEndpoint.create(allocator, sink);
    defer page.deinit();

    var manager = Manager.init(allocator);
    manager.host = &fake_host;
    defer manager.deinit();

    const environment = try manager.addEnvironment(.{
        .kind = .window,
        .origin = "https://example.com",
        .creation_url = "https://example.com/page.html",
        .endpoint = &page.endpoint,
    });
    try manager.schedule(.{
        .job_type = .register,
        .storage_key = "https://example.com",
        .scope_url = "https://example.com/",
        .script_url = "https://example.com/sw.js",
        .client = .{ .environment = environment, .promise = 1 },
        .referrer = "https://example.com/page.html",
    });
    // The environment ends before its loop ran anything: what was posted to
    // it finds no environment and runs nothing.
    manager.removeEnvironment(environment);
    var waited: u64 = 0;
    while (waited < 300) : (waited += 10) {
        sink.waitForWork(10 * std.time.ns_per_ms);
        var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
        defer posted.deinit(allocator);
        try sink.takeAll(&posted, allocator);
        for (posted.items) |task| task.run(task.data);
    }
    try testing.expectEqual(@as(usize, 0), page.log.items.len);
}

/// A host whose lifecycle events never settle: waitUntil() with a promise
/// that never resolves.
const stuck_host: manager_mod.Host = .{
    .fetch = fakeFetch,
    .start = fakeStart,
    .dispatch = stuckDispatch,
    .post_message = fakePostMessage,
    .dispatch_fetch = fallbackDispatchFetch,
};

fn stuckDispatch(_: *Manager, _: manager_mod.Started, _: registry.LifecycleEvent, _: u64) void {}

test "an install event that never settles times out: the worker is redundant and the job queue moves on" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var page = TestEndpoint.create(allocator, sink);
    defer page.deinit();

    var manager = Manager.init(allocator);
    manager.host = &stuck_host;
    manager.lifecycle_timeout_ms = 50;
    defer manager.deinit();

    const environment = try manager.addEnvironment(.{
        .kind = .window,
        .origin = "https://example.com",
        .creation_url = "https://example.com/page.html",
        .endpoint = &page.endpoint,
    });
    try manager.schedule(.{
        .job_type = .register,
        .storage_key = "https://example.com",
        .scope_url = "https://example.com/",
        .script_url = "https://example.com/sw.js",
        .client = .{ .environment = environment, .promise = 1 },
        .referrer = "https://example.com/page.html",
    });
    // A second job for the scope waits behind the first.
    try manager.schedule(.{
        .job_type = .unregister,
        .storage_key = "https://example.com",
        .scope_url = "https://example.com/",
        .client = .{ .environment = environment, .promise = 2 },
        .referrer = "https://example.com/page.html",
    });
    try page.drainUntil(sink, "installing null", 10_000);
    try testing.expect(page.heard("state redundant"));
    // Install step 12.4 finished the job: the unregister ran, and found
    // nothing (step 12.3 removed the registration).
    try page.drainUntil(sink, "resolve_boolean", 10_000);
    try testing.expect((try manager.match(allocator, "https://example.com", "https://example.com/page.html")) == null);
    manager.removeEnvironment(environment);
}
