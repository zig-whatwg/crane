//! The service worker registry's algorithms, driven without threads or an
//! engine: a recording Effects stands in for the owner, and the tests answer
//! what the algorithms wait for (the script fetch, the worker's start, the
//! lifecycle events) by calling the registry's resume steps.

const std = @import("std");
const testing = std.testing;
const sw = @import("service_worker");
const reg = sw.registry;
const Registry = reg.Registry;

/// What the algorithms asked of their owner, in order.
const Recorder = struct {
    allocator: std.mem.Allocator,
    log: std.ArrayListUnmanaged([]u8) = .empty,
    run_jobs: std.ArrayListUnmanaged([]u8) = .empty,
    started: std.ArrayListUnmanaged(u64) = .empty,
    terminated: std.ArrayListUnmanaged(u64) = .empty,
    lifecycle: std.ArrayListUnmanaged(struct { worker: u64, event: reg.LifecycleEvent, op: u64 }) = .empty,
    idled: std.ArrayListUnmanaged(u64) = .empty,
    /// Each `other` waiter's answer: (worker, waiter, ok).
    answered: std.ArrayListUnmanaged(struct { worker: u64, waiter: u64, ok: bool }) = .empty,
    now: i64 = 1_000_000,

    fn deinit(self: *Recorder) void {
        for (self.log.items) |line| self.allocator.free(line);
        self.log.deinit(self.allocator);
        for (self.run_jobs.items) |s| self.allocator.free(s);
        self.run_jobs.deinit(self.allocator);
        self.started.deinit(self.allocator);
        self.terminated.deinit(self.allocator);
        self.lifecycle.deinit(self.allocator);
        self.idled.deinit(self.allocator);
        self.answered.deinit(self.allocator);
    }

    fn effects(self: *Recorder) reg.Effects {
        return .{
            .ctx = self,
            .notify = notify,
            .queue_run_job = queueRunJob,
            .start_worker = startWorker,
            .terminate_worker = terminateWorker,
            .dispatch_lifecycle = dispatchLifecycle,
            .start_answered = startAnswered,
            .free_fetch_client = freeNothing,
            .free_policy = freeNothing,
            .now_ms = nowMs,
            .idle = idle,
        };
    }

    fn of(ctx: *anyopaque) *Recorder {
        return @ptrCast(@alignCast(ctx));
    }

    fn notify(ctx: *anyopaque, environment: *reg.Environment, message: reg.Message) void {
        const self = of(ctx);
        const line = switch (message) {
            .resolve_registration => |m| std.fmt.allocPrint(self.allocator, "{d}: resolve registration {s}", .{ environment.id, m.registration.scope_url }),
            .resolve_boolean => |m| std.fmt.allocPrint(self.allocator, "{d}: resolve {}", .{ environment.id, m.value }),
            .resolve_undefined => std.fmt.allocPrint(self.allocator, "{d}: resolve undefined", .{environment.id}),
            .reject => |m| std.fmt.allocPrint(self.allocator, "{d}: reject {s}", .{ environment.id, @tagName(m.kind) }),
            .worker_state => |m| std.fmt.allocPrint(self.allocator, "{d}: worker {d} {s}", .{ environment.id, m.worker, @tagName(m.state) }),
            .registration_slot => |m| std.fmt.allocPrint(self.allocator, "{d}: {s} = {d}", .{ environment.id, @tagName(m.slot), if (m.worker) |w| w.id else 0 }),
            .update_found => std.fmt.allocPrint(self.allocator, "{d}: updatefound", .{environment.id}),
            .controller_change => std.fmt.allocPrint(self.allocator, "{d}: controllerchange", .{environment.id}),
            .ready => |m| std.fmt.allocPrint(self.allocator, "{d}: ready {s}", .{ environment.id, m.scope_url }),
        } catch return;
        self.log.append(self.allocator, line) catch self.allocator.free(line);
    }

    fn queueRunJob(ctx: *anyopaque, scope_url: []const u8) void {
        const self = of(ctx);
        const copy = self.allocator.dupe(u8, scope_url) catch return;
        self.run_jobs.append(self.allocator, copy) catch self.allocator.free(copy);
    }

    fn startWorker(ctx: *anyopaque, worker: *reg.Worker, _: bool) void {
        of(ctx).started.append(of(ctx).allocator, worker.id) catch {};
    }

    fn terminateWorker(ctx: *anyopaque, worker: *reg.Worker) void {
        of(ctx).terminated.append(of(ctx).allocator, worker.id) catch {};
    }

    fn dispatchLifecycle(ctx: *anyopaque, worker: *reg.Worker, event: reg.LifecycleEvent, op: u64) void {
        of(ctx).lifecycle.append(of(ctx).allocator, .{ .worker = worker.id, .event = event, .op = op }) catch {};
    }

    fn startAnswered(ctx: *anyopaque, worker: *reg.Worker, waiter: u64, ok: bool) void {
        of(ctx).answered.append(of(ctx).allocator, .{ .worker = worker.id, .waiter = waiter, .ok = ok }) catch {};
    }
    fn freeNothing(_: *anyopaque, _: *anyopaque) void {}

    fn nowMs(ctx: *anyopaque) i64 {
        return of(ctx).now;
    }

    fn idle(ctx: *anyopaque, worker: *reg.Worker) void {
        of(ctx).idled.append(of(ctx).allocator, worker.id) catch {};
    }

    /// Run the queued Run Job tasks, in order; return the fetch the last one
    /// asked for (the caller owns it).
    fn runQueuedJobs(self: *Recorder, registry: *Registry) !?reg.FetchPlan {
        var plan: ?reg.FetchPlan = null;
        while (self.run_jobs.items.len > 0) {
            const scope_url = self.run_jobs.orderedRemove(0);
            defer self.allocator.free(scope_url);
            if (plan) |*p| p.deinit(self.allocator);
            plan = try registry.runJob(scope_url);
        }
        return plan;
    }

    fn expectLog(self: *Recorder, expected: []const []const u8) !void {
        defer {
            for (self.log.items) |line| self.allocator.free(line);
            self.log.clearRetainingCapacity();
        }
        if (self.log.items.len != expected.len) {
            std.debug.print("log:\n", .{});
            for (self.log.items) |line| std.debug.print("  {s}\n", .{line});
        }
        try testing.expectEqual(expected.len, self.log.items.len);
        for (expected, self.log.items) |e, got| try testing.expectEqualStrings(e, got);
    }
};

