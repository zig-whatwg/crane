//! Cookie Store "process cookie changes" step 2 across threads: the Browser's
//! jar tells its CookieStore listeners (dom.cookie_change_listeners, the jar's
//! change hook), whose `registrations` slot is the service worker manager's;
//! the manager's job thread matches each change against the registrations'
//! cookie change subscription lists and fires "cookiechange" through its
//! host (Fire Functional Event). No engine: a fake host records what it would
//! fire, and the realm side is the test's endpoint.

const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const runtime = @import("runtime");
const dom = @import("dom");
const fetch = @import("fetch");
const sw = @import("service_worker");
const Manager = sw.Manager;
const manager_mod = sw.manager;
const registry = sw.registry;
const CookieChangeListeners = dom.cookie_change_listeners.CookieChangeListeners;
const Cookie = dom.cookie_change_listeners.Cookie;
const CookieJar = fetch.internal.CookieJar;

const scope = "https://example.com/app/";

/// A cookie as `cookieStore.set()` from https://example.com stores it.
fn makeCookie(allocator: std.mem.Allocator, name: []const u8, value: []const u8, path: []const u8) !Cookie {
    var cookie = try Cookie.init(allocator, name, value);
    errdefer cookie.deinit();
    try cookie.setDomain("example.com");
    cookie.host_only = true;
    try cookie.setPath(path);
    cookie.secure = true;
    return cookie;
}

/// Store `cookie` (borrowed) as another thread of the Browser would: under
/// the jar's lock, its change heard when the lock is released.
fn store(jar: *CookieJar, cookie: Cookie) !void {
    jar.lock();
    defer jar.unlock();
    try jar.store(cookie);
}

/// The manager, and what its host was asked to fire.
const Harness = struct {
    manager: Manager,
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    /// One line per fired event: "<changed name=value,...>|<deleted name,...>".
    fired: std.ArrayListUnmanaged([]u8) = .empty,

    fn init(allocator: std.mem.Allocator, manager_allocator: std.mem.Allocator) Harness {
        var manager = Manager.init(manager_allocator);
        manager.host = &fake_host;
        return .{ .manager = manager, .allocator = allocator };
    }

    fn deinitRecords(self: *Harness) void {
        for (self.fired.items) |line| self.allocator.free(line);
        self.fired.deinit(self.allocator);
    }

    fn firedCount(self: *Harness) usize {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.fired.items.len;
    }

    /// Wait until `n` events were fired, or `budget_ms` passed.
    fn waitFired(self: *Harness, n: usize, budget_ms: u64) !void {
        var waited: u64 = 0;
        while (self.firedCount() < n) {
            if (waited >= budget_ms) return error.Timeout;
            clock.sleep(5 * std.time.ns_per_ms);
            waited += 5;
        }
    }

    fn record(self: *Harness, event: *const sw.FunctionalEvent) void {
        var line: std.ArrayListUnmanaged(u8) = .empty;
        defer line.deinit(self.allocator);
        const lists = event.kind.cookie_change;
        for (lists.changed) |item| line.print(self.allocator, "{s}={s},", .{ item.name, item.value }) catch return;
        line.append(self.allocator, '|') catch return;
        for (lists.deleted) |item| {
            std.debug.assert(!item.has_value);
            line.print(self.allocator, "{s},", .{item.name}) catch return;
        }
        const owned = line.toOwnedSlice(self.allocator) catch return;
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.fired.append(self.allocator, owned) catch self.allocator.free(owned);
    }

    fn firedLine(self: *Harness, i: usize) []const u8 {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.fired.items[i];
    }
};

const fake_host: manager_mod.Host = .{
    .fetch = fakeFetch,
    .start = fakeStart,
    .dispatch = fakeDispatch,
    .post_message = fakePostMessage,
    .dispatch_fetch = fallbackDispatchFetch,
    .dispatch_functional = recordFunctional,
};

fn recordFunctional(manager: *Manager, _: manager_mod.Started, event: *sw.FunctionalEvent, worker_id: u64, generation: u64) void {
    const harness: *Harness = @fieldParentPtr("manager", manager);
    harness.record(event);
    const registration = event.registration_id;
    event.destroy();
    manager.report(.{ .functional_done = .{ .worker = worker_id, .generation = generation, .registration = registration } });
}

