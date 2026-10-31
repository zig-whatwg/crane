//! RequestInit.integrity replaces the cloned request's owned metadata.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const Trial = struct {
    result: anyerror!void = {},
    fn run(self: *@This()) void {
        self.result = check();
    }
    fn check() !void {
        const a = std.testing.allocator;
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(a);
        defer runtime.deinitializeRuntime();
        var context = try runtime.ContextData.init(a, .{});
        defer context.deinit();
        const Init = @typeInfo(@TypeOf(interfaces.Request.call_constructor)).@"fn".param_types[2].?;
        const original = try interfaces.Request.call_constructor(&context, .{ .usvstring = "https://example.test/" }, Init.passed(.{
            .integrity = runtime.DOMString.initInterned("sha256-original"),
        }));
        defer destroy(original);
        for ([_][]const u8{ "sha384-replacement", "" }) |metadata| {
            const replacement = try interfaces.Request.call_constructor(&context, .{ .request = original }, Init.passed(.{
                .integrity = runtime.DOMString.initInterned(metadata),
            }));
            defer destroy(replacement);
            var value = try interfaces.Request.get_integrity(replacement);
            defer value.deinit(a);
            try std.testing.expectEqualStrings(metadata, value.asSlice());
        }
        var value = try interfaces.Request.get_integrity(original);
        defer value.deinit(a);
        try std.testing.expectEqualStrings("sha256-original", value.asSlice());
    }
};

fn destroy(request: *runtime.Instance) void {
    const signal = interfaces.Request.get_signal(request) catch unreachable;
    runtime.Instance.deinit(request);
    runtime.Instance.deinit(signal);
}

test "sri Request integrity overrides release the cloned metadata" {
    var trial: Trial = .{};
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}
