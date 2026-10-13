//! HTML form indexed access follows its live elements collection.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const form = try element(document, "form");
    defer dom.node_creation.destroyUninserted(form);
    const image = try element(document, "input");
    _ = try interfaces.Node.call_appendChild(form, image);
    try interfaces.HTMLInputElement.set_type(image, runtime.DOMString.initInterned("image"));
    const input = try element(document, "input");
    _ = try interfaces.Node.call_appendChild(form, input);
    const button = try element(document, "button");
    _ = try interfaces.Node.call_appendChild(form, button);

    try testing.expectEqual(@as(u32, 2), try interfaces.HTMLFormElement.get_length(form));
    try testing.expectEqual(input, try interfaces.HTMLFormElement.call_getter(form, 0));
    try testing.expectEqual(button, try interfaces.HTMLFormElement.call_getter(form, 1));
    try interfaces.HTMLInputElement.set_type(image, runtime.DOMString.initInterned("text"));
    try testing.expectEqual(image, try interfaces.HTMLFormElement.call_getter(form, 0));
    try testing.expectEqual(input, try interfaces.HTMLFormElement.call_getter(form, 1));
    try testing.expectEqual(button, try interfaces.HTMLFormElement.call_getter(form, 2));
    _ = try interfaces.Node.call_removeChild(form, input);
    defer dom.node_creation.destroyUninserted(input);
    try testing.expectEqual(button, try interfaces.HTMLFormElement.call_getter(form, 1));
}

test "form indexed getter follows live listed controls and excludes image inputs" {
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
