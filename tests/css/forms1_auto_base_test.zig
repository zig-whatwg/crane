//! Lane forms1 (C1): the UA style sheet's -internal-auto-base(<native>,
//! <base>) and the inherited in-base-appearance bit. HTML 15.5.16 states the
//! select's base-appearance styles on its COMPUTED appearance; Blink
//! (StyleCascade::ResolveAutoBaseInto, StyleAdjuster's InBaseAppearance) and
//! WebKit (Style::SubstitutionResolver::substituteInternalAutoBaseFunction)
//! write them as this UA-only arbitrary substitution function, chosen after
//! the element's `appearance` is computed. Blink's CSSVariableParser treats
//! it as a function only in kUASheetMode, so author style cannot use it.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Block = css.declarations.DeclarationBlock;
const ComputedStyle = css.computed_style.ComputedStyle;
const Support = css.cascade.AppearanceSupport;

/// One element: a UA block and an author block.
const Element = struct {
    ua: []const u8 = "",
    author: []const u8 = "",
    support: Support = .none,
};

fn styleOf(allocator: Allocator, element: Element, parent: ?*const ComputedStyle) !*ComputedStyle {
    var ua = try Block.parse(.{ .allocator = allocator, .user_agent = true }, element.ua);
    defer ua.deinit();
    var author = try Block.parse(.{ .allocator = allocator }, element.author);
    defer author.deinit();
    return css.cascade.cascade(.{ .allocator = allocator, .parent = parent, .is_root = parent == null, .appearance_support = element.support }, &.{
        .{ .block = &ua, .source = .{ .origin = .user_agent, .order = 1 } },
        .{ .block = &author, .source = .{ .origin = .author, .order = 2 } },
    });
}

fn expectResolved(style: *const ComputedStyle, l: css.properties.Longhand, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(l, &out, testing.allocator);
    testing.expectEqualStrings(expected, out.items) catch |err| {
        std.debug.print("{s}\n", .{l.name()});
        return err;
    };
}

// A non-inherited property no adjustment touches (display would be
// blockified on a root or under a flex container).
const switch_display = "min-width: -internal-auto-base(1px, 2px)";

test "author style cannot use -internal-auto-base()" {
    var block = Block.init(testing.allocator);
    defer block.deinit();
    try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, "display", "-internal-auto-base(inline, block)", ""));
    try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, "border", "-internal-auto-base(revert-rule, 1px solid)", ""));
    // Nor through a custom property: there it is an ordinary function
    // token, and display's grammar rejects the substituted text.
    const style = try styleOf(testing.allocator, .{
        .support = .select,
        .author = "--x: -internal-auto-base(1px, 2px); appearance: base-select; min-width: var(--x)",
    }, null);
    defer style.destroy();
    try expectResolved(style, .min_width, "auto");
}

test "a UA declaration's -internal-auto-base() needs exactly two non-empty arguments" {
    for ([_][]const u8{
        "display: -internal-auto-base(block)",
        "display: -internal-auto-base(block, flex, grid)",
        "display: -internal-auto-base(, flex)",
    }) |text| {
        var block = try Block.parse(.{ .allocator = testing.allocator, .user_agent = true }, text);
        defer block.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.getPropertyValue("display", &out);
        testing.expectEqualStrings("", out.items) catch |err| {
            std.debug.print("{s}\n", .{text});
            return err;
        };
    }
    // A {}-wrapped argument may hold commas (Values 5 §3.1.1).
    const style = try styleOf(testing.allocator, .{ .support = .select, .ua = "font-family: -internal-auto-base({serif, monospace}, sans-serif)" }, null);
    defer style.destroy();
    try expectResolved(style, .font_family, "serif, monospace");
}

test "a select without base appearance takes the native argument" {
    const style = try styleOf(testing.allocator, .{ .support = .select, .ua = "appearance: auto; " ++ switch_display }, null);
    defer style.destroy();
    try expectResolved(style, .min_width, "1px");
    try testing.expect(!style.in_base_appearance);
}

test "a base-select select takes the base argument and is in base appearance" {
    const style = try styleOf(testing.allocator, .{ .support = .select, .ua = "appearance: auto; " ++ switch_display, .author = "appearance: base-select" }, null);
    defer style.destroy();
    try expectResolved(style, .min_width, "2px");
    try expectResolved(style, .appearance, "base-select");
    try testing.expect(style.in_base_appearance);
}

test "base-select on an element that does not support it is not base appearance" {
    const style = try styleOf(testing.allocator, .{ .ua = switch_display, .author = "appearance: base-select" }, null);
    defer style.destroy();
    try expectResolved(style, .min_width, "1px");
    try testing.expect(!style.in_base_appearance);
}

