//! HTML document accessors, through their real interfaces, with allocator checks.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;
const html_ns = "http://www.w3.org/1999/xhtml";

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            body() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

fn element(doc: *runtime.Instance, ns: ?[]const u8, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(doc, if (ns) |value| runtime.DOMString.initInterned(value) else null, runtime.DOMString.initInterned(name), .notPassed());
}

fn globalAttributes() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const doc = try interfaces.Document.init(testing.allocator, &ctx);
    defer interfaces.Document.deinit(doc);
    const root = try element(doc, html_ns, "html");
    _ = try interfaces.Node.call_appendChild(doc, root);
    const child = try element(doc, html_ns, "div");
    _ = try interfaces.Node.call_appendChild(root, child);
    try interfaces.HTMLElement.set_translate(root, false);
    try testing.expect(!(try interfaces.HTMLElement.get_translate(child)));
    try interfaces.HTMLElement.set_dir(child, runtime.DOMString.initInterned("RTL"));
    var direction = try interfaces.HTMLElement.get_dir(child);
    defer direction.deinit(testing.allocator);
    try testing.expectEqualStrings("rtl", direction.asSlice());
    try interfaces.Document.set_dir(doc, runtime.DOMString.initInterned("AUTO"));
    var document_direction = try interfaces.Document.get_dir(doc);
    defer document_direction.deinit(testing.allocator);
    try testing.expectEqualStrings("auto", document_direction.asSlice());
    const foreign_body = try element(doc, "urn:foreign", "body");
    _ = try interfaces.Node.call_appendChild(root, foreign_body);
    try testing.expectEqual(null, try interfaces.Document.get_body(doc));
    const body = try element(doc, html_ns, "body");
    _ = try interfaces.Node.call_appendChild(root, body);
    try testing.expectEqual(body, (try interfaces.Document.get_body(doc)).?);
}

test "global attributes compute translate inheritance and canonical dir" {
    try onFreshThread(globalAttributes);
}
