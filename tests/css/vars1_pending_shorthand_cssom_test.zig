//! Pending-substitution values in declaration blocks (lane vars1): the real
//! model of CSS Values 5 Appendix A, "Substitution in Shorthand
//! Properties", which replaced the Q206 interim raw-shorthand seam and its
//! tests (ci1_*substitution*_test.zig). A shorthand with var()/env() sets a
//! pending-substitution value on EACH of its longhands - ordinary typed
//! entries, cascaded like any other - so:
//!
//! - the shorthand reads back its original text while every longhand holds
//!   that same pending value, and "" otherwise; each longhand reads "";
//! - a later declaration of one longhand replaces just that longhand, and
//!   the others stay pending (browsers do this; the seam dropped them all,
//!   Q207 2a);
//! - parsed declarations keep the longhands' priority rule per longhand (an
//!   earlier !important survives a later normal one); setProperty replaces
//!   regardless (CSSOM "set a CSS declaration");
//! - a value whose substitution functions break their argument grammar, or
//!   that holds a bad token, is invalid at parse time and changes nothing.
//!
//! The same scenarios as the seam tests - read-back, replacement, overlap,
//! removal, shadowing, top-level importance, font and font-variant,
//! setCssText, the tokenizer controls, bad tokens - pinned for the real model,
//! each with every allocation failure.
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const Block = css.declarations.DeclarationBlock;

fn options(allocator: Allocator) css.properties.ParseOptions {
    return .{ .allocator = allocator };
}

fn expectValue(allocator: Allocator, block: *const Block, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    testing.expectEqualStrings(expected, out.items) catch |err| {
        std.debug.print("{s}\n", .{name});
        return err;
    };
}

fn expectCssText(allocator: Allocator, block: *const Block, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings(expected, out.items);
}

fn shorthand(name: []const u8) css.properties.Shorthand {
    return css.properties.lookup(name).?.shorthand;
}

/// Every longhand of `name` holds a pending value of that shorthand.
fn expectAllPending(block: *const Block, name: []const u8, important: bool) !void {
    for (shorthand(name).longhands()) |l| {
        const d = block.get(l) orelse return error.TestExpectedPendingLonghand;
        try testing.expect(d.value == .value and d.value.value == .pending);
        try testing.expect(d.value.value.pending.property.? == .shorthand);
        try testing.expectEqual(important, d.important);
    }
}

fn readBack(allocator: Allocator, property: []const u8, function: []const u8, setter: bool, important: bool) !void {
    const source = try std.fmt.allocPrint(allocator, "  {s}  ", .{function});
    defer allocator.free(source);
    var block = if (setter) Block.init(allocator) else blk: {
        const text = try std.fmt.allocPrint(allocator, "{s}: {s}{s};", .{ property, source, if (important) " !important" else "" });
        defer allocator.free(text);
        break :blk try Block.parse(options(allocator), text);
    };
    defer block.deinit();
    if (setter) try testing.expect(try block.setProperty(options(allocator), property, source, if (important) "important" else ""));
    try expectValue(allocator, &block, property, function);
    try testing.expectEqual(important, block.getPropertyPriority(property));
    const css_text = try std.fmt.allocPrint(allocator, "{s}: {s}{s};", .{ property, function, if (important) " !important" else "" });
    defer allocator.free(css_text);
    try expectCssText(allocator, &block, css_text);
    try expectAllPending(&block, property, important);
    for (shorthand(property).longhands()) |l| try expectValue(allocator, &block, l.name(), "");
    try testing.expectEqual(shorthand(property).longhands().len, block.length());
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(allocator);
    try testing.expect(try block.removeProperty(property, &removed));
    try testing.expectEqualStrings(function, removed.items);
    try testing.expectEqual(@as(usize, 0), block.length());
}

test "read-back: margin, background, border and font with var() or env(), parsed or set, normal or important" {
    for ([_][]const u8{ "margin", "background", "border", "font", "font-variant" }) |property| {
        for ([_][]const u8{ "var(--ci1)", "env(ci1)", "var(--a) 1px", "var(--a, {x, y})" }) |function| {
            for ([_]bool{ false, true }) |setter| for ([_]bool{ false, true }) |important| {
                try testing.checkAllAllocationFailures(testing.allocator, readBack, .{ property, function, setter, important });
            };
        }
    }
}

