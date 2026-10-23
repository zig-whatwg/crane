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
        const property = css.properties.lookup(name) orelse return error.MissingGridProperty;
        try css.properties.serializeValue(property.longhand, style.get(property.longhand), &text, allocator);
        try testing.expectEqualStrings(expected, text.items);
    }
}

test "grid track sizes compute typed lengths inside minmax and fit-content" {
    for ([_][]const u8{ "grid-auto-columns", "grid-auto-rows", "grid-template-columns", "grid-template-rows" }) |name| {
        try check(name, "minmax(2em, 1fr) fit-content(calc(10px + 50%))", "minmax(2em, 1fr) fit-content(calc(50% + 10px))", "minmax(32px, 1fr) fit-content(calc(50% + 10px))");
        try check(name, "calc(-2px)", "calc(-2px)", "0px");
        try check(name, "0 0% 0fr min-content max-content auto", "0px 0% 0fr min-content max-content auto", "0px 0% 0fr min-content max-content auto");
        try check(name, "1in 2pt 3mm", "1in 2pt 3mm", "96px 2.66667px 11.3386px");
        try check(name, "calc(1fr + 2fr) minmax(1px, calc(2fr))", "calc(3fr) minmax(1px, calc(2fr))", "3fr minmax(1px, 2fr)");
        for ([_][]const u8{ "-1px", "-1fr", "minmax(1fr, 20px)", "minmax(calc(1fr), 20px)", "fit-content(auto)", "minmax(1px)", "minmax(1px, 2px, 3px)", "1px, 2px" }) |bad| try check(name, bad, "", null);
    }
}

test "grid repeats preserve groups and line names without expanding layout" {
    try check("grid-template-columns", "[] 1em [] repeat(2, [a b] minmax(2em, 3fr) [c]) []", "1em repeat(2, [a b] minmax(2em, 3fr) [c])", "16px repeat(2, [a b] minmax(32px, 3fr) [c])");
    try check("grid-template-rows", "[a] repeat(calc(1 + 1), 10px) [b]", "[a] repeat(calc(2), 10px) [b]", "[a] repeat(2, 10px) [b]");
    for ([_][]const u8{ "[a]", "[auto] 1px", "[span] 1px", "[initial] 1px", "[default] 1px", "[a] [b] 1px", "repeat(0, 1px)", "repeat(2, repeat(2, 1px))", "repeat(auto-fill, 1px) repeat(auto-fit, 2px)", "1fr repeat(auto-fill, 1px)" }) |bad| try check("grid-template-columns", bad, "", null);
    for ([_][]const u8{ "none", "[a] 1px", "repeat(2, 1px)" }) |bad| try check("grid-auto-columns", bad, "", null);
}

test "subgrid keeps empty name sets and finite repeats as specified" {
    try check("grid-template-columns", "subgrid [] [a a] repeat(2, [] [b]) repeat(auto-fill, [c])", "subgrid [] [a a] repeat(2, [] [b]) repeat(auto-fill, [c])", "subgrid [] [a a] repeat(2, [] [b]) repeat(auto-fill, [c])");
    for ([_][]const u8{ "subgrid 1px", "subgrid repeat(auto-fit, [a])", "subgrid repeat(2, 1px)", "subgrid repeat(auto-fill, [a]) repeat(auto-fill, [b])" }) |bad| try check("grid-template-columns", bad, "", null);
}

test "intrinsic auto-repeat preserves computed tracks outside grid lanes" {
    // Q48: Grid 2 §7.2 defines the computed list. CSSWG #10915 is open;
    // tentative nogrid WPT expectations do not establish a none fallback.
    try check("grid-template-columns", "1px repeat(auto-fill, auto fit-content(2em)) 3px", "1px repeat(auto-fill, auto fit-content(2em)) 3px", "1px repeat(auto-fill, auto fit-content(32px)) 3px");
    // Grid 3 §3.1.1 changes the contents of auto-repeat; the surrounding
    // auto-track-list still requires Grid 2 fixed-size tracks (Q38).
    try check("grid-template-columns", "auto repeat(auto-fill, auto) auto", "", null);
}

test "grid areas normalize cells and reject nonrectangular named areas" {
    try check("grid-template-areas", "\"  a a ... \" \"b b .\"", "\"a a .\" \"b b .\"", "\"a a .\" \"b b .\"");
    try check("grid-template-areas", "\"1st 2nd\"", "\"1st 2nd\"", "\"1st 2nd\"");
    for ([_][]const u8{ "\"\"", "\"a b\" \"c\"", "\"a a\" \"a .\"", "\"a . a\"", "\"a / b\"" }) |bad| try check("grid-template-areas", bad, "", null);
}

