//! Row124 properties at the CSS Pseudo4 first-line/first-letter boundary.
//! Q28-Q30: property applicability follows the shipping browsers, with the
//! specification breaking ties between browsers that ship the property.
const std = @import("std");
const css = @import("css");

fn check(allocator: std.mem.Allocator, pseudo: []const u8, name: []const u8, input: []const u8, expected: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingProperty;
    var origin_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:20px;color:blue");
    defer origin_block.deinit();
    const origin = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .is_root = true }, &.{.{ .block = &origin_block, .source = .{ .origin = .author } }});
    defer origin.destroy();
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = origin, .pseudo = pseudo }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    switch (property) {
        .longhand => |longhand| try style.serializeResolved(longhand, &out, allocator),
        .shorthand => |shorthand| {
            var assigned: [3]css.properties.Assigned = undefined;
            for (shorthand.longhands(), 0..) |longhand, i| assigned[i] = .{ .value = style.get(longhand) };
            try std.testing.expect(try css.properties.serializeShorthand(shorthand, assigned[0..shorthand.longhands().len], .computed, &out, allocator));
        },
    }
    try std.testing.expectEqualStrings(expected, out.items);
}

test "text properties apply to both typographic pseudos under the shipping and spec rules" {
    const cases = .{
        .{ "word-spacing", "12px", "12px" },
        .{ "text-justify", "inter-word", "inter-word" },
        .{ "hyphenate-character", "\"X\"", "\"X\"" },
        .{ "hyphenate-limit-chars", "7 3 4", "7 3 4" },
        .{ "hanging-punctuation", "first", "first" },
        .{ "text-autospace", "ideograph-alpha", "ideograph-alpha" },
        .{ "text-autospace", "ideograph-numeric", "ideograph-numeric" },
    };
    inline for (.{ "first-line", "first-letter" }) |pseudo| {
        inline for (cases) |row| try check(std.testing.allocator, pseudo, row[0], row[1], row[2]);
    }
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "first-line", "hyphenate-character", "\"X\"", "\"X\"" });
}

test "decoration properties apply to both typographic pseudos and compute in their font context" {
    const cases = .{
        .{ "text-decoration-line", "overline", "overline" },
        .{ "text-decoration-style", "wavy", "wavy" },
        .{ "text-decoration-color", "red", "rgb(255, 0, 0)" },
        .{ "text-decoration-thickness", "2em", "40px" },
        .{ "text-decoration-inset", "2em 1em", "40px 20px" },
        .{ "text-decoration-skip-ink", "none", "none" },
        .{ "text-decoration-skip-spaces", "none", "none" },
        .{ "text-underline-position", "under", "under" },
        .{ "text-underline-offset", "2em", "40px" },
        .{ "text-shadow", "red 1em 2px 3px", "rgb(255, 0, 0) 20px 2px 3px" },
    };
    inline for (.{ "first-line", "first-letter" }) |pseudo| {
        inline for (cases) |row| try check(std.testing.allocator, pseudo, row[0], row[1], row[2]);
    }
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "first-letter", "text-shadow", "red 1em 2px 3px", "rgb(255, 0, 0) 20px 2px 3px" });
}

test "vertical alignment keeps its constituents applicable to both typographic pseudos" {
    const cases = .{
        .{ "alignment-baseline", "middle", "middle" },
        .{ "baseline-shift", "1em", "20px" },
        .{ "baseline-source", "last", "last" },
        .{ "vertical-align", "last middle 1em", "last middle 20px" },
    };
    inline for (.{ "first-line", "first-letter" }) |pseudo| {
        inline for (cases) |row| try check(std.testing.allocator, pseudo, row[0], row[1], row[2]);
    }
}

test "initial-letter applies only to first-letter" {
    try check(std.testing.allocator, "first-letter", "initial-letter", "3", "3");
    try check(std.testing.allocator, "first-line", "initial-letter", "3", "normal");
}

test "filtered text decoration and inline properties retain inherited or initial values" {
    const cases = .{
        .{ "hyphens", "auto", "manual" },
        .{ "line-break", "strict", "auto" },
        .{ "overflow-wrap", "anywhere", "normal" },
        .{ "tab-size", "3", "8" },
        .{ "text-align", "right", "start" },
        .{ "text-align-last", "right", "auto" },
        .{ "text-indent", "12px", "0px" },
        .{ "text-wrap-mode", "nowrap", "wrap" },
        .{ "text-wrap-style", "balance", "auto" },
        .{ "white-space-collapse", "preserve", "collapse" },
        .{ "word-break", "break-all", "normal" },
        .{ "text-fit", "grow", "none" },
        .{ "text-emphasis-style", "open circle", "none" },
        .{ "text-emphasis-color", "red", "rgb(0, 0, 255)" },
        .{ "text-emphasis-position", "under left", "over" },
        .{ "dominant-baseline", "middle", "auto" },
        .{ "text-box-edge", "cap alphabetic", "auto" },
        .{ "text-box-trim", "trim-both", "none" },
        .{ "hyphenate-limit-lines", "3", "no-limit" },
        .{ "text-group-align", "center", "none" },
        .{ "text-spacing-trim", "trim-all", "normal" },
        .{ "white-space-trim", "discard-before", "none" },
        .{ "word-space-transform", "ideographic-space", "none" },
    };
    inline for (.{ "first-line", "first-letter" }) |pseudo| {
        inline for (cases) |row| try check(std.testing.allocator, pseudo, row[0], row[1], row[2]);
    }
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "first-line", "text-emphasis-style", "open circle", "none" });
}