test "a longhand with var() or env() is a pending value too (no longer rejected)" {
    var block = Block.init(testing.allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(options(testing.allocator), "width", "var(--ci1)", ""));
    try testing.expect(try block.setProperty(options(testing.allocator), "height", " env(ci1) ", ""));
    try expectValue(testing.allocator, &block, "width", "var(--ci1)");
    try expectValue(testing.allocator, &block, "height", "env(ci1)");
    // Invalid argument grammar is invalid at parse time.
    try testing.expect(!try block.setProperty(options(testing.allocator), "width", "var()", ""));
    try expectValue(testing.allocator, &block, "width", "var(--ci1)");
}

fn replacement(allocator: Allocator, first: []const u8, second: []const u8, first_important: bool, second_important: bool, setter: bool) !void {
    const text = try std.fmt.allocPrint(allocator, "margin: {s}{s};", .{ first, if (first_important) " !important" else "" });
    defer allocator.free(text);
    var block = try Block.parse(options(allocator), text);
    defer block.deinit();
    if (setter) {
        try testing.expect(try block.setProperty(options(allocator), "margin", second, if (second_important) "important" else ""));
    } else {
        const more = try std.fmt.allocPrint(allocator, "{s} margin: {s}{s};", .{ text, second, if (second_important) " !important" else "" });
        defer allocator.free(more);
        try block.setCssText(options(allocator), more);
    }
    // Parsed: an earlier !important survives a later normal declaration.
    const first_survives = !setter and first_important and !second_important;
    try expectValue(allocator, &block, "margin", if (first_survives) first else second);
    try testing.expectEqual(if (first_survives) true else second_important, block.getPropertyPriority("margin"));
    try expectAllPending(&block, "margin", if (first_survives) true else second_important);
}

test "replacement: parsed obeys importance per longhand, setProperty replaces regardless" {
    for ([_]bool{ false, true }) |a| for ([_]bool{ false, true }) |b| for ([_]bool{ false, true }) |setter| {
        try testing.checkAllAllocationFailures(testing.allocator, replacement, .{ "var(--x)", "env(x)", a, b, setter });
        try testing.checkAllAllocationFailures(testing.allocator, replacement, .{ "env(x)", "var(--x)", a, b, setter });
    };
}

fn longhandAfterShorthand(allocator: Allocator, important: bool, setter: bool) !void {
    const text = try std.fmt.allocPrint(allocator, "margin: var(--m){s};", .{if (important) " !important" else ""});
    defer allocator.free(text);
    var block = try Block.parse(options(allocator), text);
    defer block.deinit();
    if (setter) {
        try testing.expect(try block.setProperty(options(allocator), "margin-top", "1px", ""));
    } else {
        const more = try std.fmt.allocPrint(allocator, "{s} margin-top: 1px;", .{text});
        defer allocator.free(more);
        try block.setCssText(options(allocator), more);
    }
    const replaced = setter or !important;
    try expectValue(allocator, &block, "margin-top", if (replaced) "1px" else "");
    // The other three keep their pending values: no longer the whole entry
    // dropped (Q207 2a).
    try expectValue(allocator, &block, "margin", if (replaced) "" else "var(--m)");
    try testing.expectEqual(@as(usize, 4), block.length());
    for ([_]css.properties.Longhand{ .margin_right, .margin_bottom, .margin_left }) |l| {
        try testing.expect(block.get(l).?.value.value == .pending);
    }
    // CSSOM "serialize a CSS declaration": name, ": ", the value ("" for a
    // longhand a shorthand set), " !important" when important. A parsed
    // declaration moves to the end; setProperty sets in place.
    if (replaced) {
        const rest = if (important)
            "margin-right:  !important; margin-bottom:  !important; margin-left:  !important;"
        else
            "margin-right: ; margin-bottom: ; margin-left: ;";
        const expected = if (setter)
            try std.fmt.allocPrint(allocator, "margin-top: 1px; {s}", .{rest})
        else
            try std.fmt.allocPrint(allocator, "{s} margin-top: 1px;", .{rest});
        defer allocator.free(expected);
        try expectCssText(allocator, &block, expected);
    }
}

test "a longhand after a var() shorthand replaces only itself (variable-cssText.html target9)" {
    for ([_]bool{ false, true }) |important| for ([_]bool{ false, true }) |setter| {
        try testing.checkAllAllocationFailures(testing.allocator, longhandAfterShorthand, .{ important, setter });
    };
}

