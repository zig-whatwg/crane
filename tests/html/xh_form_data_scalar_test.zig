//! HTML's native form entry path also creates scalar-value strings.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    const data = try interfaces.FormData.call_constructor(&context, .notPassed(), .notPassed());
    defer runtime.Instance.deinit(data);
    try interfaces.FormData.call_append(data, "key\xED\xA0\x80", "a\xED\xB0\x80b\xF0\x9F\x9A\x80");
    const value = (try interfaces.FormData.call_get(data, "key\xEF\xBF\xBD")) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("a\xEF\xBF\xBDb\xF0\x9F\x9A\x80", value.usvstring);
}

test "native FormData append creates scalar strings in names and values" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
