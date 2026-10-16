//! Origin API ownership and comparisons through its generated interface.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            body() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "Origin records outlive their source object and preserve opaque identity" {
    try onFreshThread(struct {
        fn run() !void {
            const allocator = std.testing.allocator;
            runtime.initializeRuntime(allocator);
            defer runtime.deinitializeRuntime();
            interfaces.process_hooks.startHooksForTest();
            var ctx = try runtime.ContextData.init(allocator, .{});
            defer ctx.deinit();

            const first = try interfaces.Origin.call_constructor(&ctx);
            defer runtime.Instance.deinit(first);
            const second = try interfaces.Origin.call_constructor(&ctx);
            defer runtime.Instance.deinit(second);
            try std.testing.expect(try interfaces.Origin.get_opaque(first));
            try std.testing.expect(try interfaces.Origin.call_isSameOrigin(first, first));
            try std.testing.expect(try interfaces.Origin.call_isSameSite(first, first));
            try std.testing.expect(!try interfaces.Origin.call_isSameOrigin(first, second));
            try std.testing.expect(!try interfaces.Origin.call_isSameSite(first, second));

            const source = try interfaces.Origin.call_constructor(&ctx);
            const copy = try interfaces.Origin.call_static_from(first, .{ .instance = source });
            defer runtime.Instance.deinit(copy);
            try std.testing.expect(try interfaces.Origin.call_isSameOrigin(copy, source));
            runtime.Instance.deinit(source);
            try std.testing.expect(try interfaces.Origin.get_opaque(copy));
            const copy_again = try interfaces.Origin.call_static_from(first, .{ .instance = copy });
            defer runtime.Instance.deinit(copy_again);
            try std.testing.expect(try interfaces.Origin.call_isSameOrigin(copy, copy_again));
        }
    }.run);
}

test "Origin parsing canonicalizes tuples and compares schemeful sites" {
    try onFreshThread(struct {
        fn run() !void {
            const allocator = std.testing.allocator;
            runtime.initializeRuntime(allocator);
            defer runtime.deinitializeRuntime();
            interfaces.process_hooks.startHooksForTest();
            var ctx = try runtime.ContextData.init(allocator, .{});
            defer ctx.deinit();
            const caller = try interfaces.Origin.call_constructor(&ctx);
            defer runtime.Instance.deinit(caller);
            const cases = [_]struct { a: []const u8, b: []const u8, same_origin: bool, same_site: bool }{
                .{ .a = "https://USER:pass@EXAMPLE.com:443/a", .b = "https://example.com", .same_origin = true, .same_site = true },
                .{ .a = "https://a.example.com", .b = "https://b.example.com:8443", .same_origin = false, .same_site = true },
                .{ .a = "https://example.com", .b = "http://example.com", .same_origin = false, .same_site = false },
                .{ .a = "https://example.com", .b = "https://example.com.", .same_origin = false, .same_site = false },
                .{ .a = "https://[::1]", .b = "https://[::1]:8443", .same_origin = false, .same_site = true },
                .{ .a = "https://localhost", .b = "https://localhost:8443", .same_origin = false, .same_site = true },
                .{ .a = "data:text/plain,a", .b = "data:text/plain,a", .same_origin = false, .same_site = false },
            };
            for (cases) |case| {
                const a = try interfaces.Origin.call_static_from(caller, runtime.JSValue.fromStringRef(case.a));
                defer runtime.Instance.deinit(a);
                const b = try interfaces.Origin.call_static_from(caller, runtime.JSValue.fromStringRef(case.b));
                defer runtime.Instance.deinit(b);
                try std.testing.expectEqual(case.same_origin, try interfaces.Origin.call_isSameOrigin(a, b));
                try std.testing.expectEqual(case.same_site, try interfaces.Origin.call_isSameSite(a, b));
            }
            for ([_][]const u8{ "", "relative/path", "http://[invalid" }) |input| {
                try std.testing.expectError(error.TypeError, interfaces.Origin.call_static_from(caller, runtime.JSValue.fromStringRef(input)));
            }
        }
    }.run);
}

