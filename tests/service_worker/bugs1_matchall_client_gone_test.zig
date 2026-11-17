//! clients.matchAll() settles when a window client goes away mid-query
//! (lane bugs1, item 6a, hypothesis H3).
//!
//! matchAll() step 2.5.1.6 gathers each window client's window data on that
//! client's own event loop: the manager posts a WindowDataTask to the
//! client's sink and settles the promise once every slot has answered. A
//! slot whose task never answered - neither run nor dropped - would leave the
//! promise pending for ever: service-workers/service-worker/
//! client-url-creation-url.https.html timed out in sweeps (1 in 20, "TIMEOUT
//! 8") in a subtest whose frame was navigating while its service worker
//! called matchAll(). Here the client goes away between the post and the run
//! in each way it can: its environment ends first (the task runs and finds
//! none), and its loop ends first (the sink drops the task). Each must still
//! settle, with the other clients.
//!
//! The realms are the test's endpoints, as in sw2_matchall_focus_order_test.zig.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const sw = @import("service_worker");
const Manager = sw.Manager;
const manager_mod = sw.manager;
const registry = sw.registry;

const host: manager_mod.Host = .{
    .fetch = fakeFetch,
    .start = fakeStart,
    .dispatch = fakeDispatch,
    .post_message = dropMessage,
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

fn dropMessage(manager: *Manager, _: manager_mod.Started, message: *manager_mod.WorkerMessage, worker_id: u64, generation: u64) void {
    message.destroy();
    manager.report(.{ .message_done = .{ .worker = worker_id, .generation = generation } });
}

/// A realm, as the test plays it: the matchAll() answers it heard, each as
/// "clients:" and the clients' creation URLs' paths.
const TestEndpoint = struct {
    endpoint: manager_mod.Endpoint,
    allocator: std.mem.Allocator,
    log: std.ArrayListUnmanaged([]u8) = .empty,

    fn create(allocator: std.mem.Allocator, sink: *runtime.TaskSink) TestEndpoint {
        return .{
            .endpoint = .{ .sink = sink, .deliver = deliver, .window_data = windowData, .window_data_now = windowData, .realm = @ptrCast(sink) },
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
            .resolve_clients => |m| blk: {
                var text: std.ArrayListUnmanaged(u8) = .empty;
                defer text.deinit(self.allocator);
                text.appendSlice(self.allocator, "clients:") catch return;
                for (m.clients) |client| {
                    const path = client.url["https://example.com".len..];
                    text.print(self.allocator, " {s}", .{path}) catch return;
                }
                break :blk self.allocator.dupe(u8, text.items);
            },
            else => std.fmt.allocPrint(self.allocator, "{s}", .{@tagName(delivery.*)}),
        } catch return;
        self.log.append(self.allocator, line) catch self.allocator.free(line);
    }

    fn windowData(_: *manager_mod.Endpoint, _: std.mem.Allocator) ?manager_mod.WindowData {
        return .{ .visible = true, .focused = false };
    }

    fn lastClients(self: *const TestEndpoint) ?[]const u8 {
        var i = self.log.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.startsWith(u8, self.log.items[i], "clients:")) return self.log.items[i];
        }
        return null;
    }
};

fn runPosted(sink: *runtime.TaskSink, allocator: std.mem.Allocator) !void {
    var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer posted.deinit(allocator);
    try sink.takeAll(&posted, allocator);
    for (posted.items) |task| task.run(task.data);
}

/// Run what reaches `sink` until `endpoint` heard a matchAll() answer, or 5 s
/// passed (a promise that never settles): that answer.
fn settled(sink: *runtime.TaskSink, endpoint: *TestEndpoint) ![]const u8 {
    var waited: u64 = 0;
    while (true) {
        if (endpoint.lastClients()) |line| return line;
        if (waited >= 5_000) return error.MatchAllNeverSettled;
        sink.waitForWork(10 * std.time.ns_per_ms);
        waited += 10;
        try runPosted(sink, endpoint.allocator);
    }
}

/// Register a service worker at https://example.com/ for `page` and run its
/// realm until it is activated: its id.
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
        var match = (try manager.match(allocator, "https://example.com", "https://example.com/page.html")) orelse {
            sink.waitForWork(10 * std.time.ns_per_ms);
            try runPosted(sink, allocator);
            continue;
        };
        defer match.deinit(allocator);
        if (match.active) |active| if (active.state == .activated) return active.id;
        sink.waitForWork(10 * std.time.ns_per_ms);
        try runPosted(sink, allocator);
    }
    return error.Timeout;
}