var endpoint_dummy: u8 = 0;

fn addWindow(registry: *Registry, url: []const u8) !*reg.Environment {
    return registry.addEnvironment(.{
        .kind = .window,
        .origin = "https://example.com",
        .creation_url = url,
        .endpoint = &endpoint_dummy,
    });
}

fn registerJob(registry: *Registry, client: *reg.Environment, script: []const u8, scope_url: []const u8, promise: u64) !void {
    const job = try registry.createJob(.{
        .job_type = .register,
        .storage_key = "https://example.com",
        .scope_url = scope_url,
        .script_url = script,
        .client = .{ .environment = client.id, .promise = promise },
        .referrer = client.creation_url,
    });
    try registry.scheduleJob(job);
}

/// The fetch answered: the main script, with `body`, changed or not.
fn answerFetch(registry: *Registry, plan: *reg.FetchPlan, body: []const u8, changed: bool) !void {
    defer plan.deinit(testing.allocator);
    var outcome: reg.FetchOutcome = .{ .has_updated_resources = changed, .checked_network = true };
    try outcome.resources.append(testing.allocator, .{
        .url = try testing.allocator.dupe(u8, plan.script_url),
        .body = try testing.allocator.dupe(u8, body),
        .content_type = try testing.allocator.dupe(u8, "text/javascript"),
    });
    try registry.updateFetched(plan.job, &outcome);
}

