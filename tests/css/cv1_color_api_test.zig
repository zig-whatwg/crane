//! The Color API owns each retained copy, including copies inside holders.
const std = @import("std");
const css = @import("css");
const values = css.style_values;
const Color = values.Color;
const testing = std.testing;

fn requireApi() !void {
    if (comptime !@hasDecl(Color, "retain") or !@hasDecl(Color, "release") or
        !@hasDecl(Color, "serializeSpecified") or !@hasDecl(Color, "serializeComputed") or
        !@hasDecl(Color, "resolveComputed")) return error.ColorApiNotImplemented;
}

test "a Color holder retains its named value after the source is released" {
    try requireApi();
    if (comptime !@hasDecl(Color, "retain")) return;
    const original: Color = .{ .named = .{ .rgba = values.RgbaColor.black, .name = try values.SharedText.create(testing.allocator, "black") } };
    const held = original;
    held.retain();
    try testing.expectEqual(@as(u32, 2), original.named.name.refs);
    original.release();
    defer held.release();
    try testing.expectEqual(@as(u32, 1), held.named.name.refs);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try held.serializeSpecified(&out, testing.allocator);
    try testing.expectEqualStrings("black", out.items);
}

test "Color computed resolution returns an independent owned result" {
    try requireApi();
    if (comptime !@hasDecl(Color, "resolveComputed")) return;
    const parent: Color = .{ .named = .{ .rgba = values.RgbaColor.black, .name = try values.SharedText.create(testing.allocator, "black") } };
    defer parent.release();
    const inherited = try (@as(Color, .current)).resolveComputed(testing.allocator, .{ .current = parent });
    defer inherited.release();
    try testing.expectEqual(@as(u32, 2), parent.named.name.refs);
    try testing.expect(inherited.eql(parent));
    const computed = try parent.resolveComputed(testing.allocator, .{});
    defer computed.release();
    try testing.expect(computed.eql(Color.black));
    try testing.expectEqual(@as(u32, 2), parent.named.name.refs);
}

test "Color serializers preserve specified keywords and computed channels" {
    try requireApi();
    if (comptime !@hasDecl(Color, "serializeComputed")) return;
    const named: Color = .{ .named = .{ .rgba = values.RgbaColor.black, .name = try values.SharedText.create(testing.allocator, "black") } };
    defer named.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try named.serializeSpecified(&out, testing.allocator);
    try testing.expectEqualStrings("black", out.items);
    out.clearRetainingCapacity();
    try named.serializeComputed(&out, testing.allocator);
    try testing.expectEqualStrings("rgb(0, 0, 0)", out.items);
    out.clearRetainingCapacity();
    try (@as(Color, .current)).serializeComputed(&out, testing.allocator);
    try testing.expectEqualStrings("currentcolor", out.items);
    const system: Color = .{ .system = .canvastext };
    const dark = try system.resolveComputed(testing.allocator, .{ .scheme = .dark });
    defer dark.release();
    try testing.expect(dark.absolute().?.eql((values.RgbaColor{ .r = 255, .g = 255, .b = 255 })));
    try testing.expect((@as(Color, .current)).absolute() == null);
}

test "Color ownership and serialization survive every allocation failure" {
    try requireApi();
    if (comptime !@hasDecl(Color, "retain")) return;
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

test "Color dependency queries default to no tree requirement for every scalar variant" {
    if (comptime !@hasDecl(Color, "needsTreeCounts")) return error.ColorDependencyApiNotImplemented;
    const named: Color = .{ .named = .{ .rgba = values.RgbaColor.black, .name = try values.SharedText.create(testing.allocator, "black") } };
    defer named.release();
    for ([_]Color{ Color.black, .current, named, .{ .system = .canvastext } }) |color| {
        try testing.expect(!color.needsTreeCounts());
    }
}

test "Color dependency queries default to no unavailable metrics for every scalar variant" {
    if (comptime !@hasDecl(Color, "needsUnavailableMetrics")) return error.ColorDependencyApiNotImplemented;
    const named: Color = .{ .named = .{ .rgba = values.RgbaColor.black, .name = try values.SharedText.create(testing.allocator, "black") } };
    defer named.release();
    for ([_]Color{ Color.black, .current, named, .{ .system = .canvastext } }) |color| {
        try testing.expect(!color.needsUnavailableMetrics(false));
        try testing.expect(!color.needsUnavailableMetrics(true));
    }
}

fn allocationFailure(allocator: std.mem.Allocator) anyerror!void {
    const color: Color = .{ .named = .{ .rgba = values.RgbaColor.black, .name = try values.SharedText.create(allocator, "black") } };
    defer color.release();
    color.retain();
    const holder = color;
    defer holder.release();
    const computed = try (@as(Color, .current)).resolveComputed(allocator, .{ .current = holder });
    defer computed.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try computed.serializeSpecified(&out, allocator);
    try computed.serializeComputed(&out, allocator);
    try testing.expectEqualStrings("blackrgb(0, 0, 0)", out.items);
}