test "grid-template joins row boundaries and uses shortest shorthand" {
    try check("grid-template", "[a] \"x x\" auto [b] [c] \"y y\" 2em [d] / 1fr 2fr", "[a] \"x x\" [b c] \"y y\" 2em [d] / 1fr 2fr", null);
    try check("grid-template", "none / none", "none", null);
    try check("grid-template", "\"a\" / repeat(2, 1px)", "", null);
    try check("grid-template", "\"a a\" \"a .\"", "", null);
}

test "grid shorthand resets implicit properties while grid-template preserves them" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "grid-auto-rows:2px;grid-auto-columns:3px;grid-auto-flow:column dense;grid-template:1px / 4px");
    defer block.deinit();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try block.getPropertyValue("grid-auto-columns", &text);
    try testing.expectEqualStrings("3px", text.items);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "grid", "dense auto-flow 5px / 6px", "");
    const expected = .{ .{ "grid", "auto-flow dense 5px / 6px" }, .{ "grid-auto-flow", "dense" }, .{ "grid-auto-columns", "auto" }, .{ "grid-auto-rows", "5px" }, .{ "grid-template-rows", "none" }, .{ "grid-template-columns", "6px" }, .{ "grid-template-areas", "none" } };
    inline for (expected) |pair| {
        text.clearRetainingCapacity();
        try block.getPropertyValue(pair[0], &text);
        try testing.expectEqualStrings(pair[1], text.items);
    }
}

test "grid track parse compute shorthand and replacement clean up on allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

test "grid absolute conversion clamps overflow and scalar counts require known metrics" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "grid-auto-rows:1e308em");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    const property = css.properties.lookup("grid-auto-rows") orelse return error.MissingGridProperty;
    try style.serializeResolved(property.longhand, &text, testing.allocator);
    try testing.expect(std.mem.endsWith(u8, text.items, "px"));
    const number = try std.fmt.parseFloat(f64, text.items[0 .. text.items.len - 2]);
    try testing.expect(std.math.isFinite(number) and number > 0);
    for ([_][]const u8{ "repeat(calc(1cap / 1px), 2px)", "calc(1cap / 1px * 1fr)", "calc(1cap / 1cap * 1fr)" }, [_][]const u8{ "none", "none", "1fr" }) |input, expected| {
        var specified = css.declarations.DeclarationBlock.init(testing.allocator);
        defer specified.deinit();
        try testing.expect(try specified.setProperty(.{ .allocator = testing.allocator }, "grid-template-columns", input, ""));
        const computed = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &specified, .source = .{ .origin = .author } }});
        defer computed.destroy();
        const columns = css.properties.lookup("grid-template-columns") orelse return error.MissingGridProperty;
        text.clearRetainingCapacity();
        try computed.serializeResolved(columns.longhand, &text, testing.allocator);
        try testing.expectEqualStrings(expected, text.items);
    }
}

test "fit tolerance keeps symbolic normal and its legacy property alias" {
    try check("fit-tolerance", "normal", "normal", "normal");
    try check("fit-tolerance", "infinite", "infinite", "infinite");
    try check("fit-tolerance", "calc(2em + 10%)", "calc(10% + 2em)", "calc(10% + 32px)");
    try check("flow-tolerance", "2em", "2em", "32px");
    for ([_][]const u8{ "-1px", "auto", "1fr" }) |bad| try check("fit-tolerance", bad, "", null);
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "grid-template:[a] \"x x\" minmax(2em, 1fr) [b] / fit-content(calc(2px + 10%)) 3fr;grid-auto-rows:minmax(1px, 2fr) 3em");
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "grid-template-columns", "[x] repeat(2, minmax(1em, 2fr) [y])", "");
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue("grid-template-columns", &text);
    try testing.expectEqualStrings("[x] repeat(2, minmax(1em, 2fr) [y])", text.items);
}

test "grid shorthands reject trailing tokens after the complete none alternative" {
    for ([_][]const u8{ "grid", "grid-template" }) |property| {
        try check(property, "none none", "", null);
        try check(property, "none []", "", null);
        try check(property, "none / none", "none", null);
    }
}
