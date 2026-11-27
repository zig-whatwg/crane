const std = @import("std");
const crane = @import("crane");

pub const std_options: std.Options = .{
    .log_level = .warn,
    .signal_stack_size = null,
};

pub fn main(init: std.process.Init) !void {
    var rt = try crane.initRuntime(.{ .snapshot_path = "" });
    defer rt.deinit();

    const allocator = std.heap.c_allocator;
    var browser = try crane.Browser.create(allocator, .{});
    defer browser.deinit();

    try browser.navigate("data:text/html,<title>Zig Consumer</title>");

    var result = try browser.eval("\"ran \" + (6 * 7)");
    defer result.deinit();
    if (result.isException()) return error.EvalException;

    const text = (try result.stringValue(allocator)) orelse return error.UnexpectedResult;
    defer allocator.free(text);

    var stdout_buf: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buf);
    try stdout.interface.print("{s}\n", .{text});
    try stdout.interface.flush();
}
