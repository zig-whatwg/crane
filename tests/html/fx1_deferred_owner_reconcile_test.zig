//! Q46: preserve the duplicate pure helper's coverage on the one real owner.
//! These tests queue into a real Window fetch group, through interfaces/hooks.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch = @import("fetch");
const deferred = dom.deferred_fetches;
const testing = std.testing;

const Case = enum { preparation, allocation_failures, saturation, allocation };

fn prepareCase(allocator: std.mem.Allocator, window: *runtime.Instance, document: *runtime.Instance) !void {
    const group = dom.global_settings.fetchGroupOf(window) orelse return error.NoFetchGroup;
    // End unsent records before the Window: this native test sends no network
    // request and retains no task, realm or script value.
    defer group.deferred.deinit();
    const policy = dom.policy_containers.of(document) orelse return error.NoPolicy;
    policy.referrer_policy = .origin;
    const request = try fetch.internal.InternalRequest.init(allocator, "https://destination.test/");
    // queue TAKES request on failure as well as success.
    const activated = try deferred.queue(window, request, .{ .total_request_length = 32 });
    defer activated.release();
    try testing.expectEqual(@as(usize, 1), group.deferred.count());
    const held = group.deferred.items.items[0].request orelse return error.NoRequest;
    try testing.expect(held == request);
    policy.referrer_policy = .no_referrer;
    try testing.expectEqualStrings("https://client.test", held.origin.origin);
    try testing.expectEqualStrings("https://client.test/page", held.referrer.url);
    try testing.expectEqual(fetch.internal.request.ReferrerPolicy.origin, held.policyContainerReferrerPolicy());
    try testing.expectEqual(fetch.internal.request.ServiceWorkersMode.none, held.service_workers_mode);
    try testing.expect(held.keepalive);
    try testing.expect(!activated.value);
}

fn exercise(comptime selected: Case) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    try context.setDocumentUrl("https://client.test/page");
    const window = try interfaces.Window.init(testing.allocator, &context);
    defer interfaces.Window.deinit(window);
    const origin = try dom.origin_record.OriginRecord.create(testing.allocator, "https://client.test");
    defer origin.release();
    const document = try interfaces.Document.initWith(testing.allocator, &context, .{ .origin = origin });
    // Window owns its associated Document, as in pm2_permission_origin_test.
    dom.window_globals.setDocument(window, document);
    dom.document_browsing_context.setWindow(document, window);
    try dom.document_internals.setURL(document, "https://client.test/page");
    const navigables = dom.browser_state.navigablesOf(&context) orelse return error.NoNavigables;
    try testing.expectEqual(@as(usize, 1), navigables.contexts().len);
    navigables.contexts()[0].setActiveDocument(@ptrCast(document), @ptrCast(window));
    const group = dom.global_settings.fetchGroupOf(window) orelse return error.NoFetchGroup;
    defer group.deferred.deinit();
    switch (selected) {
        .preparation => try prepareCase(testing.allocator, window, document),
        .allocation_failures => {
            // The old preparation test failed request-owned allocations. Keep
            // that exact scope: global/Window setup remains leak-checked, while
            // every request allocation and client-population copy is failed.
            try testing.checkAllAllocationFailures(testing.allocator, prepareCase, .{ window, document });
        },
        .allocation => {
            const request = try fetch.internal.InternalRequest.init(testing.allocator, "https://destination.test/");
            // Queue is the post-validation owner API. An aggregate synthetic
            // pending length makes the document limit observable below the
            // independent 64 KiB per-origin ceiling.
            const activated = try deferred.queue(window, request, .{ .total_request_length = 600 * 1024 });
            defer activated.release();
            try testing.expectEqual(@as(u64, 40 * 1024), deferred.availableQuota(document, "https://other.test", .{ .deferred_fetch = true, .deferred_fetch_minimal = false }));
            try testing.expectEqual(@as(u64, 0), deferred.availableQuota(document, "https://other.test", .{ .deferred_fetch = true, .deferred_fetch_minimal = true }));
            try testing.expectEqual(@as(u64, 0), deferred.availableQuota(document, "https://other.test", .{ .deferred_fetch = false, .deferred_fetch_minimal = true }));
            try testing.expectEqual(@as(u64, 0), deferred.availableQuota(document, "https://other.test", .{ .deferred_fetch = false, .deferred_fetch_minimal = false }));
        },
        .saturation => {
            const policy: deferred.Policy = .{ .deferred_fetch = true, .deferred_fetch_minimal = true };
            const request = try fetch.internal.InternalRequest.init(testing.allocator, "https://destination.test/");
            const activated = try deferred.queue(window, request, .{ .total_request_length = std.math.maxInt(u64) });
            defer activated.release();
            try testing.expectEqual(@as(u64, 0), deferred.availableQuota(document, "https://destination.test", policy));
            try testing.expectEqual(@as(u64, 0), deferred.availableQuota(document, "https://other.test", policy));
            group.deferred.deinit();
            try testing.expectEqual(@as(u64, 64 * 1024), deferred.availableQuota(document, "https://destination.test", policy));
        },
    }
}

fn onThread(comptime selected: Case) !void {
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *?anyerror) void {
            exercise(selected) catch |err| {
                out.* = err;
            };
        }
    }.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "deferred owner snapshots client policy and disables service workers" {
    try onThread(.preparation);
}

test "deferred owner preparation frees the taken request under every allocation failure" {
    try onThread(.allocation_failures);
}

test "deferred owner quota cannot underflow for a maximal pending request length" {
    try onThread(.saturation);
}

test "deferred owner top-level allocation distinguishes 640 KiB from the minimal reservation" {
    try onThread(.allocation);
}