test "a registration runs Register, Update, Install and Activate, and each realm hears it in order" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 1);
    defer registry.deinit();

    const page = try addWindow(&registry, "https://example.com/page.html");
    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/", 7);
    // Schedule Job step 5: the queue was empty - Run Job is queued.
    try testing.expectEqual(@as(usize, 1), recorder.run_jobs.items.len);

    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try testing.expectEqualStrings("https://example.com/sw.js", plan.script_url);
    try testing.expect(plan.newest == null);
    // Fetch hook step 2: update via cache "imports" bypasses the HTTP cache.
    try testing.expect(plan.bypass_http_cache);
    try answerFetch(&registry, &plan, "self.oninstall = () => {};", true);

    // Update step 15: Run Service Worker.
    try testing.expectEqual(@as(usize, 1), recorder.started.items.len);
    const worker_id = recorder.started.items[0];
    try registry.workerEvaluated(worker_id, true);

    // Install steps 4-11: installing, its state, the job promise, updatefound,
    // then the install event.
    try recorder.expectLog(&.{
        "1: installing = 4",
        "1: worker 4 installing",
        "1: resolve registration https://example.com/",
        "1: updatefound",
    });
    try testing.expectEqual(@as(u64, 4), worker_id);
    try testing.expectEqual(@as(usize, 1), recorder.lifecycle.items.len);
    try testing.expectEqual(reg.LifecycleEvent.install, recorder.lifecycle.items[0].event);
    try registry.lifecycleEventDone(recorder.lifecycle.items[0].op, false);

    // Install 17-19 and Activate 3-7 (no client uses it: activated at once),
    // then the activate event.
    try recorder.expectLog(&.{
        "1: waiting = 4",
        "1: installing = 0",
        "1: worker 4 installed",
        "1: active = 4",
        "1: waiting = 0",
        "1: worker 4 activating",
        "1: ready https://example.com/",
    });
    try testing.expectEqual(@as(usize, 2), recorder.lifecycle.items.len);
    try testing.expectEqual(reg.LifecycleEvent.activate, recorder.lifecycle.items[1].event);
    try registry.lifecycleEventDone(recorder.lifecycle.items[1].op, false);
    try recorder.expectLog(&.{"1: worker 4 activated"});

    const registration = registry.matchRegistration("https://example.com", "https://example.com/any/page").?;
    try testing.expectEqual(worker_id, registration.active.?.id);
    try testing.expectEqual(reg.WorkerState.activated, registration.active.?.state);
    // The job finished at Install step 20: the queue is empty, nothing more
    // runs.
    try testing.expectEqual(@as(usize, 0), recorder.run_jobs.items.len);
}

test "registering the same script again resolves with the registration, and nothing installs" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 2);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");

    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/", 1);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan, "x", true);
    try registry.workerEvaluated(recorder.started.items[0], true);
    try registry.lifecycleEventDone(recorder.lifecycle.items[0].op, false);
    try registry.lifecycleEventDone(recorder.lifecycle.items[1].op, false);
    for (recorder.log.items) |line| testing.allocator.free(line);
    recorder.log.clearRetainingCapacity();

    // Register step 5.2: same script url, type and update via cache mode.
    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/", 2);
    try testing.expect((try recorder.runQueuedJobs(&registry)) == null);
    try recorder.expectLog(&.{"1: resolve registration https://example.com/"});
    try testing.expectEqual(@as(usize, 1), recorder.started.items.len);
}

test "an update whose script is unchanged resolves without a new worker" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 3);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/", 1);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan, "x", true);
    try registry.workerEvaluated(recorder.started.items[0], true);
    try registry.lifecycleEventDone(recorder.lifecycle.items[0].op, false);
    try registry.lifecycleEventDone(recorder.lifecycle.items[1].op, false);
    for (recorder.log.items) |line| testing.allocator.free(line);
    recorder.log.clearRetainingCapacity();

    const job = try registry.createJob(.{
        .job_type = .update,
        .storage_key = "https://example.com",
        .scope_url = "https://example.com/",
        .script_url = "https://example.com/sw.js",
        .client = .{ .environment = page.id, .promise = 3 },
        .referrer = page.creation_url,
    });
    try registry.scheduleJob(job);
    var update_plan = (try recorder.runQueuedJobs(&registry)).?;
    // The newest worker's script resource, for the byte-for-byte check.
    try testing.expectEqualStrings("x", update_plan.newest.?.resources[0].body);
    try answerFetch(&registry, &update_plan, "x", false);
    try recorder.expectLog(&.{"1: resolve registration https://example.com/"});
    try testing.expectEqual(@as(usize, 1), recorder.started.items.len);
}