fn fallbackDispatchFetch(manager: *Manager, _: manager_mod.Started, dispatch: *manager_mod.FetchDispatch, worker_id: u64, generation: u64) void {
    dispatch.call.answer(.fallback);
    dispatch.destroy();
    manager.report(.{ .fetch_done = .{ .worker = worker_id, .generation = generation } });
}

fn fakeFetch(manager: *Manager, plan: *const registry.FetchPlan) registry.FetchOutcome {
    var outcome: registry.FetchOutcome = .{ .has_updated_resources = true, .checked_network = true };
    const allocator = manager.allocator;
    const url = allocator.dupe(u8, plan.script_url) catch return .{ .failure = .network };
    const body = allocator.dupe(u8, "self.oncookiechange = () => {};") catch return .{ .failure = .network };
    const content_type = allocator.dupe(u8, "text/javascript") catch return .{ .failure = .network };
    outcome.resources.append(allocator, .{ .url = url, .body = body, .content_type = content_type }) catch return .{ .failure = .network };
    return outcome;
}

fn fakeStart(manager: *Manager, start: *const manager_mod.WorkerStart) anyerror!manager_mod.Started {
    manager.report(.{ .evaluated = .{ .worker = start.worker_id, .ok = true, .handles_fetch = false } });
    return .{ .link = null };
}

fn fakeDispatch(manager: *Manager, _: manager_mod.Started, _: registry.LifecycleEvent, op: u64) void {
    manager.report(.{ .lifecycle_done = .{ .op = op, .failed = false } });
}

fn fakePostMessage(manager: *Manager, _: manager_mod.Started, message: *manager_mod.WorkerMessage, worker_id: u64, generation: u64) void {
    message.destroy();
    manager.report(.{ .message_done = .{ .worker = worker_id, .generation = generation } });
}

fn noWindowData(_: *manager_mod.Endpoint, _: std.mem.Allocator) ?manager_mod.WindowData {
    return null;
}

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
            .worker_state => |m| std.fmt.allocPrint(self.allocator, "state {s}", .{@tagName(m.state)}),
            .resolve_undefined => |m| std.fmt.allocPrint(self.allocator, "resolve {d}", .{m.promise}),
            .reject => |m| std.fmt.allocPrint(self.allocator, "reject {d} {s}", .{ m.promise, @tagName(m.kind) }),
            .resolve_cookie_subscriptions => |m| blk: {
                var text: std.ArrayListUnmanaged(u8) = .empty;
                defer text.deinit(self.allocator);
                text.print(self.allocator, "subscriptions {d}:", .{m.promise}) catch return;
                for (m.subscriptions) |s| text.print(self.allocator, " {s}@{s}", .{ s.name orelse "(null)", s.url }) catch return;
                break :blk text.toOwnedSlice(self.allocator);
            },
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
            if (waited >= budget_ms) {
                std.debug.print("never heard \"{s}\"; heard:\n", .{line});
                for (self.log.items) |item| std.debug.print("  {s}\n", .{item});
                return error.Timeout;
            }
            sink.waitForWork(10 * std.time.ns_per_ms);
            waited += 10;
            var posted: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
            defer posted.deinit(self.allocator);
            try sink.takeAll(&posted, self.allocator);
            for (posted.items) |task| task.run(task.data);
        }
    }
};

/// A page whose registration of `scope` is active: its environment id and
/// the registration's id.
fn registerActive(manager: *Manager, page: *TestEndpoint, sink: *runtime.TaskSink, allocator: std.mem.Allocator) !struct { environment: u64, registration: u64 } {
    const environment = try manager.addEnvironment(.{
        .kind = .window,
        .origin = "https://example.com",
        .creation_url = "https://example.com/app/page.html",
        .endpoint = &page.endpoint,
    });
    try manager.schedule(.{
        .job_type = .register,
        .storage_key = "https://example.com",
        .scope_url = scope,
        .script_url = "https://example.com/app/sw.js",
        .client = .{ .environment = environment, .promise = 1 },
        .referrer = "https://example.com/app/page.html",
    });
    try page.drainUntil(sink, "state activated", 10_000);
    var info = (try manager.match(allocator, "https://example.com", "https://example.com/app/page.html")).?;
    defer info.deinit(allocator);
    return .{ .environment = environment, .registration = info.id };
}

