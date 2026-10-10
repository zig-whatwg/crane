//! Native state reads must work without starting a JavaScript engine.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const t = std.testing;

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(t.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(t.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(t.allocator, &context);
    defer interfaces.Document.deinit(document);
    const input = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("input"), .notPassed());
    defer dom.node_creation.destroyUninserted(input);
    try interfaces.HTMLInputElement.set_required(input, true);
    try t.expect(html.pseudo_classes.matches(input, .invalid));
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("value"));
    try t.expect(html.pseudo_classes.matches(input, .valid));
    try interfaces.HTMLInputElement.set_readOnly(input, true);
    try t.expect(!html.pseudo_classes.matches(input, .valid));
    try t.expect(html.pseudo_classes.matches(input, .read_only));
    try interfaces.HTMLInputElement.set_readOnly(input, false);
    try interfaces.HTMLInputElement.set_type(input, runtime.DOMString.initInterned("checkbox"));
    try interfaces.HTMLInputElement.set_checked(input, true);
    try t.expect(html.pseudo_classes.matches(input, .checked));
    try t.expect(!html.pseudo_classes.matches(input, .default));
    try interfaces.HTMLInputElement.set_defaultChecked(input, true);
    try interfaces.HTMLInputElement.set_checked(input, false);
    try t.expect(html.pseudo_classes.matches(input, .default));
    try t.expect(!html.pseudo_classes.matches(input, .checked));
    try interfaces.HTMLInputElement.set_indeterminate(input, true);
    try t.expect(html.pseudo_classes.matches(input, .indeterminate));
}

test "HTML pseudo-classes read live owner state through interfaces" {
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