test "a script that cannot be fetched rejects with a TypeError and leaves no registration" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 4);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    try registerJob(&registry, page, "https://example.com/missing.js", "https://example.com/", 1);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    defer plan.deinit(testing.allocator);
    var outcome: reg.FetchOutcome = .{ .failure = .network };
    try registry.updateFetched(plan.job, &outcome);
    try recorder.expectLog(&.{"1: reject type_error"});
    try testing.expect(registry.getRegistration("https://example.com", "https://example.com/") == null);

    // A refused MIME type or scope: the SecurityError wins.
    try registerJob(&registry, page, "https://example.com/bad-mime.js", "https://example.com/", 2);
    var plan2 = (try recorder.runQueuedJobs(&registry)).?;
    defer plan2.deinit(testing.allocator);
    var refused: reg.FetchOutcome = .{ .failure = .security };
    try registry.updateFetched(plan2.job, &refused);
    try recorder.expectLog(&.{"1: reject security_error"});
}

test "Register's security checks: an untrustworthy origin, a cross-origin script or scope" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 5);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");

    try registerJob(&registry, page, "http://example.com/sw.js", "http://example.com/", 1);
    try testing.expect((try recorder.runQueuedJobs(&registry)) == null);
    try registerJob(&registry, page, "https://other.com/sw.js", "https://example.com/", 2);
    try testing.expect((try recorder.runQueuedJobs(&registry)) == null);
    try registerJob(&registry, page, "https://example.com/sw.js", "https://other.com/", 3);
    try testing.expect((try recorder.runQueuedJobs(&registry)) == null);
    try recorder.expectLog(&.{ "1: reject security_error", "1: reject security_error", "1: reject security_error" });
}

test "Schedule Job: an equivalent job joins the last one; a different one waits its turn" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 6);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    const other = try addWindow(&registry, "https://example.com/other.html");

    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/", 1);
    try registerJob(&registry, other, "https://example.com/sw.js", "https://example.com/", 2);
    try registerJob(&registry, page, "https://example.com/sw2.js", "https://example.com/", 3);
    // Only the first job's Run Job was queued.
    try testing.expectEqual(@as(usize, 1), recorder.run_jobs.items.len);
    const queue = registry.job_queues.get("https://example.com/").?;
    try testing.expectEqual(@as(usize, 2), queue.items.len);
    try testing.expectEqual(@as(usize, 1), queue.items[0].equivalent.items.len);

    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan, "x", true);
    try registry.workerEvaluated(recorder.started.items[0], true);
    // Both clients' promises resolve with the registration.
    try recorder.expectLog(&.{
        "1: installing = 7",
        "2: installing = 7",
        "1: worker 7 installing",
        "2: worker 7 installing",
        "1: resolve registration https://example.com/",
        "2: resolve registration https://example.com/",
        "1: updatefound",
        "2: updatefound",
    });
    try registry.lifecycleEventDone(recorder.lifecycle.items[0].op, false);
    // Install step 20 finished the job: the next one is queued.
    try testing.expectEqual(@as(usize, 1), recorder.run_jobs.items.len);
    for (recorder.log.items) |line| testing.allocator.free(line);
    recorder.log.clearRetainingCapacity();
    var plan2 = (try recorder.runQueuedJobs(&registry)).?;
    defer plan2.deinit(testing.allocator);
    try testing.expectEqualStrings("https://example.com/sw2.js", plan2.script_url);
}

test "an install event that fails leaves the worker redundant and removes a new registration" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 7);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/s/", 1);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan, "x", true);
    const worker_id = recorder.started.items[0];
    try registry.workerEvaluated(worker_id, true);
    for (recorder.log.items) |line| testing.allocator.free(line);
    recorder.log.clearRetainingCapacity();

    try registry.lifecycleEventDone(recorder.lifecycle.items[0].op, true);
    try recorder.expectLog(&.{ "1: worker 4 redundant", "1: installing = 0" });
    try testing.expect(registry.getRegistration("https://example.com", "https://example.com/s/") == null);
    try testing.expectEqual(worker_id, recorder.terminated.items[0]);
    // Its thread's end frees what is left of it.
    try registry.workerEnded(worker_id);
    try testing.expect(registry.findWorker(worker_id) == null);
}

