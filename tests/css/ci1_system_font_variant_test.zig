//! CSSOM getPropertyValue steps 1.2.2–1.2.3; Fonts4 §2.7.
//! Q200: tmp/analysis/integrator-probes-1024d (Chrome155/Firefox158/Safari27).
//! Pending longhands and their shorthand follow the coupled CSSOM rule;
//! cssText keeps the separately ruled system-font serialization.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Case = enum { normal_then_menu, caption, weight_override, kerning_override };

fn property(block: *const css.declarations.DeclarationBlock, name: []const u8, expected: []const u8, allocator: Allocator) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn check(allocator: Allocator, case: Case) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    const options = css.properties.ParseOptions{ .allocator = allocator };
    if (case == .normal_then_menu) {
        try testing.expect(try block.setProperty(options, "font-variant", "normal", ""));
        try property(&block, "font-variant", "normal", allocator);
    }
    const keyword = if (case == .normal_then_menu) "menu" else "caption";
    try testing.expect(try block.setProperty(options, "font", keyword, ""));
    if (case == .weight_override)
        try testing.expect(try block.setProperty(options, "font-weight", "700", ""));
    if (case == .kerning_override)
        try testing.expect(try block.setProperty(options, "font-kerning", "none", ""));

    // Check every pending longhand before the shorthand, so the RED locates
    // the getter mismatch independently of the system-font reset behavior.
    for ([_][]const u8{
        "font-variant-ligatures",  "font-variant-caps",     "font-variant-alternates", "font-variant-numeric",
        "font-variant-east-asian", "font-variant-position", "font-variant-emoji",
    }) |name| try property(&block, name, "", allocator);
    try property(&block, "font-variant", "", allocator);
    try property(&block, "FONT-VARIANT", "", allocator);

    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.serialize(&text);
    if (case == .normal_then_menu or case == .caption) {
        const expected = try std.fmt.allocPrint(allocator, "font: {s};", .{keyword});
        defer allocator.free(expected);
        try testing.expectEqualStrings(expected, text.items);
        try property(&block, "font", keyword, allocator);
    } else {
        try testing.expect(std.mem.indexOf(u8, text.items, "font: ") == null);
        try testing.expect(std.mem.indexOf(u8, text.items, "font-style: ;") != null);
        try testing.expect(std.mem.indexOf(u8, text.items, "font-variant: normal;") != null);
        try property(&block, "font", "", allocator);
        try property(&block, if (case == .weight_override) "font-weight" else "font-kerning", if (case == .weight_override) "700" else "none", allocator);
    }

    // Q200 says ANY pending member prevents the getter's serialization.
    try testing.expect(try block.setProperty(options, "font-variant-caps", "small-caps", ""));
    try property(&block, "font-variant-caps", "small-caps", allocator);
    try property(&block, "font-variant", "", allocator);
    // Replacing all pending members restores the ordinary shorthand path.
    try testing.expect(try block.setProperty(options, "font-variant", "normal", ""));
    try property(&block, "font-variant", "normal", allocator);
}

test "system font menu clears a preceding variant shorthand through the public getter" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{Case.normal_then_menu});
}

test "system font caption leaves its variant longhands and getter pending" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{Case.caption});
}

test "system font weight override keeps the pending variant getter distinct from cssText" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{Case.weight_override});
}

test "system font kerning override keeps the pending variant getter distinct from cssText" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{Case.kerning_override});
}