/// The page and the service worker share one loop (`sink`); the frame that
/// goes away has a loop of its own (`frame_sink`), which the test runs - or
/// ends - itself.
const Fixture = struct {
    allocator: std.mem.Allocator,
    sink: *runtime.TaskSink,
    frame_sink: *runtime.TaskSink,
    manager: Manager,
    page: TestEndpoint = undefined,
    frame: TestEndpoint = undefined,
    sw_realm: TestEndpoint = undefined,
    page_id: u64 = 0,
    frame_id: u64 = 0,
    worker_id: u64 = 0,
    sw_environment: u64 = 0,

    fn init(self: *Fixture, allocator: std.mem.Allocator) !void {
        const sink = try runtime.TaskSink.create(allocator);
        errdefer sink.release();
        const frame_sink = try runtime.TaskSink.create(allocator);
        self.* = .{ .allocator = allocator, .sink = sink, .frame_sink = frame_sink, .manager = Manager.init(allocator) };
        self.manager.host = &host;
        self.page = TestEndpoint.create(allocator, sink);
        self.frame = TestEndpoint.create(allocator, frame_sink);
        self.sw_realm = TestEndpoint.create(allocator, sink);
        self.page_id = try self.window(&self.page, "/page.html", 0);
        self.worker_id = try activate(&self.manager, sink, allocator, self.page_id);
        self.sw_environment = try self.manager.addEnvironment(.{ .kind = .service_worker, .origin = "https://example.com", .creation_url = "https://example.com/sw.js", .service_worker_id = self.worker_id, .endpoint = &self.sw_realm.endpoint });
        self.frame_id = try self.window(&self.frame, "/frame.html?step=2", 7);
    }

    fn deinit(self: *Fixture) void {
        self.manager.deinit();
        self.page.deinit();
        self.frame.deinit();
        self.sw_realm.deinit();
        self.frame_sink.release();
        self.sink.release();
    }

    fn window(self: *Fixture, endpoint: *TestEndpoint, path: []const u8, navigable: usize) !u64 {
        var buffer: [128]u8 = undefined;
        const url = try std.fmt.bufPrint(&buffer, "https://example.com{s}", .{path});
        return self.manager.createClient(.{
            .kind = .window,
            .origin = "https://example.com",
            .creation_url = url,
            .secure_context = true,
            .endpoint = &endpoint.endpoint,
            .navigable = navigable,
        });
    }

    /// The service worker's clients.matchAll({includeUncontrolled: true}).
    fn matchAll(self: *Fixture) !void {
        try self.manager.matchAll(self.sw_environment, self.worker_id, true, .window, 50);
    }
};

test "matchAll() settles when a window client's environment ends after its window data was asked for" {
    var fixture: Fixture = undefined;
    try fixture.init(testing.allocator);
    defer fixture.deinit();

    try fixture.matchAll();
    // The frame's document unloads before its loop runs the request: its
    // environment ends first (its realm's unloading cleanup).
    fixture.manager.removeEnvironment(fixture.frame_id);
    try runPosted(fixture.frame_sink, testing.allocator);
    try testing.expectEqualStrings("clients: /page.html", try settled(fixture.sink, &fixture.sw_realm));
}

test "matchAll() settles when a window client's loop ends with its window-data request still queued" {
    var fixture: Fixture = undefined;
    try fixture.init(testing.allocator);
    defer fixture.deinit();

    try fixture.matchAll();
    // The frame's loop ends with the request in its inbox: the sink drops it
    // (TaskSink.close runs each queued task's drop).
    fixture.frame_sink.close();
    fixture.manager.removeEnvironment(fixture.frame_id);
    try testing.expectEqualStrings("clients: /page.html", try settled(fixture.sink, &fixture.sw_realm));
}

test "matchAll() settles with every client when each one answers" {
    var fixture: Fixture = undefined;
    try fixture.init(testing.allocator);
    defer fixture.deinit();

    try fixture.matchAll();
    try runPosted(fixture.frame_sink, testing.allocator);
    try testing.expectEqualStrings("clients: /page.html /frame.html?step=2", try settled(fixture.sink, &fixture.sw_realm));
}