test "a waiting worker activates only once no client uses the registration, or with skipWaiting" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 8);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/", 1);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan, "v1", true);
    const first = recorder.started.items[0];
    try registry.workerEvaluated(first, true);
    try registry.lifecycleEventDone(recorder.lifecycle.items[0].op, false);
    try registry.lifecycleEventDone(recorder.lifecycle.items[1].op, false);

    // The page is controlled by the first worker.
    try registry.claim(first);
    const registration = registry.getRegistration("https://example.com", "https://example.com/").?;
    try testing.expectEqual(first, page.active_worker.?.id);

    // A new script installs, and waits.
    try registerJob(&registry, page, "https://example.com/sw2.js", "https://example.com/", 2);
    var plan2 = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan2, "v2", true);
    const second = recorder.started.items[1];
    try registry.workerEvaluated(second, true);
    try registry.lifecycleEventDone(recorder.lifecycle.items[2].op, false);
    try testing.expectEqual(second, registration.waiting.?.id);
    try testing.expectEqual(first, registration.active.?.id);

    // skipWaiting(): it activates, and the page hears controllerchange.
    for (recorder.log.items) |line| testing.allocator.free(line);
    recorder.log.clearRetainingCapacity();
    try registry.skipWaiting(second);
    try testing.expectEqual(second, registration.active.?.id);
    try testing.expectEqual(second, page.active_worker.?.id);
    var saw_change = false;
    for (recorder.log.items) |line| {
        if (std.mem.eql(u8, line, "1: controllerchange")) saw_change = true;
    }
    try testing.expect(saw_change);
    try testing.expectEqual(first, recorder.terminated.items[recorder.terminated.items.len - 1]);
}

test "unregister resolves true, and with no client the registration is cleared" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 9);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/", 1);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan, "x", true);
    const worker_id = recorder.started.items[0];
    try registry.workerEvaluated(worker_id, true);
    try registry.lifecycleEventDone(recorder.lifecycle.items[0].op, false);
    try registry.lifecycleEventDone(recorder.lifecycle.items[1].op, false);
    for (recorder.log.items) |line| testing.allocator.free(line);
    recorder.log.clearRetainingCapacity();

    const job = try registry.createJob(.{
        .job_type = .unregister,
        .storage_key = "https://example.com",
        .scope_url = "https://example.com/",
        .client = .{ .environment = page.id, .promise = 2 },
        .referrer = page.creation_url,
    });
    try registry.scheduleJob(job);
    try testing.expect((try recorder.runQueuedJobs(&registry)) == null);
    try recorder.expectLog(&.{ "1: resolve true", "1: worker 4 redundant", "1: active = 0" });
    try testing.expect(registry.getRegistration("https://example.com", "https://example.com/") == null);
    try registry.workerEnded(worker_id);
    try testing.expect(registry.findWorker(worker_id) == null);

    // A second unregister finds nothing: false.
    const again = try registry.createJob(.{
        .job_type = .unregister,
        .storage_key = "https://example.com",
        .scope_url = "https://example.com/",
        .client = .{ .environment = page.id, .promise = 3 },
        .referrer = page.creation_url,
    });
    try registry.scheduleJob(again);
    try testing.expect((try recorder.runQueuedJobs(&registry)) == null);
    try recorder.expectLog(&.{"1: resolve false"});
}

test "an environment that ends while it is controlled lets a waiting worker activate" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 10);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    const frame = try addWindow(&registry, "https://example.com/frame.html");
    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/", 1);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan, "v1", true);
    const first = recorder.started.items[0];
    try registry.workerEvaluated(first, true);
    try registry.lifecycleEventDone(recorder.lifecycle.items[0].op, false);
    try registry.lifecycleEventDone(recorder.lifecycle.items[1].op, false);
    try registry.claim(first);

    try registerJob(&registry, page, "https://example.com/sw2.js", "https://example.com/", 2);
    var plan2 = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan2, "v2", true);
    const second = recorder.started.items[1];
    try registry.workerEvaluated(second, true);
    try registry.lifecycleEventDone(recorder.lifecycle.items[2].op, false);
    const registration = registry.getRegistration("https://example.com", "https://example.com/").?;
    try testing.expectEqual(second, registration.waiting.?.id);

    // One client leaves: the other still uses it.
    registry.removeEnvironment(frame);
    try testing.expectEqual(second, registration.waiting.?.id);
    // The last one leaves: Handle Service Worker Client Unload activates.
    registry.removeEnvironment(page);
    try testing.expectEqual(second, registration.active.?.id);
}

