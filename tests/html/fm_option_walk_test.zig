//! HTML option-list brand checks neither clone names nor count foreign elements.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const options = @import("html").forms.options;
const testing = std.testing;

fn exercise(comptime with_foreign: bool) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const select = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("select"), .notPassed());
    defer dom.node_creation.destroyUninserted(select);
    const parent = if (with_foreign) blk: {
        const foreign = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/2000/svg"), runtime.DOMString.initInterned("option"), .notPassed());
        _ = try interfaces.Node.call_appendChild(select, foreign);
        break :blk foreign;
    } else select;
    const option = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("option"), .notPassed());
    _ = try interfaces.Node.call_appendChild(parent, option);
    const Visit = struct {
        expected: *runtime.Instance,
        count: *usize,
        fn visit(self: @This(), item: *runtime.Instance) anyerror!void {
            try testing.expectEqual(self.expected, item);
            self.count.* += 1;
        }
    };
    var count: usize = 0;
    try options.forEach(select, Visit{ .expected = option, .count = &count }, Visit.visit);
    try testing.expectEqual(@as(usize, 1), count);
    var failing = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    const original = context.allocator;
    context.allocator = failing.allocator();
    defer context.allocator = original;
    count = 0;
    try options.forEach(select, Visit{ .expected = option, .count = &count }, Visit.visit);
    try testing.expectEqual(@as(usize, 1), count);
    try testing.expect(!failing.has_induced_failure);
}

fn runOnThread(comptime with_foreign: bool) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(with_foreign) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "option walk excludes foreign options and traverses their children" {
    try runOnThread(true);
}
test "option walk does not allocate local names" {
    try runOnThread(false);
}
