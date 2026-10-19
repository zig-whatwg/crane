//! HTML 8.1.3.4: a document without a browsing context cannot run script.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn check() !void {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.createNullContext(allocator);
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(document);
    try std.testing.expect((try interfaces.Document.get_defaultView(document)) == null);
    try std.testing.expect(!dom.document_scripts.scriptingEnabled(document));
}

fn run(result: *anyerror!void) void {
    result.* = check();
}

test "a document without a browsing context has scripting disabled" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, run, .{&result});
    thread.join();
    try result;
}