test "the bit is inherited and cleared on a nested select without base appearance" {
    const select = try styleOf(testing.allocator, .{ .support = .select, .author = "appearance: base-select" }, null);
    defer select.destroy();
    const option = try styleOf(testing.allocator, .{ .ua = switch_display }, select);
    defer option.destroy();
    try expectResolved(option, .min_width, "2px");
    try testing.expect(option.in_base_appearance);
    const nested = try styleOf(testing.allocator, .{ .support = .select, .ua = "appearance: auto; " ++ switch_display }, option);
    defer nested.destroy();
    try expectResolved(nested, .min_width, "1px");
    try testing.expect(!nested.in_base_appearance);
    const nested_option = try styleOf(testing.allocator, .{ .ua = switch_display }, nested);
    defer nested_option.destroy();
    try expectResolved(nested_option, .min_width, "1px");
}

test "a picker has base appearance only when its select has it" {
    const native_select = try styleOf(testing.allocator, .{ .support = .select }, null);
    defer native_select.destroy();
    const picker_of_native = try styleOf(testing.allocator, .{ .support = .picker, .ua = switch_display, .author = "appearance: base-select" }, native_select);
    defer picker_of_native.destroy();
    try expectResolved(picker_of_native, .min_width, "1px");
    try testing.expect(!picker_of_native.in_base_appearance);

    const base_select = try styleOf(testing.allocator, .{ .support = .select, .author = "appearance: base-select" }, null);
    defer base_select.destroy();
    const auto_picker = try styleOf(testing.allocator, .{ .support = .picker, .ua = switch_display }, base_select);
    defer auto_picker.destroy();
    try expectResolved(auto_picker, .min_width, "1px");
    try testing.expect(!auto_picker.in_base_appearance);
    const base_picker = try styleOf(testing.allocator, .{ .support = .picker, .ua = switch_display, .author = "appearance: base-select" }, base_select);
    defer base_picker.destroy();
    try expectResolved(base_picker, .min_width, "2px");
    try testing.expect(base_picker.in_base_appearance);
}

test "an appearance that asks for its own base appearance is invalid at computed-value time" {
    // Blink's DetectCycle: the substitution fails; appearance takes its
    // initial value and the element has no base appearance.
    const style = try styleOf(testing.allocator, .{ .support = .select, .ua = "appearance: -internal-auto-base(base-select, auto); " ++ switch_display }, null);
    defer style.destroy();
    try expectResolved(style, .appearance, "none");
    try expectResolved(style, .min_width, "1px");
    try testing.expect(!style.in_base_appearance);
}

test "revert-rule as the chosen argument rolls back to the UA rule before it" {
    var earlier = try Block.parse(.{ .allocator = testing.allocator, .user_agent = true }, "display: inline-block; letter-spacing: 3px");
    defer earlier.deinit();
    var later = try Block.parse(.{ .allocator = testing.allocator, .user_agent = true }, "display: -internal-auto-base(revert-rule, inline-flex); letter-spacing: -internal-auto-base(revert-rule, inherit)");
    defer later.deinit();
    var author = try Block.parse(.{ .allocator = testing.allocator }, "appearance: base-select");
    defer author.deinit();
    const parent = try styleOf(testing.allocator, .{ .author = "letter-spacing: 7px" }, null);
    defer parent.destroy();
    const native = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent, .appearance_support = .select }, &.{
        .{ .block = &earlier, .source = .{ .origin = .user_agent, .order = 1 } },
        .{ .block = &later, .source = .{ .origin = .user_agent, .order = 2 } },
    });
    defer native.destroy();
    try expectResolved(native, .display, "inline-block");
    try expectResolved(native, .letter_spacing, "3px");
    const base = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent, .appearance_support = .select }, &.{
        .{ .block = &earlier, .source = .{ .origin = .user_agent, .order = 1 } },
        .{ .block = &later, .source = .{ .origin = .user_agent, .order = 2 } },
        .{ .block = &author, .source = .{ .origin = .author, .order = 3 } },
    });
    defer base.destroy();
    try expectResolved(base, .display, "inline-flex");
    try expectResolved(base, .letter_spacing, "7px");
}

test "an element whose declarations use no -internal-auto-base() never resolves appearance early" {
    // The cost condition (integrator, 2026-11-07): pages without a select
    // pay nothing. A plain element's cascade still computes appearance in
    // its ordinary place, once.
    const style = try styleOf(testing.allocator, .{ .ua = "display: block", .author = "appearance: base-select" }, null);
    defer style.destroy();
    try expectResolved(style, .appearance, "base-select");
    try expectResolved(style, .display, "block");
    try testing.expect(!style.in_base_appearance);
}