fn subscriptionCall(manager: *Manager, op: Manager.CookieSubscriptionsCall.Op, registration: u64, environment: u64, promise: u64, entries: []const sw.registry.ChangeSubscription) !void {
    const call = try Manager.CookieSubscriptionsCall.create(manager.allocator, op, registration, environment, promise);
    errdefer call.destroy();
    for (entries) |entry| try call.append(entry.name, entry.url);
    manager.cookieSubscriptions(call);
}

/// Counts what its child allocator is asked for.
const CountingAllocator = struct {
    child: std.mem.Allocator,
    allocations: std.atomic.Value(usize) = .init(0),

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        _ = self.allocations.fetchAdd(1, .monotonic);
        return self.child.rawAlloc(len, alignment, ret_addr);
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawRemap(memory, alignment, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(memory, alignment, ret_addr);
    }
};

test "with no subscription anywhere, a cookie change costs the manager one load: nothing allocated, nothing posted" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();
    var counting: CountingAllocator = .{ .child = allocator };

    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var listeners = CookieChangeListeners.init(allocator);
    defer listeners.deinit();
    listeners.hearJar(&jar);
    var harness = Harness.init(allocator, counting.allocator());
    defer harness.deinitRecords();
    defer harness.manager.deinit();
    harness.manager.hearCookieChanges(&listeners);

    const before = counting.allocations.load(.monotonic);
    var i: usize = 0;
    while (i < 200) : (i += 1) {
        var cookie = try makeCookie(allocator, "session", if (i % 2 == 0) "a" else "b", "/");
        defer cookie.deinit();
        try store(&jar, cookie);
    }
    try testing.expectEqual(before, counting.allocations.load(.monotonic));
    try testing.expectEqual(@as(u32, 0), harness.manager.cookie_interest.load(.monotonic));
    // Not even the job thread was started for it.
    try testing.expect(harness.manager.job_link == null);
}

test "a subscribed registration's worker gets one cookiechange per observed change, its lists prepared" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var listeners = CookieChangeListeners.init(allocator);
    defer listeners.deinit();
    listeners.hearJar(&jar);
    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var page = TestEndpoint.create(allocator, sink);
    defer page.deinit();
    var harness = Harness.init(allocator, allocator);
    defer harness.deinitRecords();
    defer harness.manager.deinit();
    harness.manager.hearCookieChanges(&listeners);

    const ids = try registerActive(&harness.manager, &page, sink, allocator);
    try subscriptionCall(&harness.manager, .subscribe, ids.registration, ids.environment, 7, &.{
        .{ .name = "session", .url = scope },
        .{ .name = "session", .url = scope },
        .{ .name = null, .url = "https://example.com/app/deeper" },
    });
    try page.drainUntil(sink, "resolve 7", 10_000);
    try subscriptionCall(&harness.manager, .get, ids.registration, ids.environment, 8, &.{});
    try page.drainUntil(sink, "subscriptions 8: session@https://example.com/app/ (null)@https://example.com/app/deeper", 10_000);

    // Observed: inserted, then removed (an expired cookie replacing it).
    var session = try makeCookie(allocator, "session", "1", "/");
    defer session.deinit();
    try store(&jar, session);
    try harness.waitFired(1, 10_000);
    try testing.expectEqualStrings("session=1,|", harness.firedLine(0));
    var expired = try makeCookie(allocator, "session", "gone", "/");
    defer expired.deinit();
    expired.expiry_time = 1;
    try store(&jar, expired);
    try harness.waitFired(2, 10_000);
    try testing.expectEqualStrings("|session,", harness.firedLine(1));

    // Not observed: another name under the scope only (the unnamed
    // subscription's url /app/deeper does not path-match /app/x's cookie),
    // a cookie whose path the scope does not path-match, an HttpOnly one.
    var other = try makeCookie(allocator, "other", "1", "/app/x");
    defer other.deinit();
    try store(&jar, other);
    var elsewhere = try makeCookie(allocator, "session", "2", "/elsewhere");
    defer elsewhere.deinit();
    try store(&jar, elsewhere);
    var http_only = try makeCookie(allocator, "session", "3", "/app/");
    defer http_only.deinit();
    http_only.http_only = true;
    try store(&jar, http_only);
    // Observed: the unnamed subscription's url sees a cookie of path /app/.
    var deeper = try makeCookie(allocator, "any", "4", "/app/");
    defer deeper.deinit();
    try store(&jar, deeper);
    try harness.waitFired(3, 10_000);
    try testing.expectEqualStrings("any=4,|", harness.firedLine(2));

    // Unsubscribed: nothing more.
    try subscriptionCall(&harness.manager, .unsubscribe, ids.registration, ids.environment, 9, &.{
        .{ .name = "session", .url = scope },
        .{ .name = null, .url = "https://example.com/app/deeper" },
    });
    try page.drainUntil(sink, "resolve 9", 10_000);
    var after = try makeCookie(allocator, "session", "5", "/");
    defer after.deinit();
    try store(&jar, after);
    clock.sleep(100 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 3), harness.firedCount());
    try testing.expectEqual(@as(u32, 0), harness.manager.cookie_interest.load(.monotonic));

    harness.manager.removeEnvironment(ids.environment);
}