/// Register, install and activate `script` at `scope_url` for `page`: the
/// worker's id.
fn installAndActivate(recorder: *Recorder, registry: *Registry, page: *reg.Environment, script: []const u8, scope_url: []const u8, body: []const u8) !u64 {
    try registerJob(registry, page, script, scope_url, 1);
    var plan = (try recorder.runQueuedJobs(registry)).?;
    try answerFetch(registry, &plan, body, true);
    const worker_id = recorder.started.items[recorder.started.items.len - 1];
    try registry.workerEvaluated(worker_id, true);
    try registry.lifecycleEventDone(recorder.lifecycle.items[recorder.lifecycle.items.len - 1].op, false);
    try registry.lifecycleEventDone(recorder.lifecycle.items[recorder.lifecycle.items.len - 1].op, false);
    for (recorder.log.items) |line| testing.allocator.free(line);
    recorder.log.clearRetainingCapacity();
    return worker_id;
}

test "Soft Update schedules an update job with no client for the newest worker" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 11);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    _ = try installAndActivate(&recorder, &registry, page, "https://example.com/sw.js", "https://example.com/", "v1");
    const registration = registry.getRegistration("https://example.com", "https://example.com/").?;
    registration.update_via_cache = .none;

    try registry.softUpdate(registration, true);
    // Schedule Job step 5: Run Job queued for its scope.
    try testing.expectEqual(@as(usize, 1), recorder.run_jobs.items.len);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    defer plan.deinit(testing.allocator);
    try testing.expectEqualStrings("https://example.com/sw.js", plan.script_url);
    // Its force bypass cache flag, and the fetch hook's step 2.
    try testing.expect(plan.bypass_http_cache);
    try testing.expect(plan.bypass_http_cache_for_imports);
    // No client: nothing to hear its promise.
    try testing.expect(plan.fetch_client == null);
}

test "importScripts in a service worker: fetched while installing, then answered from the map" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 12);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/", 1);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan, "importScripts('a.js')", true);
    const worker_id = recorder.started.items[0];

    // Parsed (its script runs): steps 6-9 fetch, with no-cache only for the
    // reasons of step 8.
    switch (try registry.importStep(worker_id, "https://example.com/a.js")) {
        .fetch => |f| try testing.expect(!f.bypass_http_cache),
        else => return error.TestUnexpectedResult,
    }
    try registry.addImportedScript(worker_id, .{
        .url = try testing.allocator.dupe(u8, "https://example.com/a.js"),
        .body = try testing.allocator.dupe(u8, "var a;"),
        .content_type = try testing.allocator.dupe(u8, "text/javascript"),
    }, true);
    const worker = registry.findWorker(worker_id).?;
    try testing.expect(worker.classic_scripts_imported);
    try testing.expectEqual(@as(usize, 2), worker.used_scripts.items.len);

    // Step 5: the same URL again is the stored response.
    switch (try registry.importStep(worker_id, "https://example.com/a.js")) {
        .stored => |stored| {
            var copy = stored;
            defer copy.deinit(testing.allocator);
            try testing.expectEqualStrings("var a;", copy.body);
        },
        else => return error.TestUnexpectedResult,
    }

    // Installed: a URL the map lacks is a network error (step 4).
    try registry.workerEvaluated(worker_id, true);
    try registry.lifecycleEventDone(recorder.lifecycle.items[0].op, false);
    try testing.expect(worker.state != .parsed and worker.state != .installing);
    try testing.expect((try registry.importStep(worker_id, "https://example.com/b.js")) == .network_error);
    switch (try registry.importStep(worker_id, "https://example.com/a.js")) {
        .stored => |stored| {
            var copy = stored;
            copy.deinit(testing.allocator);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "a running worker with nothing left to do is reported idle" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 13);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    try registerJob(&registry, page, "https://example.com/sw.js", "https://example.com/", 1);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan, "x", true);
    const worker_id = recorder.started.items[0];
    try registry.workerEvaluated(worker_id, true);
    // Its install event is pending: not idle.
    try testing.expectEqual(@as(usize, 0), recorder.idled.items.len);
    try registry.lifecycleEventDone(recorder.lifecycle.items[0].op, false);
    // Then its activate event.
    try testing.expectEqual(@as(usize, 0), recorder.idled.items.len);
    try registry.lifecycleEventDone(recorder.lifecycle.items[1].op, false);
    try testing.expectEqual(@as(usize, 1), recorder.idled.items.len);
    try testing.expectEqual(worker_id, recorder.idled.items[0]);
    // An extended event keeps it busy until it settles.
    try registry.extendedEventsChanged(worker_id, 1);
    try testing.expect(!registry.isIdle(registry.findWorker(worker_id).?));
    try registry.extendedEventsChanged(worker_id, 0);
    try testing.expectEqual(@as(usize, 2), recorder.idled.items.len);
    // Terminated for it, it is stopped - not idle, and nothing waits.
    try registry.workerEnded(worker_id);
    try testing.expect(!registry.isIdle(registry.findWorker(worker_id).?));
}

