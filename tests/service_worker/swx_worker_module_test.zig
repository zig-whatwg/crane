//! A worker's static module request retains its wire destination but uses
//! the existing client's controller, including outside that controller's scope.
const std = @import("std");
const testing = std.testing;
const sw = @import("service_worker");
const fetch = @import("fetch");
const registry = sw.registry;

const host: sw.manager.Host = .{
    .fetch = scriptFetch,
    .start = start,
    .dispatch = lifecycle,
    .post_message = message,
    .dispatch_fetch = dispatchFetch,
};

fn scriptFetch(manager: *sw.Manager, plan: *const registry.FetchPlan) registry.FetchOutcome {
    var result: registry.FetchOutcome = .{ .has_updated_resources = true, .checked_network = true };
    const a = manager.allocator;
    const url = a.dupe(u8, plan.script_url) catch return .{ .failure = .network };
    const body = a.dupe(u8, "// service worker") catch {
        a.free(url);
        return .{ .failure = .network };
    };
    const mime = a.dupe(u8, "text/javascript") catch {
        a.free(url);
        a.free(body);
        return .{ .failure = .network };
    };
    result.resources.append(a, .{ .url = url, .body = body, .content_type = mime }) catch {
        a.free(url);
        a.free(body);
        a.free(mime);
        return .{ .failure = .network };
    };
    return result;
}

fn start(manager: *sw.Manager, value: *const sw.manager.WorkerStart) anyerror!sw.manager.Started {
    manager.report(.{ .evaluated = .{ .worker = value.worker_id, .ok = true, .handles_fetch = true } });
    return .{ .link = null };
}
fn lifecycle(manager: *sw.Manager, _: sw.manager.Started, _: registry.LifecycleEvent, op: u64) void {
    manager.report(.{ .lifecycle_done = .{ .op = op, .failed = false } });
}
fn message(manager: *sw.Manager, _: sw.manager.Started, value: *sw.manager.WorkerMessage, worker: u64, generation: u64) void {
    value.destroy();
    manager.report(.{ .message_done = .{ .worker = worker, .generation = generation } });
}
fn dispatchFetch(manager: *sw.Manager, _: sw.manager.Started, value: *sw.manager.FetchDispatch, worker: u64, generation: u64) void {
    // A real handled request, distinguishable from Handle Fetch's early
    // network fallback without allocating a response or retaining the task.
    value.call.answer(.fallback);
    value.destroy();
    manager.report(.{ .fetch_done = .{ .worker = worker, .generation = generation } });
}

fn checkWorkerModules(kind: registry.EnvironmentKind, destination: fetch.internal.Destination) !void {
    const a = testing.allocator;
    var manager = sw.Manager.init(a);
    defer manager.deinit();
    manager.host = &host;
    const client = try manager.addEnvironment(.{
        .kind = kind,
        .origin = "https://example.com",
        .creation_url = "https://example.com/root/worker.js",
        .endpoint = null,
    });
    try manager.schedule(.{
        .job_type = .register,
        .storage_key = "https://example.com",
        .scope_url = "https://example.com/root/",
        .script_url = "https://example.com/sw.js",
        .client = .{ .environment = client, .promise = 1 },
        .referrer = "https://example.com/root/worker.js",
    });
    var controller: u64 = 0;
    for (0..1000) |_| {
        if (try manager.match(a, "https://example.com", "https://example.com/root/worker.js")) |found| {
            var info = found;
            defer info.deinit(a);
            if (info.active) |active| if (active.state == .activated) {
                controller = active.id;
                break;
            };
        }
        std.Io.Threaded.global_single_threaded.io().sleep(.fromNanoseconds(10 * std.time.ns_per_ms), .awake) catch {};
    }
    try testing.expect(controller != 0);
    {
        std.Io.Threaded.mutexLock(&manager.mutex);
        defer std.Io.Threaded.mutexUnlock(&manager.mutex);
        const environment = manager.registry.findEnvironment(client).?;
        manager.registry.setActiveWorker(environment, manager.registry.findWorker(controller).?);
    }
    const request = try fetch.internal.InternalRequest.init(a, "https://example.com/outside/dependency.js");
    defer request.deinit();
    request.destination = destination;
    request.mode = .cors;
    const result = try manager.handleFetch(request, client);
    try testing.expect(result == .call);
    defer result.call.release();
    try testing.expect((result.call.wait(5000) orelse return error.TimedOut) == .fallback);
    // Root worker loads have mode same-origin and still need a reservation.
    request.mode = .same_origin;
    try testing.expect(try manager.handleFetch(request, client) == .network);
    request.mode = .cors;
    try testing.expect(try manager.handleFetch(request, 0) == .network);
    const page = try manager.addEnvironment(.{
        .kind = .window,
        .origin = "https://example.com",
        .creation_url = "https://example.com/root/page.html",
        .endpoint = null,
    });
    {
        std.Io.Threaded.mutexLock(&manager.mutex);
        defer std.Io.Threaded.mutexUnlock(&manager.mutex);
        manager.registry.setActiveWorker(manager.registry.findEnvironment(page).?, manager.registry.findWorker(controller).?);
    }
    // A malformed new-worker request from a page is not a static import.
    try testing.expect(try manager.handleFetch(request, page) == .network);
}

test "dedicated worker static imports use their controller outside its scope" {
    try checkWorkerModules(.dedicated_worker, .worker);
}
test "shared worker static imports use their controller outside its scope" {
    try checkWorkerModules(.shared_worker, .sharedworker);
}