test "MessageEvent extraction retains an actual origin record but rejects strings" {
    try onFreshThread(struct {
        fn run() !void {
            const allocator = std.testing.allocator;
            runtime.initializeRuntime(allocator);
            defer runtime.deinitializeRuntime();
            interfaces.process_hooks.startHooksForTest();
            var ctx = try runtime.ContextData.init(allocator, .{});
            defer ctx.deinit();
            const caller = try interfaces.Origin.call_constructor(&ctx);
            defer runtime.Instance.deinit(caller);
            const event = try interfaces.MessageEvent.call_constructor(&ctx, runtime.DOMString.initInterned("message"), .passed(.{ .base = .{}, .origin = "null" }));
            defer runtime.Instance.deinit(event);
            try std.testing.expectError(error.TypeError, interfaces.Origin.call_static_from(caller, .{ .instance = event }));

            // The firing sites are a separate lane. Exercise the event's own
            // record storage directly, as authorized by row 45's ANSWER Q3.
            event.getState(interfaces.MessageEvent.State).own._internal.?.origin_record = try dom.origin_record.OriginRecord.create(allocator, "null");
            const extracted = try interfaces.Origin.call_static_from(caller, .{ .instance = event });
            defer runtime.Instance.deinit(extracted);
            const serialized = try interfaces.MessageEvent.get_origin(event);
            defer allocator.free(serialized);
            try std.testing.expectEqualStrings("null", serialized);
            try std.testing.expect(try interfaces.Origin.get_opaque(extracted));

            try interfaces.MessageEvent.call_initMessageEvent(event, runtime.DOMString.initInterned("again"), .notPassed(), .notPassed(), .notPassed(), .passed("https://example.com"), .notPassed(), .notPassed(), .notPassed());
            try std.testing.expectError(error.TypeError, interfaces.Origin.call_static_from(caller, .{ .instance = event }));
            const copy = try interfaces.Origin.call_static_from(caller, .{ .instance = extracted });
            defer runtime.Instance.deinit(copy);
            try std.testing.expect(try interfaces.Origin.call_isSameOrigin(extracted, copy));

            const ephemeral = try interfaces.MessageEvent.call_constructor(&ctx, runtime.DOMString.initInterned("message"), .notPassed());
            ephemeral.getState(interfaces.MessageEvent.State).own._internal.?.origin_record = try dom.origin_record.OriginRecord.create(allocator, "https://example.com");
            const after_event = try interfaces.Origin.call_static_from(caller, .{ .instance = ephemeral });
            defer runtime.Instance.deinit(after_event);
            runtime.Instance.deinit(ephemeral);
            const expected = try interfaces.Origin.call_static_from(caller, runtime.JSValue.fromStringRef("https://example.com"));
            defer runtime.Instance.deinit(expected);
            try std.testing.expect(try interfaces.Origin.call_isSameOrigin(after_event, expected));
        }
    }.run);
}

test "URL extraction owns canonical tuples, distinct opaque records and no invalid URL" {
    const allocator = std.testing.allocator;
    const tuple = (try dom.extract_origin.ownedRecordForUrl(allocator, "https://EXAMPLE.com:443/path")).?;
    defer tuple.release();
    try std.testing.expectEqualStrings("https://example.com", tuple.serialized.?);
    const first = (try dom.extract_origin.ownedRecordForUrl(allocator, "data:text/plain,a")).?;
    defer first.release();
    const second = (try dom.extract_origin.ownedRecordForUrl(allocator, "data:text/plain,a")).?;
    defer second.release();
    try std.testing.expect(first.isOpaque());
    try std.testing.expect(second.isOpaque());
    try std.testing.expect(first != second);
    try std.testing.expect((try dom.extract_origin.ownedRecordForUrl(allocator, "relative/path")) == null);
}

test "Origin extraction from an xlink-only SVG anchor frees its native allocations" {
    try onFreshThread(struct {
        fn run() !void {
            const allocator = std.testing.allocator;
            runtime.initializeRuntime(allocator);
            defer runtime.deinitializeRuntime();
            interfaces.process_hooks.startHooksForTest();
            var ctx = try runtime.ContextData.init(allocator, .{});
            defer ctx.deinit();
            const caller = try interfaces.Origin.call_constructor(&ctx);
            defer runtime.Instance.deinit(caller);
            const anchor = try interfaces.SVGAElement.init(allocator, &ctx);
            defer runtime.Instance.deinit(anchor);
            try interfaces.Element.call_setAttributeNS(
                anchor,
                runtime.DOMString.initInterned("http://www.w3.org/1999/xlink"),
                runtime.DOMString.initInterned("xlink:href"),
                .{ .domstring = runtime.DOMString.initInterned("https://example.com/path") },
            );
            // No animated-string getter is called by the test. The allocator
            // also checks objects created internally by Origin extraction.
            const extracted = try interfaces.Origin.call_static_from(caller, .{ .instance = anchor });
            defer runtime.Instance.deinit(extracted);
            const expected = try interfaces.Origin.call_static_from(caller, runtime.JSValue.fromStringRef("https://example.com"));
            defer runtime.Instance.deinit(expected);
            try std.testing.expect(try interfaces.Origin.call_isSameOrigin(extracted, expected));
        }
    }.run);
}