// ============================================================================
// Functional events (postMessage's message event) and client queries
// ============================================================================

test "a message to a running worker is handed over at once, and is in flight until it is done" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 21);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    const worker_id = try installAndActivate(&recorder, &registry, page, "https://example.com/sw.js", "https://example.com/", "v1");
    const worker = registry.findWorker(worker_id).?;
    const idled_before = recorder.idled.items.len;

    // postMessage step 6.1: Run Service Worker - it is running, so the
    // owner's waiter is answered at once.
    try registry.runServiceWorker(worker, false, .{ .other = 77 });
    try testing.expectEqual(@as(usize, 1), recorder.answered.items.len);
    try testing.expectEqual(@as(u64, 77), recorder.answered.items[0].waiter);
    try testing.expect(recorder.answered.items[0].ok);
    try testing.expectEqual(@as(u32, 1), worker.events_in_flight);
    // A worker with an event in flight has pending events: not idle.
    try testing.expect(!reg.serviceWorkerHasNoPendingEvents(worker));
    try testing.expect(!registry.isIdle(worker));

    try registry.functionalEventDone(worker_id, worker.run_generation);
    try testing.expectEqual(@as(u32, 0), worker.events_in_flight);
    try testing.expectEqual(idled_before + 1, recorder.idled.items.len);
}

test "a message to a stopped worker starts it, and is answered once its script has run" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 22);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    const worker_id = try installAndActivate(&recorder, &registry, page, "https://example.com/sw.js", "https://example.com/", "v1");
    const worker = registry.findWorker(worker_id).?;
    // Terminated (idle): stopped.
    try registry.workerEnded(worker_id);
    const started_before = recorder.started.items.len;

    try registry.runServiceWorker(worker, false, .{ .other = 5 });
    try testing.expectEqual(started_before + 1, recorder.started.items.len);
    try testing.expectEqual(@as(usize, 0), recorder.answered.items.len);
    try registry.workerEvaluated(worker_id, true);
    try testing.expectEqual(@as(usize, 1), recorder.answered.items.len);
    try testing.expect(recorder.answered.items[0].ok);
    try testing.expectEqual(@as(u32, 1), worker.events_in_flight);

    // A start that fails answers with failure, and nothing is in flight.
    try registry.functionalEventDone(worker_id, worker.run_generation);
    try registry.workerEnded(worker_id);
    try registry.runServiceWorker(worker, false, .{ .other = 6 });
    try registry.workerEvaluated(worker_id, false);
    try testing.expectEqual(@as(usize, 2), recorder.answered.items.len);
    try testing.expect(!recorder.answered.items[1].ok);
    try testing.expectEqual(@as(u32, 0), worker.events_in_flight);
}

test "an event in flight from an earlier run of the worker does not end one of this run" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 23);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    const worker_id = try installAndActivate(&recorder, &registry, page, "https://example.com/sw.js", "https://example.com/", "v1");
    const worker = registry.findWorker(worker_id).?;
    try registry.runServiceWorker(worker, false, .{ .other = 1 });
    const first_run = worker.run_generation;
    // The worker ends with the event in flight, and starts again for another.
    try registry.workerEnded(worker_id);
    try testing.expectEqual(@as(u32, 0), worker.events_in_flight);
    try registry.runServiceWorker(worker, false, .{ .other = 2 });
    try registry.workerEvaluated(worker_id, true);
    try testing.expect(worker.run_generation != first_run);
    try testing.expectEqual(@as(u32, 1), worker.events_in_flight);
    // The first run's late end changes nothing.
    try registry.functionalEventDone(worker_id, first_run);
    try testing.expectEqual(@as(u32, 1), worker.events_in_flight);
    try registry.functionalEventDone(worker_id, worker.run_generation);
    try testing.expectEqual(@as(u32, 0), worker.events_in_flight);
}

