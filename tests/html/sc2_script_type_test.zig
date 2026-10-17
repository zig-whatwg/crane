//! HTML prepare-the-script-element type-string regressions.
const std = @import("std");
const cases = @import("html").script_execution.script_type_test_cases;

fn onThread(result: *anyerror!void) void {
    result.* = cases.attributes();
}

test "script type preserves absent versus empty type and exact legacy languages" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, onThread, .{&result});
    thread.join();
    try result;
}
