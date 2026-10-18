//! Fresh per-thread context for form regressions, with leak-checking allocation.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

pub fn attribute(element: *runtime.Instance, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned(name), .{ .domstring = runtime.DOMString.initInterned(value) });
}

pub fn create(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}

pub fn run(comptime exercise: fn (*runtime.Instance) anyerror!void) !void {
    const Run = struct {
        fn body() !void {
            interfaces.process_hooks.startHooksForTest();
            runtime.initializeRuntime(std.testing.allocator);
            defer runtime.deinitializeRuntime();
            var context = try runtime.ContextData.init(std.testing.allocator, .{});
            defer context.deinit();
            const document = try interfaces.Document.init(std.testing.allocator, &context);
            defer interfaces.Document.deinit(document);
            try exercise(document);
        }
        fn threadBody(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.threadBody, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
