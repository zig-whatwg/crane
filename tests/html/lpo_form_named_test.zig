//! Form named access and its existing live-list ownership seam.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn append(document: *runtime.Instance, parent: *runtime.Instance, tag: []const u8, name: []const u8) !*runtime.Instance {
    const node = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(tag), .notPassed());
    errdefer dom.node_creation.destroyUninserted(node);
    try interfaces.Element.call_setAttribute(node, runtime.DOMString.initInterned("name"), .{ .domstring = runtime.DOMString.initInterned(name) });
    _ = try interfaces.Node.call_appendChild(parent, node);
    return node;
}

fn named(form: *runtime.Instance, name: []const u8) !runtime.JSValue {
    return interfaces.HTMLFormElement.call_getter__1(form, runtime.DOMString.initInterned(name));
}

fn exercise(comptime images: bool) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const form = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("form"), .notPassed());
    defer dom.node_creation.destroyUninserted(form);
    const first = try append(document, form, if (images) "img" else "input", "group");
    try testing.expectEqual(first, (try named(form, "group")).instance);
    const second = try append(document, form, if (images) "img" else "button", "group");
    const list = (try named(form, "group")).instance;
    defer runtime.Instance.deinit(list);
    try testing.expectEqual(@as(u32, 2), try interfaces.RadioNodeList.get_length(list));
    try testing.expectEqual(first, (try interfaces.RadioNodeList.call_item(list, 0)).?);
    try testing.expectEqual(second, (try interfaces.RadioNodeList.call_item(list, 1)).?);
    try interfaces.Element.call_setAttribute(second, runtime.DOMString.initInterned("name"), .{ .domstring = runtime.DOMString.initInterned("changed") });
    try testing.expectEqual(@as(u32, 1), try interfaces.RadioNodeList.get_length(list));
    try interfaces.Element.set_id(second, runtime.DOMString.initInterned("group"));
    try testing.expectEqual(@as(u32, 2), try interfaces.RadioNodeList.get_length(list));
    const other = try append(document, form, "form", "other");
    _ = try interfaces.Node.call_appendChild(other, second);
    try testing.expectEqual(@as(u32, 1), try interfaces.RadioNodeList.get_length(list));
    try testing.expectEqual(second, (try named(other, "group")).instance);
    if (images) {
        const control = try append(document, form, "input", "group");
        try testing.expectEqual(control, (try named(form, "group")).instance);
        try testing.expectEqual(first, (try interfaces.RadioNodeList.call_item(list, 0)).?);
    }
}

fn runOnThread(comptime images: bool) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(images) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

fn expectNames(allocator: std.mem.Allocator, form: *runtime.Instance) !void {
    const names = try interfaces.HTMLFormElement.getSupportedPropertyNames(form, allocator);
    defer {
        for (names) |*name| name.deinit(allocator);
        allocator.free(names);
    }
    const expected = [_][]const u8{ "pictureId", "picture", "fieldId", "shared", "lastId" };
    try testing.expectEqual(expected.len, names.len);
    for (expected, names) |value, name| try testing.expectEqualStrings(value, name.asSlice());
}

fn exerciseNames() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const form = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("form"), .notPassed());
    defer dom.node_creation.destroyUninserted(form);
    const image = try append(document, form, "img", "picture");
    try interfaces.Element.set_id(image, runtime.DOMString.initInterned("pictureId"));
    const first = try append(document, form, "input", "shared");
    try interfaces.Element.set_id(first, runtime.DOMString.initInterned("fieldId"));
    _ = try append(document, form, "input", "shared");
    const last = try append(document, form, "input", "");
    try interfaces.Element.set_id(last, runtime.DOMString.initInterned("lastId"));
    const excluded = try append(document, form, "input", "excluded");
    try interfaces.HTMLInputElement.set_type(excluded, runtime.DOMString.initInterned("image"));
    const other = try append(document, form, "form", "other");
    _ = try append(document, other, "input", "notOwned");
    try expectNames(testing.allocator, form);
    // Exercise every allocation failure in the caller-owned supported names.
    try testing.checkAllAllocationFailures(testing.allocator, expectNames, .{form});
}

test "form supported names preserve tree and source order and free partial allocations" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exerciseNames() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "form named control candidates remain live after names and owners change" {
    try runOnThread(false);
}

test "form image fallback candidates remain live and yield to listed controls" {
    try runOnThread(true);
}