test "a change made before subscribe()'s steps run never matches what they append: one FIFO" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var listeners = CookieChangeListeners.init(allocator);
    defer listeners.deinit();
    listeners.hearJar(&jar);
    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var page = TestEndpoint.create(allocator, sink);
    defer page.deinit();
    var harness = Harness.init(allocator, allocator);
    defer harness.deinitRecords();
    defer harness.manager.deinit();
    harness.manager.hearCookieChanges(&listeners);

    const ids = try registerActive(&harness.manager, &page, sink, allocator);
    const named: sw.registry.ChangeSubscription = .{ .name = "a", .url = scope };
    const any: sw.registry.ChangeSubscription = .{ .name = null, .url = scope };
    try subscriptionCall(&harness.manager, .subscribe, ids.registration, ids.environment, 2, &.{named});
    try page.drainUntil(sink, "resolve 2", 10_000);

    // A test's cleanup, then the next test's setup, with no wait between:
    // unsubscribe, a deletion, subscribe again. The deletion was made before
    // the second subscribe() - it must not reach the new subscription.
    try subscriptionCall(&harness.manager, .unsubscribe, ids.registration, ids.environment, 3, &.{named});
    var x = try makeCookie(allocator, "x", "1", "/");
    defer x.deinit();
    try store(&jar, x);
    try subscriptionCall(&harness.manager, .subscribe, ids.registration, ids.environment, 4, &.{any});
    var y = try makeCookie(allocator, "y", "1", "/");
    defer y.deinit();
    try store(&jar, y);
    try harness.waitFired(1, 10_000);
    clock.sleep(50 * std.time.ns_per_ms);
    try testing.expectEqual(@as(usize, 1), harness.firedCount());
    try testing.expectEqualStrings("y=1,|", harness.firedLine(0));
    try page.drainUntil(sink, "resolve 4", 10_000);
    try testing.expect(page.heard("resolve 3"));

    harness.manager.removeEnvironment(ids.environment);
}