fn overlap(allocator: Allocator, old_name: []const u8, new_name: []const u8, old_important: bool, new_important: bool) !void {
    const text = try std.fmt.allocPrint(allocator, "{s}: var(--x){s}; {s}: env(x){s};", .{ old_name, if (old_important) " !important" else "", new_name, if (new_important) " !important" else "" });
    defer allocator.free(text);
    var block = try Block.parse(options(allocator), text);
    defer block.deinit();
    const old_survives = old_important and !new_important;
    // The newer shorthand's longhands hold its value unless an important
    // earlier one keeps them; the older shorthand reads "" once any of its
    // longhands changed hands.
    try expectValue(allocator, &block, new_name, if (old_survives) "" else "env(x)");
    try expectValue(allocator, &block, old_name, if (old_survives) "var(--x)" else "");
    const new_longhands = shorthand(new_name).longhands();
    const old_longhands = shorthand(old_name).longhands();
    for (new_longhands) |l| {
        const d = block.get(l).?;
        // Per longhand: the earlier important value survives where it was.
        const from_old = old_survives and std.mem.indexOfScalar(css.properties.Longhand, old_longhands, l) != null;
        try testing.expectEqualStrings(if (from_old) "var(--x)" else "env(x)", d.value.value.pending.text);
    }
}

test "overlap: border and border-color, font and font-variant, in both directions and importances" {
    for ([_][2][]const u8{ .{ "border", "border-color" }, .{ "border-color", "border" }, .{ "font", "font-variant" }, .{ "font-variant", "font" } }) |pair| {
        for ([_]bool{ false, true }) |a| for ([_]bool{ false, true }) |b| {
            try testing.checkAllAllocationFailures(testing.allocator, overlap, .{ pair[0], pair[1], a, b });
        };
    }
}

fn removeConstituent(allocator: Allocator, name: []const u8, longhand: []const u8) !void {
    const text = try std.fmt.allocPrint(allocator, "{s}:   var(--x)   !important;", .{name});
    defer allocator.free(text);
    var block = try Block.parse(options(allocator), text);
    defer block.deinit();
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(allocator);
    try testing.expect(try block.removeProperty(longhand, &removed));
    // A longhand set by a shorthand's pending value reads "".
    try testing.expectEqualStrings("", removed.items);
    // The other longhands stay pending; the shorthand is no longer whole.
    try testing.expectEqual(shorthand(name).longhands().len - 1, block.length());
    try expectValue(allocator, &block, name, "");
}

test "removing one constituent keeps the others pending" {
    try testing.checkAllAllocationFailures(testing.allocator, removeConstituent, .{ "border", "border-top-color" });
    try testing.checkAllAllocationFailures(testing.allocator, removeConstituent, .{ "font", "font-weight" });
    try testing.checkAllAllocationFailures(testing.allocator, removeConstituent, .{ "margin", "margin-left" });
}

fn removeNarrower(allocator: Allocator) !void {
    var block = try Block.parse(options(allocator), "border: var(--x) !important;");
    defer block.deinit();
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(allocator);
    // border-color is not whole: its value reads "" and its longhands go.
    try testing.expect(try block.removeProperty("border-color", &removed));
    try testing.expectEqualStrings("", removed.items);
    try testing.expectEqual(shorthand("border").longhands().len - 4, block.length());
    removed.clearRetainingCapacity();
    try testing.expect(try block.removeProperty("border", &removed));
    try testing.expectEqualStrings("", removed.items);
    try testing.expectEqual(@as(usize, 0), block.length());
}

test "removing a narrower overlapping shorthand, then the rest" {
    try testing.checkAllAllocationFailures(testing.allocator, removeNarrower, .{});
}

fn shadowing(allocator: Allocator, full: bool) !void {
    const text = if (full)
        "margin-top: 1px !important; margin-right: 2px !important; margin-bottom: 3px !important; margin-left: 4px !important; margin: var(--x);"
    else
        "margin-top: 1px !important; margin: var(--x);";
    var block = try Block.parse(options(allocator), text);
    defer block.deinit();
    try expectValue(allocator, &block, "margin-top", "1px");
    try testing.expect(block.getPropertyPriority("margin-top"));
    if (full) {
        // Every longhand kept its important value: the pending one is gone.
        try expectValue(allocator, &block, "margin", "1px 2px 3px 4px");
        try expectCssText(allocator, &block, "margin: 1px 2px 3px 4px !important;");
        try testing.expectEqual(@as(usize, 4), block.length());
    } else {
        try expectValue(allocator, &block, "margin", "");
        try expectCssText(allocator, &block, "margin-top: 1px !important; margin-right: ; margin-bottom: ; margin-left: ;");
        try testing.expectEqual(@as(usize, 4), block.length());
    }
}

