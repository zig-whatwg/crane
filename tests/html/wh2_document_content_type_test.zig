//! A failed MIME replacement preserves the Document's previous type.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var failing = testing.FailingAllocator.init(testing.allocator, .{});
    const allocator = failing.allocator();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(allocator, &ctx);
    defer dom.node_creation.destroyUninserted(document);
    try dom.document_internals.setContentType(document, "text/html");
    failing.fail_index = failing.alloc_index;
    try testing.expectError(error.OutOfMemory, dom.document_internals.setContentType(document, "image/png"));
    failing.fail_index = std.math.maxInt(usize);
    try testing.expectEqualStrings("text/html", dom.document_internals.getContentType(document).?);
    try dom.document_internals.setContentType(document, "image/png");
    try testing.expectEqualStrings("image/png", dom.document_internals.getContentType(document).?);
}

test "Document MIME replacement is atomic on allocation failure" {
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
