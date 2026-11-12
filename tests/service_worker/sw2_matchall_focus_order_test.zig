//! Clients' matchAll() order (Service Workers 4.3.4 matchAll() step 2.6.4):
//! window clients whose browsing context has been focused first, most
//! recently focused first; then the never-focused window clients in their
//! creation order; then worker clients in creation order. A focus time is the
//! browsing context's, so the next client of the same navigable carries it,
//! and equal times (one focus update refreshing a frame and its ancestors)
//! fall back to creation order (w3c/ServiceWorker#1080). The realms are the
//! test's endpoints, as in messages_test.zig; the focus times are given
//! directly (`Manager.environmentFocused`), as a window's focus update
//! reports them.

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
/// "clients:" and the clients' creation URLs' paths in the order given.
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

    fn heard(self: *const TestEndpoint, line: []const u8) bool {
        for (self.log.items) |item| if (std.mem.eql(u8, item, line)) return true;
        return false;
    }

    fn lastClients(self: *const TestEndpoint) []const u8 {
        var i = self.log.items.len;
        while (i > 0) {
            i -= 1;
            if (std.mem.startsWith(u8, self.log.items[i], "clients:")) return self.log.items[i];
        }
        return "";
    }
};

fn runPosted(sink: *runtime.TaskSink, allocator: std.mem.Allocator) !void {
    var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer posted.deinit(allocator);
    try sink.takeAll(&posted, allocator);
    for (posted.items) |task| task.run(task.data);
}

/// Run what reaches `sink` until `endpoint` heard a line starting with
/// `prefix` (or 10 s passed); that line.
fn drainUntilPrefix(sink: *runtime.TaskSink, endpoint: *TestEndpoint, prefix: []const u8, count: usize) ![]const u8 {
    var waited: u64 = 0;
    while (true) {
        var seen: usize = 0;
        for (endpoint.log.items) |item| if (std.mem.startsWith(u8, item, prefix)) {
            seen += 1;
        };
        if (seen >= count) return endpoint.lastClients();
        if (waited >= 10_000) return error.Timeout;
        sink.waitForWork(10 * std.time.ns_per_ms);
        waited += 10;
        try runPosted(sink, endpoint.allocator);
    }
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
    var waited: u64 = 0;
    while (waited < 10_000) : (waited += 10) {
        var match = (try manager.match(page.allocator, "https://example.com", "https://example.com/page.html")) orelse {
            sink.waitForWork(10 * std.time.ns_per_ms);
            try runPosted(sink, page.allocator);
            continue;
        };
        defer match.deinit(page.allocator);
        if (match.active) |active| if (active.state == .activated) return active.id;
        sink.waitForWork(10 * std.time.ns_per_ms);
        try runPosted(sink, page.allocator);
    }
    return error.Timeout;
}

const Fixture = struct {
    allocator: std.mem.Allocator,
    sink: *runtime.TaskSink,
    manager: Manager,
    endpoints: [8]TestEndpoint = undefined,
    used: usize = 0,
    sw_realm: TestEndpoint = undefined,
    worker_id: u64 = 0,
    sw_environment: u64 = 0,
    promise: u64 = 10,

    fn init(self: *Fixture, allocator: std.mem.Allocator) !void {
        self.* = .{ .allocator = allocator, .sink = try runtime.TaskSink.create(allocator), .manager = Manager.init(allocator) };
        self.manager.host = &host;
        self.sw_realm = TestEndpoint.create(allocator, self.sink);
    }

    fn deinit(self: *Fixture) void {
        self.manager.deinit();
        for (self.endpoints[0..self.used]) |*e| e.deinit();
        self.sw_realm.deinit();
        self.sink.release();
    }

    fn endpoint(self: *Fixture) *TestEndpoint {
        self.endpoints[self.used] = TestEndpoint.create(self.allocator, self.sink);
        self.used += 1;
        return &self.endpoints[self.used - 1];
    }

    /// A window client made the way a realm is made (`createClient`).
    fn window(self: *Fixture, path: []const u8, navigable: usize) !u64 {
        var buffer: [128]u8 = undefined;
        const url = try std.fmt.bufPrint(&buffer, "https://example.com{s}", .{path});
        return self.manager.createClient(.{
            .kind = .window,
            .origin = "https://example.com",
            .creation_url = url,
            .secure_context = true,
            .endpoint = &self.endpoint().endpoint,
            .navigable = navigable,
        });
    }

    fn startWorker(self: *Fixture, page_environment: u64) !void {
        self.worker_id = try activate(&self.manager, self.sink, &self.endpoints[0], page_environment);
        self.sw_environment = try self.manager.addEnvironment(.{ .kind = .service_worker, .origin = "https://example.com", .creation_url = "https://example.com/sw.js", .service_worker_id = self.worker_id, .endpoint = &self.sw_realm.endpoint });
    }

    fn matchAll(self: *Fixture) ![]const u8 {
        const before = blk: {
            var n: usize = 0;
            for (self.sw_realm.log.items) |item| if (std.mem.startsWith(u8, item, "clients:")) {
                n += 1;
            };
            break :blk n;
        };
        self.promise += 1;
        try self.manager.matchAll(self.sw_environment, self.worker_id, true, .all, self.promise);
        return drainUntilPrefix(self.sink, &self.sw_realm, "clients:", before + 1);
    }
};

