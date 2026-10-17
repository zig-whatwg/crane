//! Decimal numeric input stepping, through the generated interface.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn attribute(element: *runtime.Instance, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned(name), .{ .domstring = runtime.DOMString.initInterned(value) });
}

fn expectValue(input: *runtime.Instance, expected: []const u8) !void {
    var value = try interfaces.HTMLInputElement.get_value(input);
    defer value.deinit(testing.allocator);
    try testing.expectEqualStrings(expected, value.asSlice());
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const input = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("input"), .notPassed());
    defer dom.node_creation.destroyUninserted(input);
    try attribute(input, "type", "number");
    try attribute(input, "step", "0.3");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("1.2"));
    try interfaces.HTMLInputElement.call_stepDown(input, .notPassed());
    try expectValue(input, "0.9");
    try interfaces.HTMLInputElement.call_stepUp(input, .passed(-1));
    try expectValue(input, "0.6");
    try attribute(input, "min", "0.05");
    try attribute(input, "max", "0.45");
    try attribute(input, "step", "0.1");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("0.25"));
    try interfaces.HTMLInputElement.call_stepUp(input, .passed(100));
    try expectValue(input, "0.45");
    try interfaces.HTMLInputElement.call_stepDown(input, .passed(100));
    try expectValue(input, "0.05");
    try interfaces.HTMLInputElement.set_value(input, runtime.DOMString.initInterned("0.26"));
    try interfaces.HTMLInputElement.call_stepUp(input, .passed(2));
    try expectValue(input, "0.45");
    try attribute(input, "max", "0.04");
    try interfaces.HTMLInputElement.call_stepDown(input, .notPassed());
    try expectValue(input, "0.45");
    try attribute(input, "step", "any");
    try testing.expectError(error.InvalidStateError, interfaces.HTMLInputElement.call_stepUp(input, .notPassed()));
}

test "numeric input steps keep decimal precision direction and bounds" {
    const Run = struct {
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
