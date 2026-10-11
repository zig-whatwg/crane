//! HTML contenteditable states and setter, using the generated interfaces.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
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

fn check(comptime kind: enum { getter, setter, inheritance }) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx.deinit();
    const doc = try interfaces.Document.init(testing.allocator, &ctx);
    defer interfaces.Document.deinit(doc);
    const root = try interfaces.Document.call_createElementNS(doc, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("html"), .notPassed());
    _ = try interfaces.Node.call_appendChild(doc, root);
    if (kind == .getter) {
        inline for (.{ .{ "TRUE", "true" }, .{ "FALSE", "false" }, .{ "PLAINTEXT-ONLY", "plaintext-only" }, .{ "", "true" }, .{ " true", "inherit" }, .{ "falſe", "inherit" } }) |pair| {
            try interfaces.Element.call_setAttribute(root, runtime.DOMString.initInterned("contenteditable"), .{ .domstring = runtime.DOMString.initInterned(pair[0]) });
            var state = try interfaces.HTMLElement.get_contentEditable(root);
            defer state.deinit(testing.allocator);
            try testing.expectEqualStrings(pair[1], state.asSlice());
        }
    } else if (kind == .setter) {
        try testing.expectError(error.SyntaxError, interfaces.HTMLElement.set_contentEditable(root, runtime.DOMString.initInterned("")));
        inline for (.{ .{ "TRUE", "true" }, .{ "FaLsE", "false" }, .{ "PLAINTEXT-ONLY", "plaintext-only" } }) |pair| {
            try interfaces.HTMLElement.set_contentEditable(root, runtime.DOMString.initInterned(pair[0]));
            var value = (try interfaces.Element.call_getAttributeNS(root, null, runtime.DOMString.initInterned("contenteditable"))).?;
            defer value.deinit(testing.allocator);
            try testing.expectEqualStrings(pair[1], value.asSlice());
        }
        try interfaces.HTMLElement.set_contentEditable(root, runtime.DOMString.initInterned("INHERIT"));
        try testing.expectEqual(null, try interfaces.Element.call_getAttributeNS(root, null, runtime.DOMString.initInterned("contenteditable")));
    } else {
        try testing.expect(!(try interfaces.HTMLElement.get_isContentEditable(root)));
        const middle = try interfaces.Document.call_createElementNS(doc, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("div"), .notPassed());
        _ = try interfaces.Node.call_appendChild(root, middle);
        const leaf = try interfaces.Document.call_createElementNS(doc, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("span"), .notPassed());
        _ = try interfaces.Node.call_appendChild(middle, leaf);
        try interfaces.HTMLElement.set_contentEditable(root, runtime.DOMString.initInterned("true"));
        try testing.expect(try interfaces.HTMLElement.get_isContentEditable(leaf));
        try interfaces.HTMLElement.set_contentEditable(middle, runtime.DOMString.initInterned("false"));
        try testing.expect(!(try interfaces.HTMLElement.get_isContentEditable(leaf)));
        try interfaces.HTMLElement.set_contentEditable(leaf, runtime.DOMString.initInterned("plaintext-only"));
        try testing.expect(try interfaces.HTMLElement.get_isContentEditable(leaf));
    }
}
fn getter() !void {
    try check(.getter);
}
fn setter() !void {
    try check(.setter);
}
fn inheritance() !void {
    try check(.inheritance);
}
test "contentEditable getter canonicalizes the four enumerated states" {
    try onFreshThread(getter);
}
test "contentEditable setter rejects invalid states and removes inherit" {
    try onFreshThread(setter);
}
test "isContentEditable inherits until an explicit state or parent boundary" {
    try onFreshThread(inheritance);
}