test "matchAll: windows most recently focused first, never-focused windows in creation order, then workers" {
    var fixture: Fixture = undefined;
    try fixture.init(testing.allocator);
    defer fixture.deinit();
    const manager = &fixture.manager;

    const page = try fixture.window("/page.html", 0);
    try fixture.startWorker(page);
    const w1 = try fixture.window("/w1.html", 0);
    const w2 = try fixture.window("/w2.html", 0);
    const w3 = try fixture.window("/w3.html", 0);
    const dedicated = try manager.addEnvironment(.{ .kind = .dedicated_worker, .origin = "https://example.com", .creation_url = "https://example.com/d.js", .endpoint = &fixture.endpoint().endpoint });
    _ = dedicated;

    // Never focused: creation order, windows before the worker client.
    try testing.expectEqualStrings("clients: /page.html /w1.html /w2.html /w3.html /d.js", try fixture.matchAll());

    // Focused w1, then w3, then w2: most recent first, the others after in
    // creation order.
    manager.environmentFocused(w1, 1_000);
    manager.environmentFocused(w3, 2_000);
    manager.environmentFocused(w2, 3_000);
    try testing.expectEqualStrings("clients: /w2.html /w3.html /w1.html /page.html /d.js", try fixture.matchAll());

    // w1 again: it moves to the front.
    manager.environmentFocused(w1, 4_000);
    try testing.expectEqualStrings("clients: /w1.html /w2.html /w3.html /page.html /d.js", try fixture.matchAll());
}

test "matchAll: equal focus times - a frame and its ancestors in one focus update - keep creation order" {
    var fixture: Fixture = undefined;
    try fixture.init(testing.allocator);
    defer fixture.deinit();
    const manager = &fixture.manager;

    const page = try fixture.window("/page.html", 0);
    try fixture.startWorker(page);
    const top0 = try fixture.window("/top0.html", 0);
    const top1 = try fixture.window("/top1.html", 0);
    const nested1 = try fixture.window("/nested1.html", 0);
    const top2 = try fixture.window("/top2.html", 0);
    // clients-matchall-order.https.html's last case: focus top0, top1, then
    // nested1 (which refreshes top1 and the page with the same time), top2.
    manager.environmentFocused(top0, 10);
    manager.environmentFocused(page, 10);
    manager.environmentFocused(top1, 20);
    manager.environmentFocused(page, 20);
    manager.environmentFocused(nested1, 30);
    manager.environmentFocused(top1, 30);
    manager.environmentFocused(page, 30);
    manager.environmentFocused(top2, 40);
    manager.environmentFocused(page, 40);
    try testing.expectEqualStrings("clients: /page.html /top2.html /top1.html /nested1.html /top0.html", try fixture.matchAll());
}

test "matchAll: a frame's next document keeps its focus time when the old one unloads before the new one is a client" {
    var fixture: Fixture = undefined;
    try fixture.init(testing.allocator);
    defer fixture.deinit();
    const manager = &fixture.manager;

    const page = try fixture.window("/page.html", 0);
    try fixture.startWorker(page);
    const frame_a = try fixture.window("/a.html", 7);
    const other = try fixture.window("/other.html", 8);
    manager.environmentFocused(frame_a, 100);
    manager.environmentFocused(other, 50);
    // The frame navigates as HTMLIFrameElement does: the navigation reserves
    // its client from the frame's own document, that document unloads (its
    // environment ends), and only then does the new document become a client.
    const reserved = manager.reserveClient(.window, frame_a, 0, .{}) orelse return error.OutOfMemory;
    manager.removeEnvironment(frame_a);
    _ = try manager.createClient(.{
        .kind = .window,
        .origin = "https://example.com",
        .creation_url = "https://example.com/b.html",
        .secure_context = true,
        .endpoint = &fixture.endpoint().endpoint,
        .reserved = reserved,
        .navigable = 7,
    });
    try testing.expectEqualStrings("clients: /b.html /other.html /page.html", try fixture.matchAll());
}

test "matchAll: a focus time is the browsing context's - the next client of the same navigable carries it" {
    var fixture: Fixture = undefined;
    try fixture.init(testing.allocator);
    defer fixture.deinit();
    const manager = &fixture.manager;

    const page = try fixture.window("/page.html", 0);
    try fixture.startWorker(page);
    const frame_a = try fixture.window("/a.html", 7);
    const other = try fixture.window("/other.html", 8);
    manager.environmentFocused(frame_a, 100);
    manager.environmentFocused(other, 50);
    // The frame navigates: its next document is a new client of navigable 7.
    _ = try fixture.window("/b.html", 7);
    manager.removeEnvironment(frame_a);
    try testing.expectEqualStrings("clients: /b.html /other.html /page.html", try fixture.matchAll());
}
