//! Output's default-value override is released by document teardown.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const output = try interfaces.HTMLOutputElement.init(testing.allocator, &context);
    _ = try interfaces.Node.call_appendChild(document, output);
    try interfaces.HTMLOutputElement.set_defaultValue(output, runtime.DOMString.initInterned("default"));
    // The replacement detaches this native node. With no engine the test
    // owns that orphan; document teardown owns the output and its new text.
    const old_text = (try interfaces.Node.get_firstChild(output)).?;
    defer @import("dom").node_creation.destroyUninserted(old_text);
    try interfaces.HTMLOutputElement.set_value(output, runtime.DOMString.initInterned("current"));
    var saved = try interfaces.HTMLOutputElement.get_defaultValue(output);
    defer saved.deinit(testing.allocator);
    try testing.expectEqualStrings("default", saved.asSlice());
}

test "document teardown releases an output's owned default-value override" {
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
