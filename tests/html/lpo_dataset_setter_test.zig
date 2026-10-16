//! DOMStringMap rejects invalid names before mutating its element.
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
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const element = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("div"), .notPassed());
    defer dom.node_creation.destroyUninserted(element);
    const dataset = try interfaces.HTMLElement.get_dataset(element);
    defer runtime.Instance.deinit(dataset);
    const value = runtime.DOMString.initInterned("value");
    for ([_][]const u8{ "-a", "foo-bar", "--a", "bad-a/", "bad-a " }) |name| {
        try testing.expectError(error.SyntaxError, interfaces.DOMStringMap.call_setter(dataset, runtime.DOMString.initInterned(name), value));
    }
    for ([_][]const u8{ "bad name", "bad\tname", "bad\nname", "bad\rname", "bad\x0cname", "bad\x00name", "bad/name", "bad=name", "bad>name" }) |name| {
        try testing.expectError(error.InvalidCharacterError, interfaces.DOMStringMap.call_setter(dataset, runtime.DOMString.initInterned(name), value));
    }
    try testing.expect(!try interfaces.Element.call_hasAttributes(element));

    const cases = [_]struct { property: []const u8, attribute: []const u8 }{
        .{ .property = "", .attribute = "data-" },
        .{ .property = "fooBar", .attribute = "data-foo-bar" },
        .{ .property = "foo-Bar", .attribute = "data-foo--bar" },
        .{ .property = "-", .attribute = "data--" },
        .{ .property = "foo-9", .attribute = "data-foo-9" },
        .{ .property = "é-É", .attribute = "data-é-É" },
    };
    for (cases) |case| {
        try interfaces.DOMStringMap.call_setter(dataset, runtime.DOMString.initInterned(case.property), value);
        var actual = (try interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned(case.attribute))).?;
        defer actual.deinit(testing.allocator);
        try testing.expectEqualStrings("value", actual.asSlice());
    }
}

test "dataset setter validates hyphen-lowercase before attribute names and converts only ASCII capitals" {
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
