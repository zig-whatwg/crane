//! HTML reset-the-form-owner: only listed elements react to a form attribute.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const forms = @import("html").form_associated;

fn append(document: *runtime.Instance, parent: *runtime.Instance, tag: []const u8) !*runtime.Instance {
    const node = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(tag), .notPassed());
    errdefer dom.node_creation.destroyUninserted(node);
    _ = try interfaces.Node.call_appendChild(parent, node);
    return node;
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(std.testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const root = try append(document, document, "div");
    const form = try append(document, root, "form");
    const image = try append(document, root, "img");
    const control = try append(document, root, "input");
    try forms.parserAssociate(image, form, root);
    try forms.parserAssociate(control, form, root);
    try std.testing.expectEqual(@as(?*runtime.Instance, form), forms.formOwner(image));
    try std.testing.expectEqual(@as(?*runtime.Instance, form), forms.formOwner(control));
    for ([_][]const u8{ "other", "changed" }) |value| {
        try interfaces.Element.call_setAttribute(image, runtime.DOMString.initInterned("form"), .{ .domstring = runtime.DOMString.initInterned(value) });
        try std.testing.expectEqual(@as(?*runtime.Instance, form), forms.formOwner(image));
    }
    try interfaces.Element.call_removeAttribute(image, runtime.DOMString.initInterned("form"));
    try std.testing.expectEqual(@as(?*runtime.Instance, form), forms.formOwner(image));
    try interfaces.Element.call_setAttribute(control, runtime.DOMString.initInterned("form"), .{ .domstring = runtime.DOMString.initInterned("other") });
    try interfaces.Element.call_removeAttribute(control, runtime.DOMString.initInterned("form"));
    try std.testing.expectEqual(null, forms.formOwner(control));
}

test "an unlisted parser-associated image retains its owner when form is set changed or removed" {
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
