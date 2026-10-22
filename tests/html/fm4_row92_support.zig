//! Forms remainder regressions through generated interfaces, with leak checking.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

pub fn attribute(element: *runtime.Instance, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned(name), .{ .domstring = runtime.DOMString.initInterned(value) });
}

pub fn create(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}

pub fn expectValue(input: *runtime.Instance, expected: []const u8) !void {
    var value = try interfaces.HTMLInputElement.get_value(input);
    defer value.deinit(testing.allocator);
    try testing.expectEqualStrings(expected, value.asSlice());
}

pub fn withDocument(comptime body: fn (*runtime.Instance) anyerror!void) !void {
    const Run = struct {
        fn exercise() !void {
            interfaces.process_hooks.startHooksForTest();
            runtime.initializeRuntime(testing.allocator);
            defer runtime.deinitializeRuntime();
            var context = try runtime.ContextData.init(testing.allocator, .{});
            defer context.deinit();
            const document = try interfaces.Document.init(testing.allocator, &context);
            defer interfaces.Document.deinit(document);
            try body(document);
        }

        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
