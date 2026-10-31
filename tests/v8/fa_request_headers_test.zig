//! Request constructor step 33 replaces or sanitizes the copied header list.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

const Trial = struct {
    filter: bool,
    result: anyerror!void = {},

    fn run(self: *Trial) void {
        self.result = self.check();
    }

    fn check(self: *Trial) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        defer runtime.deinitializeRuntime();
        var context = try runtime.ContextData.init(testing.allocator, .{});
        defer context.deinit();
        const Init = @typeInfo(@TypeOf(interfaces.Request.call_constructor)).@"fn".param_types[2].?;
        const input = try interfaces.Request.call_constructor(&context, .{ .usvstring = "https://example.test/" }, Init.passed(.{
            .headers = .{ .byte_string_byte_string_record = &.{
                .{ .key = "x-old", .value = "1" },
                .{ .key = "content-type", .value = "application/json" },
                .{ .key = "accept", .value = "text/plain" },
            } },
        }));
        defer destroyRequest(input);
        const request = try interfaces.Request.call_constructor(&context, .{ .request = input }, Init.passed(if (self.filter)
            .{ .mode = ._no_cors_ }
        else
            .{ .headers = .{ .byte_string_byte_string_record = &.{} } }));
        defer destroyRequest(request);
        const headers = try interfaces.Request.get_headers(request);
        defer runtime.Instance.deinit(headers);
        try testing.expect(!try interfaces.Headers.call_has(headers, "x-old"));
        try testing.expect(!try interfaces.Headers.call_has(headers, "content-type"));
        try testing.expectEqual(self.filter, try interfaces.Headers.call_has(headers, "accept"));
        const original_headers = try interfaces.Request.get_headers(input);
        defer runtime.Instance.deinit(original_headers);
        try testing.expect(try interfaces.Headers.call_has(original_headers, "x-old"));
    }
};

fn destroyRequest(request: *runtime.Instance) void {
    const signal = interfaces.Request.get_signal(request) catch unreachable;
    runtime.Instance.deinit(request);
    runtime.Instance.deinit(signal);
}

fn check(filter: bool) !void {
    var trial: Trial = .{ .filter = filter };
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}

test "RequestInit empty headers replace the input list" {
    try check(false);
}

test "RequestInit mode sanitizes the inherited list" {
    try check(true);
}
