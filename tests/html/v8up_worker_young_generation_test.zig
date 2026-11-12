//! A host's young-generation limit reaches EVERY agent of its Browser: the
//! window agent, and the agents of the dedicated and shared workers its
//! pages start (the service worker's: tests/service_worker/
//! v8up_young_generation_test.zig). Browser.Config.young_generation_limit ->
//! engine.AgentOptions.young_generation_limit for the window agent, and for
//! each worker agent through the Browser's WorkerRegistry (worker_host.zig
//! reads it when the worker's thread makes its agent). A Browser that sets
//! nothing gives every one of them the protocol's one default,
//! engine.default_young_generation_limit.
//!
//! What an agent got is engine.youngGenerationLimitOf - callable from any
//! thread while the agent lives, so the test reads a worker's under the
//! worker link's agent lock, which the worker's thread takes before it
//! destroys its agent.
const std = @import("std");
const Browser = @import("browser").Browser;
const engine = @import("engine");
const html = @import("html");

const mb = 1024 * 1024;

/// A dedicated and a shared worker from data: URLs, each saying "up" once it
/// runs and then staying alive.
const launch =
    \\globalThis.up = 0;
    \\globalThis.dedicated = new Worker('data:text/javascript,postMessage("up")');
    \\dedicated.onmessage = () => { up++; };
    \\globalThis.shared = new SharedWorker('data:text/javascript,onconnect = e => e.ports[0].postMessage("up")');
    \\shared.port.onmessage = () => { up++; };
    \\'started'
;

/// What each live worker agent of `browser` got, read through its
/// WorkerRegistry's links.
fn workerLimits(browser: *Browser, limits: *[8]?usize) usize {
    const registry = browser.scope.existing(html.WorkerRegistry) orelse return 0;
    std.Io.Threaded.mutexLockUncancelable(&registry.mutex);
    defer std.Io.Threaded.mutexUnlock(&registry.mutex);
    var count: usize = 0;
    for (registry.links.items) |link| {
        std.Io.Threaded.mutexLockUncancelable(&link.agent_lock);
        defer std.Io.Threaded.mutexUnlock(&link.agent_lock);
        const agent = link.agent orelse continue;
        if (count == limits.len) break;
        limits[count] = engine.youngGenerationLimitOf(agent);
        count += 1;
    }
    return count;
}

const Configured = union(enum) { nothing, limit: usize };

fn check(configured: Configured) !void {
    const allocator = std.testing.allocator;
    const browser = switch (configured) {
        .nothing => try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" }),
        .limit => |bytes| try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "", .young_generation_limit = bytes }),
    };
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = "https://young-generation.test/" });
    const started = try page.evaluateScriptToString(launch, allocator);
    defer allocator.free(started);
    try std.testing.expectEqualStrings("started", started);
    var up = false;
    for (0..1000) |_| {
        _ = try browser.runEventLoopBlocking(10);
        const answer = try page.evaluateScriptToString("String(up)", allocator);
        defer allocator.free(answer);
        if (std.mem.eql(u8, answer, "2")) {
            up = true;
            break;
        }
    }
    try std.testing.expect(up);

    // What the Browser's own window agent got is what its configuration
    // says: nothing set is the protocol's default.
    const window_limit = engine.youngGenerationLimitOf(browser.agent orelse return error.NoAgent);
    const honoured = comptime engine.capabilities.young_generation_limit != .unsupported;
    switch (configured) {
        .limit => |bytes| try std.testing.expectEqual(@as(?usize, if (honoured) bytes else null), window_limit),
        .nothing => if (engine.default_young_generation_limit) |default| {
            // The engine may round the default down, never up or to nothing.
            if (honoured) try std.testing.expect(window_limit != null and window_limit.? <= default and window_limit.? > 0);
        } else try std.testing.expectEqual(@as(?usize, null), window_limit),
    }
    // And each of its two workers' agents got the same.
    var limits: [8]?usize = undefined;
    const count = workerLimits(browser, &limits);
    if (count != 2) std.debug.print("{d} worker agent(s) live, expected the dedicated and the shared worker's\n", .{count});
    try std.testing.expectEqual(@as(usize, 2), count);
    for (limits[0..count]) |limit| try std.testing.expectEqual(window_limit, limit);
}

fn onThread(comptime configured: Configured) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            check(configured) catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "a Browser configured with a 24 MB young generation: its window agent, its dedicated worker's and its shared worker's each get 24 MB" {
    try onThread(.{ .limit = 24 * mb });
}

test "a Browser configured with a 6 MB young generation: its window agent and both workers' get 6 MB" {
    try onThread(.{ .limit = 6 * mb });
}

test "a Browser with no young-generation limit set: its window agent and both workers' get the protocol's default" {
    try onThread(.nothing);
}