test "a subscription url that failed its check rejects, after the entries before it were applied" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var page = TestEndpoint.create(allocator, sink);
    defer page.deinit();
    var harness = Harness.init(allocator, allocator);
    defer harness.deinitRecords();
    defer harness.manager.deinit();

    const ids = try registerActive(&harness.manager, &page, sink, allocator);
    // subscribe([{name: "first"}, {url: "/elsewhere"}]): the realm's steps
    // let the first through and stop at the second (4.2.5).
    const call = try Manager.CookieSubscriptionsCall.create(harness.manager.allocator, .subscribe, ids.registration, ids.environment, 5);
    try call.append("first", scope);
    call.failure = "The subscription url is not within the registration's scope";
    harness.manager.cookieSubscriptions(call);
    try page.drainUntil(sink, "reject 5 type_error", 10_000);
    try subscriptionCall(&harness.manager, .get, ids.registration, ids.environment, 6, &.{});
    try page.drainUntil(sink, "subscriptions 6: first@https://example.com/app/", 10_000);
    // The pending count it took is given back: only the list counts now.
    try testing.expectEqual(@as(u32, 1), harness.manager.cookie_interest.load(.monotonic));

    harness.manager.removeEnvironment(ids.environment);
}

/// One thread changing the jar without pause, as a worker's fetches would.
const Changer = struct {
    jar: *CookieJar,
    allocator: std.mem.Allocator,
    /// Stop after this many changes; 0: until `stop`.
    limit: usize,
    made: std.atomic.Value(usize) = .init(0),
    stop: std.atomic.Value(bool) = .init(false),
    failed: std.atomic.Value(bool) = .init(false),

    fn run(self: *Changer) void {
        var i: usize = 0;
        while (!self.stop.load(.acquire)) : (i += 1) {
            if (self.limit != 0 and i >= self.limit) break;
            var buffer: [32]u8 = undefined;
            const value = std.fmt.bufPrint(&buffer, "{d}", .{i}) catch unreachable;
            var cookie = makeCookie(self.allocator, "racer", value, "/") catch {
                self.failed.store(true, .release);
                return;
            };
            defer cookie.deinit();
            store(self.jar, cookie) catch {
                self.failed.store(true, .release);
                return;
            };
            _ = self.made.fetchAdd(1, .acq_rel);
        }
    }
};

test "the manager's end races a stream of cookie changes from another thread: none lost before, none reaches it after" {
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.debug.assert(debug_allocator.deinit() == .ok);
    const allocator = debug_allocator.allocator();

    var jar = CookieJar.init(allocator);
    defer jar.deinit();
    var listeners = CookieChangeListeners.init(allocator);
    defer listeners.deinit();
    listeners.hearJar(&jar);
    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    var page = TestEndpoint.create(allocator, sink);
    defer page.deinit();
    // The manager on a page of its own: once it is gone, any call into it
    // faults.
    const harness = try std.heap.page_allocator.create(Harness);
    harness.* = Harness.init(allocator, allocator);
    harness.manager.hearCookieChanges(&listeners);

    const ids = try registerActive(&harness.manager, &page, sink, allocator);
    try subscriptionCall(&harness.manager, .subscribe, ids.registration, ids.environment, 2, &.{.{ .name = "racer", .url = scope }});
    try page.drainUntil(sink, "resolve 2", 10_000);

    // 1. Fifty changes from another thread: every one fired, none lost.
    var first: Changer = .{ .jar = &jar, .allocator = allocator, .limit = 50 };
    const t1 = try std.Thread.spawn(.{}, Changer.run, .{&first});
    t1.join();
    try testing.expect(!first.failed.load(.acquire));
    try harness.waitFired(50, 20_000);
    try testing.expectEqual(@as(usize, 50), harness.firedCount());

    // 2. The manager ends while another thread keeps changing the jar.
    var second: Changer = .{ .jar = &jar, .allocator = allocator, .limit = 0 };
    const t2 = try std.Thread.spawn(.{}, Changer.run, .{&second});
    while (second.made.load(.acquire) < 20) clock.sleep(std.time.ns_per_ms);
    harness.manager.removeEnvironment(ids.environment);
    harness.manager.deinit();
    harness.deinitRecords();
    std.heap.page_allocator.destroy(harness);
    // The jar keeps changing after the manager is gone: nothing reaches it.
    const at_end = second.made.load(.acquire);
    while (second.made.load(.acquire) < at_end + 50) clock.sleep(std.time.ns_per_ms);
    second.stop.store(true, .release);
    t2.join();
    try testing.expect(!second.failed.load(.acquire));
    try testing.expect(listeners.registrations == null);
}