test "an active worker with a message in flight is not replaced until the message is done" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 24);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    const first = try installAndActivate(&recorder, &registry, page, "https://example.com/sw.js", "https://example.com/", "v1");
    try registry.runServiceWorker(registry.findWorker(first).?, false, .{ .other = 9 });

    // A second worker installs and asks to skip waiting.
    try registerJob(&registry, page, "https://example.com/sw2.js", "https://example.com/", 2);
    var plan = (try recorder.runQueuedJobs(&registry)).?;
    try answerFetch(&registry, &plan, "v2", true);
    const second = recorder.started.items[recorder.started.items.len - 1];
    try registry.workerEvaluated(second, true);
    try registry.lifecycleEventDone(recorder.lifecycle.items[recorder.lifecycle.items.len - 1].op, false);
    try registry.skipWaiting(second);
    const registration = registry.getRegistration("https://example.com", "https://example.com/").?;
    // Try Activate step 3: the active worker has a pending event.
    try testing.expectEqual(second, registration.waiting.?.id);
    try testing.expectEqual(first, registration.active.?.id);

    // Its end lets the waiting worker activate.
    try registry.functionalEventDone(first, registry.findWorker(first).?.run_generation);
    try testing.expectEqual(second, registration.active.?.id);
}

fn addClient(registry: *Registry, kind: reg.EnvironmentKind, origin: []const u8, url: []const u8, secure: bool) !*reg.Environment {
    return registry.addEnvironment(.{
        .kind = kind,
        .origin = origin,
        .creation_url = url,
        .secure_context = secure,
        .endpoint = &endpoint_dummy,
    });
}

test "matchAll's target clients: the worker's storage key, in creation order, controlled unless includeUncontrolled" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 25);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    const frame = try addWindow(&registry, "https://example.com/frame.html");
    _ = try addClient(&registry, .window, "https://other.com", "https://other.com/page.html", true);
    _ = try addClient(&registry, .window, "https://example.com", "https://example.com/insecure.html", false);
    const worker_id = try installAndActivate(&recorder, &registry, page, "https://example.com/sw.js", "https://example.com/", "v1");
    const worker = registry.findWorker(worker_id).?;
    // The service worker's own global is an environment, and no client.
    _ = try addClient(&registry, .service_worker, "https://example.com", "https://example.com/sw.js", true);
    try registry.claim(worker_id);
    // The first client goes, a dedicated worker comes: creation order is
    // kept whatever the list's order.
    registry.removeEnvironment(page);
    const dedicated = try addClient(&registry, .dedicated_worker, "https://example.com", "https://example.com/worker.js", true);

    const controlled = try registry.matchAllClients(testing.allocator, worker, false);
    defer testing.allocator.free(controlled);
    try testing.expectEqual(@as(usize, 1), controlled.len);
    try testing.expectEqual(frame, controlled[0]);

    const all = try registry.matchAllClients(testing.allocator, worker, true);
    defer testing.allocator.free(all);
    try testing.expectEqual(@as(usize, 2), all.len);
    try testing.expectEqual(frame, all[0]);
    try testing.expectEqual(dedicated, all[1]);
}

test "get(id) finds a client of the worker's storage key by its id, and nothing else" {
    var recorder: Recorder = .{ .allocator = testing.allocator };
    defer recorder.deinit();
    var registry = Registry.init(testing.allocator, recorder.effects(), 26);
    defer registry.deinit();
    const page = try addWindow(&registry, "https://example.com/page.html");
    const other = try addClient(&registry, .window, "https://other.com", "https://other.com/page.html", true);
    const worker_id = try installAndActivate(&recorder, &registry, page, "https://example.com/sw.js", "https://example.com/", "v1");
    const worker = registry.findWorker(worker_id).?;
    const own_global = try addClient(&registry, .service_worker, "https://example.com", "https://example.com/sw.js", true);

    try testing.expectEqual(page, registry.getClient(worker, &page.client_id).?);
    try testing.expect(registry.getClient(worker, &other.client_id) == null);
    try testing.expect(registry.getClient(worker, &own_global.client_id) == null);
    try testing.expect(registry.getClient(worker, "not-an-id") == null);
}
