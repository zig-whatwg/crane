//! CSS Text4 §§4.4, 5.4–5.5, 6.3 and 8.1; Text5 §2.
const std = @import("std");
const css = @import("css");

fn check(allocator: std.mem.Allocator, name: []const u8, input: []const u8, specified: []const u8, computed: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingTextProperty;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "font-size", "20px", "");
    _ = try block.setProperty(.{ .allocator = allocator }, name, input, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try std.testing.expectEqualStrings(specified, out.items);
    if (specified.len == 0) return;
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:10px");
    defer child_block.deinit();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    for ([_]*const css.computed_style.ComputedStyle{ parent, child }) |style| {
        out.clearRetainingCapacity();
        switch (property) {
            .longhand => |l| try style.serializeResolved(l, &out, allocator),
            .shorthand => |s| {
                var assigned: [css.properties.Longhand.count]css.properties.Assigned = undefined;
                const ls = s.longhands();
                for (ls, 0..) |l, i| assigned[i] = .{ .value = style.get(l) };
                try std.testing.expect(try css.properties.serializeShorthand(s, assigned[0..ls.len], .computed, &out, allocator));
            },
        }
        try std.testing.expectEqualStrings(computed, out.items);
    }
}

test "text strings, integer limits, tab dimensions and spacing compute before inheritance" {
    const cases = .{
        .{ "hyphenate-character", "'\\1400'", "\"᐀\"", "\"᐀\"" },
        .{ "hyphenate-character", "\"\"", "\"\"", "\"\"" },
        .{ "hyphenate-character", "auto", "auto", "auto" },
        .{ "hyphenate-limit-chars", "auto auto auto", "auto", "auto" },
        .{ "hyphenate-limit-chars", "5 2 2", "5 2", "5 2" },
        .{ "hyphenate-limit-chars", "0 auto 2", "0 auto 2", "0 auto 2" },
        .{ "hyphenate-limit-chars", "5 calc(2.1) 3", "5 calc(2.1) 3", "5 2 3" },
        .{ "tab-size", "0", "0", "0" },
        .{ "tab-size", "2.5", "2.5", "2.5" },
        .{ "tab-size", "2em", "2em", "40px" },
        .{ "tab-size", "calc(10px - 2em)", "calc(-2em + 10px)", "0px" },
        .{ "word-spacing", "normal", "normal", "0px" },
        .{ "word-spacing", "-2em", "-2em", "-40px" },
        .{ "word-spacing", "-20%", "-20%", "-20%" },
        .{ "text-fit", "grow consistent 150%", "grow consistent 150%", "grow 150%" },
        .{ "text-fit", "shrink per-line-all", "shrink per-line-all", "shrink per-line-all" },
        .{ "text-wrap", "stable nowrap", "nowrap stable", "nowrap stable" },
        .{ "text-wrap", "auto", "wrap", "wrap" },
        .{ "text-wrap", "wrap pretty", "pretty", "pretty" },
        .{ "text-justify", "distribute", "inter-character", "inter-character" },
    };
    inline for (cases) |row| try check(std.testing.allocator, row[0], row[1], row[2], row[3]);
}

test "text value grammars reject extra components, wrong dimensions and literal ranges" {
    const cases = .{
        .{ "hyphenate-character", "\"a\" \"b\"" },
        .{ "hyphenate-limit-chars", "1.5" },
        .{ "hyphenate-limit-chars", "-1" },
        .{ "hyphenate-limit-chars", "1 2 3 4" },
        .{ "tab-size", "-1" },
        .{ "tab-size", "-1px" },
        .{ "tab-size", "calc(10% + 2px)" },
        .{ "word-spacing", "auto" },
        .{ "text-fit", "grow 150% consistent" },
        .{ "text-fit", "none 100%" },
        .{ "text-wrap", "wrap nowrap" },
        .{ "text-wrap", "pretty stable" },
        .{ "text-justify", "inter-word inter-character" },
    };
    inline for (cases) |row| try check(std.testing.allocator, row[0], row[1], "", "");
}

test "text nested values survive every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "hyphenate-limit-chars", "5 calc(2.1) 3", "5 calc(2.1) 3", "5 2 3" });
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "hyphenate-character", "'\\1400'", "\"᐀\"", "\"᐀\"" });
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "text-fit", "grow consistent 150%", "grow consistent 150%", "grow 150%" });
}

