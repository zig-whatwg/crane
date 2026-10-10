//! Element class collections stay live across mutations, through their interface.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn check() !void {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    const doc = try interfaces.Document.init(allocator, &ctx);
    defer interfaces.Document.deinit(doc);
    const root = try interfaces.Document.call_createElementNS(doc, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("div"), .notPassed());
    var root_alive = true;
    defer if (root_alive) dom.node_creation.destroyUninserted(root);
    const classes = try interfaces.Element.call_getElementsByClassName(root, runtime.DOMString.initInterned("held"));
    defer runtime.Instance.deinit(classes);
    const child = try interfaces.Document.call_createElementNS(doc, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("span"), .notPassed());
    try interfaces.Element.set_className(child, runtime.DOMString.initInterned("held"));
    _ = try interfaces.Node.call_appendChild(root, child);
    if (try interfaces.HTMLCollection.get_length(classes) != 1) return error.ClassNamesNotLive;
    // Explicit native teardown may outlive a list; it must not read a reused
    // root slot. Root retention is a separate refcount follow-up (Q20).
    dom.node_creation.destroyUninserted(root);
    root_alive = false;
    try std.testing.expectEqual(@as(u32, 0), try interfaces.HTMLCollection.get_length(classes));
}

test "element class collection reads mutations and rejects explicitly destroyed roots" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            check() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
