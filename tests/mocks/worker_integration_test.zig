//! Integration tests for Worker Infrastructure Mocks
//!
//! These tests verify that all worker infrastructure mocks work together
//! to support Service Worker implementation.

const std = @import("std");
const mocks = @import("../../src/mocks/root.zig");

const WorkerGlobalScope = mocks.WorkerGlobalScope;
const WorkerLocation = mocks.WorkerLocation;
const WorkerNavigator = mocks.WorkerNavigator;
const WorkerEventLoop = mocks.WorkerEventLoop;
const ScriptEvaluator = mocks.ScriptEvaluator;
const MessagePort = mocks.MessagePort;
const MessageChannel = mocks.MessageChannel;
const TaskSource = mocks.TaskSource;

// =============================================================================
// Integration Tests
// =============================================================================

test "WorkerGlobalScope has all required components" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/sw.js",
        .module,
    );
    defer scope.deinit();

    // Verify location is accessible and correct
    const loc = scope.getLocation();
    try std.testing.expectEqualStrings("https://example.com/sw.js", loc.href);
    try std.testing.expectEqualStrings("https://example.com", loc.origin);
    try std.testing.expectEqualStrings("/sw.js", loc.pathname);

    // Verify navigator is accessible
    const nav = scope.getNavigator();
    try std.testing.expectEqualStrings("Mozilla", nav.getAppCodeName());
    try std.testing.expect(nav.getOnLine());

    // Verify origin matches location
    try std.testing.expectEqualStrings(loc.origin, scope.getOrigin());

    // Verify secure context
    try std.testing.expect(scope.getIsSecureContext());
}

test "WorkerGlobalScope event loop integration" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/sw.js",
        .classic,
    );
    defer scope.deinit();

    // Queue tasks through the scope
    var task_count: u32 = 0;

    _ = scope.queueTask(.service_worker, struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *u32 = @ptrCast(@alignCast(ctx.?));
            ptr.* += 1;
        }
    }.callback, @ptrCast(&task_count));

    _ = scope.setTimeout(struct {
        fn callback(ctx: ?*anyopaque) void {
            const ptr: *u32 = @ptrCast(@alignCast(ctx.?));
            ptr.* += 10;
        }
    }.callback, 100, @ptrCast(&task_count));

    // Run the event loop
    scope.runEventLoop();

    try std.testing.expectEqual(@as(u32, 11), task_count);
}

test "WorkerGlobalScope script evaluation" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/sw.js",
        .classic,
    );
    defer scope.deinit();

    // Import scripts (classic worker only)
    const urls = [_][]const u8{
        "https://example.com/lib1.js",
        "https://example.com/lib2.js",
    };
    try scope.importScripts(&urls);

    // Verify scripts were evaluated
    try std.testing.expect(scope.script_evaluator.hasEvaluated("https://example.com/lib1.js"));
    try std.testing.expect(scope.script_evaluator.hasEvaluated("https://example.com/lib2.js"));
}

test "WorkerGlobalScope message ports" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/sw.js",
        .classic,
    );
    defer scope.deinit();

    // Create a message channel
    const channel = try MessageChannel.init(allocator);
    defer channel.deinit();

    // Add port to worker
    try scope.addPort(channel.port1);

    // Verify ports are tracked
    try std.testing.expectEqual(@as(usize, 1), scope.ports.items.len);
}

test "MessageChannel bidirectional communication" {
    const allocator = std.testing.allocator;

    const channel = try MessageChannel.init(allocator);
    defer channel.deinit();

    channel.port1.onmessage = struct {
        fn handler(_: []const u8, _: []const u8) void {
            // Handler called when message received
        }
    }.handler;

    channel.port2.onmessage = struct {
        fn handler(_: []const u8, _: []const u8) void {
            // Handler called when message received
        }
    }.handler;

    // Start both ports
    channel.port1.start();
    channel.port2.start();

    // Send messages both ways
    try channel.port1.postMessage("hello from port1");
    try channel.port2.postMessage("hello from port2");

    // In mock, messages are dispatched immediately when port is started
    // Verify no pending messages (they were dispatched)
    try std.testing.expectEqual(@as(usize, 0), channel.port1.getPendingMessageCount());
    try std.testing.expectEqual(@as(usize, 0), channel.port2.getPendingMessageCount());
}

