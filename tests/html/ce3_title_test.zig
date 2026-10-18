//! HTML title text semantics through the generated interface, with leak checks.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

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

fn titleText() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const doc = try interfaces.Document.init(testing.allocator, &ctx);
    defer interfaces.Document.deinit(doc);
    const ns = runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml");
    const title = try interfaces.Document.call_createElementNS(doc, ns, runtime.DOMString.initInterned("title"), .notPassed());
    _ = try interfaces.Node.call_appendChild(doc, title);
    const left = try interfaces.Document.call_createTextNode(doc, runtime.DOMString.initInterned("left"));
    defer if ((interfaces.Node.get_parentNode(left) catch null) == null) dom.node_creation.destroyUninserted(left);
    _ = try interfaces.Node.call_appendChild(title, left);
    const nested = try interfaces.Document.call_createElementNS(doc, ns, runtime.DOMString.initInterned("span"), .notPassed());
    defer if ((interfaces.Node.get_parentNode(nested) catch null) == null) dom.node_creation.destroyUninserted(nested);
    _ = try interfaces.Node.call_appendChild(title, nested);
    try interfaces.Node.set_textContent(nested, runtime.DOMString.initInterned("nested"));
    const right = try interfaces.Document.call_createTextNode(doc, runtime.DOMString.initInterned("right"));
    defer if ((interfaces.Node.get_parentNode(right) catch null) == null) dom.node_creation.destroyUninserted(right);
    _ = try interfaces.Node.call_appendChild(title, right);
    var text = try interfaces.HTMLTitleElement.get_text(title);
    defer text.deinit(testing.allocator);
    try testing.expectEqualStrings("leftright", text.asSlice());
    try interfaces.HTMLTitleElement.set_text(title, runtime.DOMString.initInterned("replacement"));
    var replaced = try interfaces.HTMLTitleElement.get_text(title);
    defer replaced.deinit(testing.allocator);
    try testing.expectEqualStrings("replacement", replaced.asSlice());
    const first = (try interfaces.Node.get_firstChild(title)).?;
    // This engine-free fixture owns nodes removed by string replace all.
    // The document destructor owns only nodes still attached to its tree.
    defer if ((interfaces.Node.get_parentNode(first) catch null) == null) dom.node_creation.destroyUninserted(first);
    try testing.expectEqual(interfaces.Node.get_TEXT_NODE(), try interfaces.Node.get_nodeType(first));
    try testing.expectEqual(null, try interfaces.Node.get_nextSibling(first));
    try interfaces.HTMLTitleElement.set_text(title, runtime.DOMString.initEmpty());
    try testing.expectEqual(null, try interfaces.Node.get_firstChild(title));
}

test "title text reads only Text children and replaces all children" {
    try onFreshThread(titleText);
}
