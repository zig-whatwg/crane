//! Reflected command targets use weak, live tree associations.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const t = std.testing;

fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(t.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(t.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(t.allocator, &context);
    defer interfaces.Document.deinit(document);
    const root = try element(document, "div");
    defer dom.node_creation.destroyUninserted(root);
    const button = try element(document, "button");
    _ = try interfaces.Node.call_appendChild(root, button);
    const target = try element(document, "div");
    _ = try interfaces.Node.call_appendChild(root, target);
    try interfaces.Element.set_id(target, runtime.DOMString.initInterned("target"));
    try interfaces.Element.call_setAttribute(button, runtime.DOMString.initInterned("commandfor"), .{ .domstring = runtime.DOMString.initInterned("target") });
    try t.expectEqual(target, (try interfaces.HTMLButtonElement.get_commandForElement(button)).?);
    try interfaces.Element.set_id(target, runtime.DOMString.initInterned("changed"));
    try t.expectEqual(null, try interfaces.HTMLButtonElement.get_commandForElement(button));
    try interfaces.HTMLButtonElement.set_commandForElement(button, target);
    try t.expectEqual(target, (try interfaces.HTMLButtonElement.get_commandForElement(button)).?);
    try interfaces.Element.call_setAttribute(button, runtime.DOMString.initInterned("commandfor"), .{ .domstring = runtime.DOMString.initEmpty() });
    try t.expectEqual(null, try interfaces.HTMLButtonElement.get_commandForElement(button));
    try interfaces.HTMLButtonElement.set_commandForElement(button, target);
    try interfaces.HTMLButtonElement.set_commandForElement(button, null);
    try t.expect(!(try interfaces.Element.call_hasAttribute(button, runtime.DOMString.initInterned("commandfor"))));
    try interfaces.HTMLButtonElement.set_commandForElement(button, target);
    _ = try interfaces.Node.call_removeChild(root, target);
    dom.node_creation.destroyUninserted(target);
    try t.expectEqual(null, try interfaces.HTMLButtonElement.get_commandForElement(button));
}

test "commandForElement resets its explicit weak target on content attribute changes" {
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
