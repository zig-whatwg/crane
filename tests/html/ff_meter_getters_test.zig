//! HTML 4.10.14: parse gauge attributes, then derive the six ordered values.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn attribute(meter: *runtime.Instance, key: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(meter, runtime.DOMString.initInterned(key), .{ .domstring = runtime.DOMString.initInterned(value) });
}

fn expectValues(meter: *runtime.Instance, expected: [6]f64) !void {
    const actual = [6]f64{
        try interfaces.HTMLMeterElement.get_min(meter),
        try interfaces.HTMLMeterElement.get_max(meter),
        try interfaces.HTMLMeterElement.get_value(meter),
        try interfaces.HTMLMeterElement.get_low(meter),
        try interfaces.HTMLMeterElement.get_high(meter),
        try interfaces.HTMLMeterElement.get_optimum(meter),
    };
    try testing.expectEqualSlices(f64, &expected, &actual);
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const meter = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("meter"), .notPassed());
    defer dom.node_creation.destroyUninserted(meter);
    try expectValues(meter, .{ 0, 1, 0, 0, 1, 0.5 });
    try attribute(meter, "min", "  +2.5tail");
    try attribute(meter, "max", "1");
    try expectValues(meter, .{ 2.5, 2.5, 2.5, 2.5, 2.5, 2.5 });
    try attribute(meter, "min", "-10");
    try attribute(meter, "max", "10");
    try attribute(meter, "value", "20");
    try attribute(meter, "low", "8");
    try attribute(meter, "high", "-8");
    try attribute(meter, "optimum", "-20");
    try expectValues(meter, .{ -10, 10, 10, 8, 8, -10 });
    try attribute(meter, "value", "-20");
    try attribute(meter, "low", "-20");
    try attribute(meter, "high", "20");
    try attribute(meter, "optimum", "20");
    try expectValues(meter, .{ -10, 10, -10, -10, 10, 10 });
    for ([_][]const u8{ "", "garbage", "NaN", "Infinity", "-Infinity", "1e999" }) |invalid| {
        for ([_][]const u8{ "min", "max", "value", "low", "high", "optimum" }) |name| try attribute(meter, name, invalid);
        try expectValues(meter, .{ 0, 1, 0, 0, 1, 0.5 });
    }
    // A finite midpoint must not overflow when both endpoints are large.
    try attribute(meter, "min", "1e308");
    try attribute(meter, "max", "1.6e308");
    try testing.expectApproxEqRel(@as(f64, 1.3e308), try interfaces.HTMLMeterElement.get_optimum(meter), 1e-15);
    try attribute(meter, "min", "-1.6e308");
    try testing.expectEqual(@as(f64, 0), try interfaces.HTMLMeterElement.get_optimum(meter));
    try attribute(meter, "min", "5e-324");
    try attribute(meter, "max", "5e-324");
    try testing.expectEqual(@as(f64, 5e-324), try interfaces.HTMLMeterElement.get_optimum(meter));
}

test "meter getters parse defaults clamp dependent bounds and keep a finite midpoint" {
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
