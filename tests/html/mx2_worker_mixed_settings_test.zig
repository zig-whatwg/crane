//! Mixed Content 4.3: worker requests carry their own origin's restriction.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const settings = @import("dom").global_settings;
const mixed_content = @import("fetch").mixed_content;

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn snapshotOrigins() !void {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();

    inline for (.{ interfaces.DedicatedWorkerGlobalScope, interfaces.SharedWorkerGlobalScope, interfaces.ServiceWorkerGlobalScope }) |Scope| {
        inline for (.{
            .{ "https://example.test/worker.js", true },
            .{ "http://example.test/worker.js", false },
            .{ "http://localhost/worker.js", true },
        }) |case| {
            const scope = try Scope.initWith(allocator, &context, .{ .url = case[0] });
            defer Scope.deinit(scope);
            var client = try settings.requestClient(scope);
            defer client.deinit();
            try std.testing.expectEqual(case[1], client.request.prohibits_mixed_security_contexts);
        }
    }
}

fn comparePredicate() !void {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();

    inline for (.{
        "https://example.test/worker.js",
        "http://example.test/worker.js",
        "http://localhost/worker.js",
        "http://127.0.0.1/worker.js",
        "http://[::1]/worker.js",
    }) |url| {
        const scope = try interfaces.DedicatedWorkerGlobalScope.initWith(allocator, &context, .{ .url = url });
        defer interfaces.DedicatedWorkerGlobalScope.deinit(scope);
        var client = try settings.requestClient(scope);
        defer client.deinit();
        try std.testing.expectEqual(
            try mixed_content.isOriginAuthenticated(allocator, client.request.origin.?),
            client.request.prohibits_mixed_security_contexts,
        );
    }

    // A scope without URL setup reports an opaque origin. This pins the
    // absent-state default without giving a data/blob worker an owner rule.
    const scope = try interfaces.WorkerGlobalScope.init(allocator, &context);
    defer interfaces.WorkerGlobalScope.deinit(scope);
    var client = try settings.requestClient(scope);
    defer client.deinit();
    try std.testing.expectEqualStrings("null", client.request.origin.?);
    try std.testing.expectEqual(
        try mixed_content.isOriginAuthenticated(allocator, "null"),
        client.request.prohibits_mixed_security_contexts,
    );
}

test "worker mixed content: dedicated, shared and service client snapshots use the scope origin" {
    try onThread(snapshotOrigins);
}

test "worker mixed content: callback agrees with the authenticated origin predicate" {
    try onThread(comparePredicate);
}

fn noAllocationForCallback() !void {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const allocator = failing.allocator();
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const scope = try interfaces.DedicatedWorkerGlobalScope.initWith(allocator, &context, .{ .url = "https://example.test/worker.js" });
    defer interfaces.DedicatedWorkerGlobalScope.deinit(scope);
    const callback = (settings.of(scope) orelse return error.NoSettings).prohibits_mixed_security_contexts orelse return error.NoCallback;

    // Once the scope exists, reading its immutable origin must work even
    // when another allocation cannot be made.
    failing.fail_index = failing.alloc_index;
    defer failing.fail_index = std.math.maxInt(usize);
    try std.testing.expect(try callback(scope));
    try std.testing.expect(!failing.has_induced_failure);
}

test "worker mixed content: the origin restriction callback allocates nothing" {
    try onThread(noAllocationForCallback);
}