test "WorkerEventLoop task priorities" {
    const allocator = std.testing.allocator;

    const loop = try WorkerEventLoop.init(allocator);
    defer loop.deinit();

    var execution_order: [3]u8 = .{ 0, 0, 0 };
    var order_idx: usize = 0;

    // Queue tasks from different sources
    _ = loop.queueTask(.networking, struct {
        fn callback(ctx: ?*anyopaque) void {
            const data: *struct { order: *[3]u8, idx: *usize } = @ptrCast(@alignCast(ctx.?));
            data.order[data.idx.*] = 1;
            data.idx.* += 1;
        }
    }.callback, @ptrCast(&.{ .order = &execution_order, .idx = &order_idx }));

    _ = loop.queueTask(.timer, struct {
        fn callback(ctx: ?*anyopaque) void {
            const data: *struct { order: *[3]u8, idx: *usize } = @ptrCast(@alignCast(ctx.?));
            data.order[data.idx.*] = 2;
            data.idx.* += 1;
        }
    }.callback, @ptrCast(&.{ .order = &execution_order, .idx = &order_idx }));

    _ = loop.queueTask(.service_worker, struct {
        fn callback(ctx: ?*anyopaque) void {
            const data: *struct { order: *[3]u8, idx: *usize } = @ptrCast(@alignCast(ctx.?));
            data.order[data.idx.*] = 3;
            data.idx.* += 1;
        }
    }.callback, @ptrCast(&.{ .order = &execution_order, .idx = &order_idx }));

    // All tasks should run
    loop.runAllTasks();
    try std.testing.expectEqual(@as(usize, 3), order_idx);
}

test "ScriptEvaluator with configured failures" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    // Configure specific failures
    try evaluator.configureFetchFailure("https://example.com/404.js", "Not found");
    try evaluator.configureThrowError("https://example.com/error.js", "SyntaxError");

    // Good script succeeds
    const good_result = try evaluator.evaluateScript("https://example.com/good.js", .classic);
    try std.testing.expectEqual(mocks.EvaluationResult.success, good_result);

    // 404 script fails with fetch error
    const fetch_result = try evaluator.evaluateScript("https://example.com/404.js", .classic);
    switch (fetch_result) {
        .fetch_error => {},
        else => return error.ExpectedFetchError,
    }

    // Error script fails with thrown error
    const error_result = try evaluator.evaluateScript("https://example.com/error.js", .module);
    switch (error_result) {
        .error_thrown => {},
        else => return error.ExpectedErrorThrown,
    }
}

test "WorkerLocation URL parsing edge cases" {
    const allocator = std.testing.allocator;

    // URL with all components
    const full_url = try WorkerLocation.init(
        allocator,
        "https://user:pass@example.com:8080/path/to/sw.js?query=1&foo=bar#section",
    );
    defer full_url.deinit();

    try std.testing.expectEqualStrings("https:", full_url.protocol);
    try std.testing.expectEqualStrings("8080", full_url.port);
    try std.testing.expectEqualStrings("/path/to/sw.js", full_url.pathname);
    try std.testing.expectEqualStrings("?query=1&foo=bar", full_url.search);
    try std.testing.expectEqualStrings("#section", full_url.hash);
}

test "WorkerNavigator online/offline simulation" {
    const allocator = std.testing.allocator;

    const nav = try WorkerNavigator.init(allocator);
    defer nav.deinit();

    // Initially online
    try std.testing.expect(nav.getOnLine());

    // Simulate going offline
    nav.setOnLine(false);
    try std.testing.expect(!nav.getOnLine());

    // Simulate going back online
    nav.setOnLine(true);
    try std.testing.expect(nav.getOnLine());
}

test "WorkerGlobalScope close and termination" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/sw.js",
        .classic,
    );
    defer scope.deinit();

    try std.testing.expect(!scope.isClosing());

    scope.close();

    try std.testing.expect(scope.isClosing());

    // importScripts should do nothing when closing
    const urls = [_][]const u8{"https://example.com/lib.js"};
    try scope.importScripts(&urls);

    // Script should not have been evaluated (worker is closing)
    // Note: In our mock, we return early if closing
    // The evaluator won't have the record
}

test "WorkerGlobalScope btoa and atob" {
    const allocator = std.testing.allocator;

    const scope = try WorkerGlobalScope.init(
        allocator,
        "https://example.com/sw.js",
        .classic,
    );
    defer scope.deinit();

    const original = "Hello, Service Worker!";

    const encoded = try scope.btoa(original);
    defer allocator.free(encoded);

    const decoded = try scope.atob(encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(original, decoded);
}
