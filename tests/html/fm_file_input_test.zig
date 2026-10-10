//! The input owns only empty FileLists it made without an engine.
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
    const input = try interfaces.HTMLInputElement.init(testing.allocator, &context);
    var input_live = true;
    defer if (input_live) dom.node_creation.destroyUninserted(input);
    inline for (.{ "hidden", "text", "search", "tel", "url", "email", "password", "date", "month", "week", "time", "datetime-local", "number", "range", "color", "checkbox", "radio", "submit", "image", "reset", "button" }) |kind| {
        try interfaces.HTMLInputElement.set_type(input, runtime.DOMString.initInterned(kind));
        try testing.expectEqual(null, try interfaces.HTMLInputElement.get_files(input));
    }
    try interfaces.HTMLInputElement.set_type(input, runtime.DOMString.initInterned("file"));
    const empty = (try interfaces.HTMLInputElement.get_files(input)).?;
    try testing.expectEqual(empty, (try interfaces.HTMLInputElement.get_files(input)).?);
    try testing.expectEqual(@as(u32, 0), try interfaces.FileList.get_length(empty));
    try interfaces.HTMLInputElement.set_files(input, null);
    try testing.expectEqual(empty, (try interfaces.HTMLInputElement.get_files(input)).?);
    try testing.expectError(error.TypeError, interfaces.HTMLInputElement.set_files(input, input));
    try interfaces.HTMLInputElement.set_value(input, .empty);
    try testing.expectEqual(empty, (try interfaces.HTMLInputElement.get_files(input)).?);
    dom.form_controls.reset(input);
    try testing.expectEqual(empty, (try interfaces.HTMLInputElement.get_files(input)).?);

    const assigned = try interfaces.FileList.init(testing.allocator, &context);
    defer runtime.Instance.deinit(assigned);
    const generation = runtime.SlabAllocator.generationOf(assigned);
    try interfaces.HTMLInputElement.set_files(input, assigned);
    try testing.expectEqual(assigned, (try interfaces.HTMLInputElement.get_files(input)).?);
    dom.node_creation.destroyUninserted(input);
    input_live = false;
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(assigned));
    try testing.expect(!runtime.instance_lifecycle.isCleanedUp(assigned));
    try testing.expectEqual(@as(u32, 0), try interfaces.FileList.get_length(assigned));
}

test "input FileList identity, applicability, brand defense and native ownership" {
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
