//! Textarea editor offsets and contents use the same normalized API value.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const textarea = try interfaces.HTMLTextAreaElement.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(textarea);
    try interfaces.HTMLTextAreaElement.set_value(textarea, runtime.DOMString.initInterned("a\r\nb\rc"));
    var text = (try dom.form_controls.editorText(textarea)).?;
    defer text.deinit(testing.allocator);
    try testing.expectEqualStrings("a\nb\nc", text.asSlice());
    try interfaces.HTMLTextAreaElement.set_value(textarea, runtime.DOMString.initInterned("replacement"));
    try testing.expectEqualStrings("a\nb\nc", text.asSlice());
}

test "textarea editor returns an owned normalized API value" {
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
