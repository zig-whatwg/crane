//! CSS Values 4 sections 9.1 and 10: typed arithmetic, computation and serialization.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(name: []const u8, input: []const u8, specified: []const u8, computed: ?[]const u8) !void {
    const allocator = testing.allocator;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(name, &text);
    try testing.expectEqualStrings(specified, text.items);
    if (computed) |expected| {
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        text.clearRetainingCapacity();
        const longhand = css.properties.lookup(name).?.longhand;
        try css.properties.serializeValue(longhand, style.get(longhand), &text, allocator);
        try testing.expectEqualStrings(expected, text.items);
    }
}

test "math preserves specified wrappers and resolves available computed units" {
    try check("width", "calc(1in + 2px)", "calc(98px)", "98px");
    try check("width", "calc(2em + 3px)", "calc(2em + 3px)", "35px");
    try check("width", "calc((2 + 3) * 4px)", "calc(20px)", "20px");
    try check("width", "calc(calc(2px + 3px) * 4)", "calc(20px)", "20px");
    try check("width", "calc(20px + 100% - 100%)", "calc(0% + 20px)", "calc(0% + 20px)");
}

test "math dimensional algebra checks the unreduced type" {
    try check("width", "calc(10px * 10px / 2px)", "calc(50px)", "50px");
    try check("z-index", "calc(1em / 1px)", "calc(1em / 1px)", "16");
    for ([_][]const u8{ "calc(0 + 1px)", "calc(0 * 1px + 1s)", "calc(1px - 1px + 1s)", "calc(1px * 1px)", "calc(1px / 1s)" }) |value| try check("width", value, "", null);
    try check("opacity", "calc(.25 + 25%)", "", null);
    try check("border-top-width", "calc(1px + 0%)", "", null);
}

test "math comparison functions simplify only comparable values" {
    try check("width", "min(30px, 1in, 10px)", "calc(10px)", "10px");
    try check("width", "max(1em, 10px)", "max(1em, 10px)", "16px");
    try check("width", "min(10px, 3em, 20px)", "min(10px, 3em)", "10px");
    try check("width", "min(10%, 20%)", "min(10%, 20%)", "min(10%, 20%)");
    try check("width", "clamp(100px, 0px, 50px)", "calc(100px)", "100px");
    try check("width", "clamp(none, 10px, none)", "calc(10px)", "10px");
    try check("width", "clamp(none, 1em, 10px)", "min(1em, 10px)", "10px");
    try check("width", "clamp(1px, none, 3px)", "", null);
}

test "math range checks and integer rounding happen at computation" {
    try check("width", "calc(-5px)", "calc(-5px)", "0px");
    try check("margin-left", "calc(-5px)", "calc(-5px)", "-5px");
    try check("opacity", "calc(25%)", "calc(25%)", "0.25");
    try check("opacity", "calc(2)", "calc(2)", "1");
    try check("z-index", "calc(2.5)", "calc(2.5)", "3");
    try check("z-index", "calc(-1.5)", "calc(-1.5)", "-1");
    try check("font-size", "calc(50% + 2px)", "calc(50% + 2px)", "10px");
}

test "math signed zero infinities and NaN stay internal until the outer result" {
    try check("opacity", "calc(0 / 0)", "calc(NaN)", "0");
    try check("opacity", "calc(1 / 0)", "calc(infinity)", "1");
    try check("opacity", "calc(1 / (-5 * 0))", "calc(-infinity)", "0");
    try check("width", "calc(NaN * 1px)", "calc(NaN * 1px)", "0px");
    try check("width", "calc(2 * pi * 1px)", "calc(6.28319px)", "6.28319px");
}

test "math token syntax enforces whitespace and balanced argument grammars" {
    for ([_][]const u8{ "calc(1px+2px)", "calc(1px +2px)", "calc(1px+ 2px)", "calc()", "min()", "min(1px,)", "calc(1px, 2px)", "clamp(1px, 2px)", "calc(foo)", "calc(1px +)", "calc(var(--x))", "calc(env(foo))" }) |value| try check("width", value, "", null);
    try check("width", "CALC( 1PX + 2px )", "calc(3px)", "3px");
}

test "math allocation errors release every partially built expression" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "width: calc((1em + 10%) * 2); height: min(1px, 3em, 10px); margin: max(2px, 1em) calc(100% - 20px);");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try css.properties.serializeValue(.width, style.get(.width), &text, allocator);
    try testing.expectEqualStrings("calc(20% + 32px)", text.items);
}

// Q16: image/background argument grammars must consume typed math before
// lifting their existing rejection. They are outside this scalar batch.
test "opaque image and background grammars retain their existing math rejection" {
    try check("background-image", "linear-gradient(red calc(1px + 2px), blue)", "", null);
    try check("background", "url(a.png) calc(10% + 1px) 0", "", null);
    try check("background", "url(a.png) 0 / calc(10px + 2px) auto", "", null);
}

test "math component values close open functions and parentheses at EOF" {
    try check("width", "calc(1px + 2px", "calc(3px)", "3px");
    try check("width", "calc((1px + 2px", "calc(3px)", "3px");
    try check("width", "min(2px, calc(3px", "calc(2px)", "2px");
    try check("width", "clamp(1px, 2px, 3px", "calc(2px)", "2px");
    for ([_][]const u8{ "calc(1px +", "calc(1px]", "min(1px,", "clamp(1px, 2px" }) |invalid| try check("width", invalid, "", null);
}

test "finite CSS numbers exceeding a small scratch buffer never serialize as zero" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try css.style_values.appendNumber(1e100, &out, testing.allocator);
    try testing.expect(out.items.len > 64);
    const number = try std.fmt.parseFloat(f64, out.items);
    try testing.expectApproxEqRel(@as(f64, 1e100), number, 0.000001);
}

test "border none releases an unresolved computed metric expression when zeroing width" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = std.testing.allocator }, "border-top-width:2cap;border-top-style:none");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = std.testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    try style.serializeResolved(.border_top_width, &out, std.testing.allocator);
    try std.testing.expectEqualStrings("0px", out.items);
}