test "important typed longhands shadow a later normal pending shorthand, partly or fully" {
    try testing.checkAllAllocationFailures(testing.allocator, shadowing, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, shadowing, .{true});
}

fn topLevelImportant(allocator: Allocator) !void {
    var block = try Block.parse(options(allocator), "margin: var(--x) !important; margin: 1px; margin: env(y);");
    defer block.deinit();
    try expectValue(allocator, &block, "margin", "var(--x)");
    try testing.expect(block.getPropertyPriority("margin"));
    try expectCssText(allocator, &block, "margin: var(--x) !important;");
}

test "a top-level !important pending shorthand survives later normal declarations" {
    try testing.checkAllAllocationFailures(testing.allocator, topLevelImportant, .{});
}

fn setCssTextTransfers(allocator: Allocator, function: []const u8) !void {
    var block = Block.init(allocator);
    defer block.deinit();
    const text = try std.fmt.allocPrint(allocator, "margin: {s}", .{function});
    defer allocator.free(text);
    try block.setCssText(options(allocator), text);
    try expectValue(allocator, &block, "margin", function);
    try testing.expect(try block.setProperty(options(allocator), "margin-top", "2px", ""));
    try expectValue(allocator, &block, "margin", "");
    try block.setCssText(options(allocator), text);
    try expectValue(allocator, &block, "margin", function);
    try testing.expectEqual(@as(usize, 4), block.length());
}

test "setCssText stores pending values and later typed mutation and reuse work" {
    try testing.checkAllAllocationFailures(testing.allocator, setCssTextTransfers, .{"var(--x)"});
    try testing.checkAllAllocationFailures(testing.allocator, setCssTextTransfers, .{"env(x)"});
}

fn tokenizerControls(allocator: Allocator) !void {
    // Functions named in comments or strings are not functions.
    for ([_][]const u8{ "/* var(--x) */ 1px", "/* env(x) */ 1px" }) |value| {
        const input = try std.fmt.allocPrint(allocator, "margin: {s};", .{value});
        defer allocator.free(input);
        var block = try Block.parse(options(allocator), input);
        defer block.deinit();
        try expectValue(allocator, &block, "margin", "1px");
        try testing.expect(block.get(.margin_top).?.value.value != .pending);
    }
    for ([_][]const u8{ "\"var(--x)\"", "\"env(x)\"" }) |value| {
        const input = try std.fmt.allocPrint(allocator, "margin: {s};", .{value});
        defer allocator.free(input);
        var block = try Block.parse(options(allocator), input);
        defer block.deinit();
        try testing.expectEqual(@as(usize, 0), block.length());
    }
    // Escaped and differently cased names are the functions.
    for ([_][]const u8{ "VAR(--x)", "v\\61 r(--x)", "Env(x)" }) |value| {
        const input = try std.fmt.allocPrint(allocator, "margin: {s};", .{value});
        defer allocator.free(input);
        var block = try Block.parse(options(allocator), input);
        defer block.deinit();
        try testing.expect(block.get(.margin_top).?.value.value == .pending);
    }
}

test "the tokenizer recognizes var() and env() function tokens only" {
    try testing.checkAllAllocationFailures(testing.allocator, tokenizerControls, .{});
}

fn badTokens(allocator: Allocator) !void {
    for ([_][]const u8{
        "margin-left: 7px; margin: var(--x) url(a b);",
        "margin-left: 7px; margin: env(x) url(a b);",
        "margin-left: 7px; margin: var(--x) f(\"bad\n);",
        "margin-left: 7px; margin: env(x) f(\"bad\n);",
        "margin-left: 7px; margin: var();",
        "margin-left: 7px; margin: var(--x,!);",
    }) |input| {
        var block = try Block.parse(options(allocator), input);
        defer block.deinit();
        try expectValue(allocator, &block, "margin-left", "7px");
        try testing.expectEqual(@as(usize, 1), block.length());
        try expectValue(allocator, &block, "margin", "");
    }
}

test "a value invalid at parse time changes nothing" {
    try testing.checkAllAllocationFailures(testing.allocator, badTokens, .{});
}