test "text spacing canonicalizes unordered components and shorthand defaults" {
    const cases = .{
        .{ "hyphenate-limit-lines", "calc(2.1)", "calc(2.1)", "2" },
        .{ "hyphenate-limit-lines", "no-limit", "no-limit", "no-limit" },
        .{ "text-autospace", "replace punctuation ideograph-numeric ideograph-alpha", "ideograph-alpha ideograph-numeric punctuation replace", "ideograph-alpha ideograph-numeric punctuation replace" },
        .{ "text-autospace", "insert", "insert", "insert" },
        .{ "text-autospace", "normal", "normal", "normal" },
        .{ "text-spacing-trim", "trim-both", "trim-both", "trim-both" },
        .{ "text-spacing", "no-autospace space-all", "none", "none" },
        .{ "text-spacing", "normal normal", "normal", "normal" },
        .{ "text-spacing", "normal trim-start", "trim-start", "trim-start" },
        .{ "text-spacing", "insert ideograph-alpha trim-all", "trim-all ideograph-alpha insert", "trim-all ideograph-alpha insert" },
        .{ "text-spacing", "auto", "auto", "auto" },
        .{ "word-space-transform", "auto-phrase ideographic-space", "ideographic-space auto-phrase", "ideographic-space auto-phrase" },
    };
    inline for (cases) |row| try check(std.testing.allocator, row[0], row[1], row[2], row[3]);
    const invalid = .{
        .{ "hyphenate-limit-lines", "-1" },
        .{ "hyphenate-limit-lines", "no-limit 2" },
        .{ "text-autospace", "insert replace" },
        .{ "text-autospace", "punctuation punctuation" },
        .{ "text-autospace", "normal insert" },
        .{ "text-spacing-trim", "normal trim-all" },
        .{ "text-spacing", "auto normal" },
        .{ "text-spacing", "normal normal no-autospace" },
        .{ "text-spacing", "none no-autospace" },
        .{ "text-spacing", "trim-start punctuation punctuation" },
        .{ "text-spacing", "normal insert replace" },
        .{ "word-space-transform", "auto-phrase" },
        .{ "word-space-transform", "none auto-phrase" },
        .{ "word-space-transform", "space ideographic-space" },
    };
    inline for (invalid) |row| try check(std.testing.allocator, row[0], row[1], "", "");
}

test "text group alignment does not inherit; spacing uses spec initial values" {
    const allocator = std.testing.allocator;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "text-group-align:center");
    defer block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    try std.testing.expectEqual(css.style_values.Keyword.center, parent.keyword(.text_group_align));
    try std.testing.expectEqual(css.style_values.Keyword.none, child.keyword(.text_group_align));
    try std.testing.expectEqual(css.style_values.Keyword.normal, child.keyword(.text_autospace));
    try std.testing.expectEqual(css.style_values.Keyword.normal, child.keyword(.text_spacing_trim));
}

test "text spacing nested parsing and canonicalization survive every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "text-spacing", "insert ideograph-alpha trim-all", "trim-all ideograph-alpha insert", "trim-all ideograph-alpha insert" });
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "text-autospace", "replace punctuation ideograph-numeric ideograph-alpha", "ideograph-alpha ideograph-numeric punctuation replace", "ideograph-alpha ideograph-numeric punctuation replace" });
}

test "hanging punctuation preserves specified order and canonicalizes before inheritance" {
    try check(std.testing.allocator, "hanging-punctuation", "last first force-end", "last first force-end", "first force-end last");
    try check(std.testing.allocator, "hanging-punctuation", "last allow-end", "last allow-end", "allow-end last");
    try check(std.testing.allocator, "hanging-punctuation", "none", "none", "none");
    try check(std.testing.allocator, "hanging-punctuation", "first allow-end force-end", "", "");
    try check(std.testing.allocator, "hanging-punctuation", "first first", "", "");
    try std.testing.checkAllAllocationFailures(std.testing.allocator, check, .{ "hanging-punctuation", "last first force-end", "last first force-end", "first force-end last" });
}

test "text fitting rejects negative literals but clamps negative calculations" {
    try check(std.testing.allocator, "text-fit", "grow -20%", "", "");
    try check(std.testing.allocator, "text-fit", "grow calc(-20%)", "grow calc(-20%)", "grow 0%");
}

test "white-space keeps its two-longhand CSSOM expansion and legacy forms" {
    const allocator = std.testing.allocator;
    inline for (.{ "normal", "pre", "pre-wrap", "pre-line", "nowrap", "break-spaces" }) |input| {
        try check(allocator, "white-space", input, input, input);
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        _ = try block.setProperty(.{ .allocator = allocator }, "white-space", input, "");
        try std.testing.expectEqual(@as(usize, 2), block.length());
        try std.testing.expectEqualStrings("white-space-collapse", block.item(0).?);
        try std.testing.expectEqualStrings("text-wrap-mode", block.item(1).?);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try std.testing.expect(try block.removeProperty("white-space", &out));
        try std.testing.expectEqualStrings(input, out.items);
        try std.testing.expectEqual(@as(usize, 0), block.length());
    }
}

fn checkWhitespaceTrim(allocator: std.mem.Allocator) !void {
    const property = css.properties.lookup("white-space-trim") orelse return error.MissingTextProperty;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "white-space-trim", "discard-inner discard-before discard-after", "");
    _ = try block.setProperty(.{ .allocator = allocator }, "white-space", "normal", "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("white-space-trim", &out);
    try std.testing.expectEqualStrings("discard-before discard-after discard-inner", out.items);
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    out.clearRetainingCapacity();
    try child.serializeResolved(property.longhand, &out, allocator);
    try std.testing.expectEqualStrings("none", out.items);
    try check(allocator, "white-space-trim", "discard-before discard-before", "", "");
    try check(allocator, "white-space-trim", "none discard-inner", "", "");
}

test "white-space trim is an independent noninherited unordered longhand" {
    try checkWhitespaceTrim(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkWhitespaceTrim, .{});
}

test "text integer representation limits clamp instead of rejecting valid large literals" {
    try check(std.testing.allocator, "hyphenate-limit-lines", "999999999999999999999999999999999999", "2147483647", "2147483647");
    try check(std.testing.allocator, "hyphenate-limit-chars", "999999999999999999999999999999999999 2", "2147483647 2", "2147483647 2");
    try check(std.testing.allocator, "hyphenate-limit-lines", "calc(2147483648)", "calc(2147483648)", "2147483647");
}

fn checkAlignment(allocator: std.mem.Allocator, name: []const u8, parent_css: []const u8, expected: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingTextProperty;
    var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, parent_css);
    defer parent_block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "direction:ltr");
    defer child_block.deinit();
    _ = try child_block.setProperty(.{ .allocator = allocator }, name, "match-parent", "");
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    var grandchild_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "direction:rtl");
    defer grandchild_block.deinit();
    const grandchild = try css.cascade.cascade(.{ .allocator = allocator, .parent = child }, &.{.{ .block = &grandchild_block, .source = .{ .origin = .author } }});
    defer grandchild.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    for ([_]*const css.computed_style.ComputedStyle{ child, grandchild }) |style| {
        out.clearRetainingCapacity();
        try style.serializeResolved(property.longhand, &out, allocator);
        try std.testing.expectEqualStrings(expected, out.items);
    }
}

test "text alignment resolves match-parent once against the parent's direction" {
    const allocator = std.testing.allocator;
    inline for (.{ "text-align", "text-align-last" }) |name| {
        try check(allocator, name, "match-parent", "match-parent", "start");
        try checkAlignment(allocator, name, "direction:rtl;text-align:start;text-align-last:start", "right");
        try checkAlignment(allocator, name, "direction:rtl;text-align:end;text-align-last:end", "left");
        try checkAlignment(allocator, name, "direction:ltr;text-align:end;text-align-last:end", "right");
        try checkAlignment(allocator, name, "text-align:center;text-align-last:center", "center");
        try check(allocator, name, "start end", "", "");
    }
    try checkAlignment(allocator, "text-align-last", "", "auto");
    try std.testing.checkAllAllocationFailures(allocator, checkAlignment, .{ "text-align", "direction:rtl;text-align:start", "right" });
}

test "text-align and text-align-last remain independent CSSOM longhands" {
    const allocator = std.testing.allocator;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "text-align-last", "justify", "");
    _ = try block.setProperty(.{ .allocator = allocator }, "text-align", "center", "");
    try std.testing.expectEqual(@as(usize, 2), block.length());
    try std.testing.expectEqualStrings("text-align-last", block.item(0).?);
    try std.testing.expectEqualStrings("text-align", block.item(1).?);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("text-align-last", &out);
    try std.testing.expectEqualStrings("justify", out.items);
    out.clearRetainingCapacity();
    try std.testing.expect(try block.removeProperty("text-align", &out));
    try std.testing.expectEqualStrings("center", out.items);
    try std.testing.expectEqual(@as(usize, 1), block.length());
    try check(allocator, "text-align", "auto", "", "");
    try check(allocator, "text-align-last", "none", "", "");
}

test "root match-parent uses start even with a supplied initial parent style" {
    const allocator = std.testing.allocator;
    const parent = try css.computed_style.ComputedStyle.initial(allocator);
    defer parent.destroy();
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "text-align:match-parent;text-align-last:match-parent");
    defer block.deinit();
    const root = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent, .is_root = true }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer root.destroy();
    inline for (.{ "text-align", "text-align-last" }) |name| {
        const property = css.properties.lookup(name) orelse return error.MissingTextProperty;
        try std.testing.expectEqual(css.style_values.Keyword.start, root.keyword(property.longhand));
    }
}
