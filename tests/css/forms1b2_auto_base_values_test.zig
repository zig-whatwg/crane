//! Lane forms1 batch 2, characterization: what every -internal-auto-base()
//! declaration of the UA sheet (src/dom/style/html.css) gives, in both
//! appearances. It passes before and after the declarations' arguments were
//! parsed eagerly (pending_values.Pending.AutoBase).
//!
//! What it pins is the spec's, not the engine's: Values 5 "replace
//! substitution functions in a property" substitutes the function - its
//! chosen argument's text - and parses the result with the property's
//! grammar, so `P: -internal-auto-base(A, B)` must give exactly what `P: A`
//! gives without base appearance and what `P: B` gives with it, longhand by
//! longhand, CSS-wide keywords (revert-rule's roll-back, inherit, initial)
//! and an argument the grammar rejects (invalid at computed-value time)
//! included. Which argument an element takes is HTML 15.5.16's "rendered
//! with base appearance" (Blink StyleCascade::ResolveAutoBaseInto, WebKit
//! Style::SubstitutionResolver::isBaseAppearance): a select with
//! `appearance: base-select`, its picker when both have it, and what they
//! contain.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Block = css.declarations.DeclarationBlock;
const ComputedStyle = css.computed_style.ComputedStyle;
const Support = css.cascade.AppearanceSupport;

/// html.css's -internal-auto-base() declarations (property, native, base),
/// as written there, and a few shapes it does not have yet.
const declarations = [_][3][]const u8{
    .{ "letter-spacing", "initial", "revert-rule" },
    .{ "word-spacing", "initial", "revert-rule" },
    .{ "line-height", "initial", "revert-rule" },
    .{ "display", "revert-rule", "inline-flex" },
    .{ "background-color", "revert-rule", "transparent" },
    .{ "border", "revert-rule", "1px solid currentColor" },
    .{ "user-select", "revert-rule", "none" },
    .{ "box-sizing", "revert-rule", "border-box" },
    .{ "text-shadow", "revert-rule", "inherit" },
    .{ "background-color", "revert-rule", "color-mix(currentColor 10%, transparent)" },
    .{ "background-color", "revert-rule", "color-mix(currentColor 20%, transparent)" },
    .{ "color", "revert-rule", "color-mix(currentColor 50%, transparent)" },
    .{ "min-inline-size", "revert-rule", "24px" },
    .{ "min-block-size", "revert-rule", "max(24px, 1lh)" },
    .{ "padding-inline", "revert-rule", "0.5em" },
    .{ "padding-block-end", "revert-rule", "0" },
    .{ "display", "revert-rule", "flex" },
    .{ "align-items", "revert-rule", "center" },
    .{ "gap", "revert-rule", "0.5em" },
    .{ "white-space", "revert-rule", "nowrap" },
    .{ "content", "revert-rule", "'\\2713' / ''" },
    .{ "visibility", "revert-rule", "hidden" },
    .{ "font-weight", "revert-rule", "normal" },
    .{ "min-block-size", "revert-rule", "1lh" },
    .{ "border-radius", "revert-rule", "0.5em" },
    .{ "padding-block", "revert-rule", "0.25em" },
    .{ "field-sizing", "revert-rule", "content" },
    .{ "color", "inherit", "CanvasText" },
    .{ "content", "revert-rule", "counter(fake-counter-name, disclosure-open)" },
    .{ "overflow", "revert-rule", "auto" },
    .{ "block-size", "revert-rule", "calc(max(24px, 1lh) * attr(size type(<integer>), 4))" },
    // Shapes html.css does not use: an argument the grammar rejects, unset,
    // a {}-wrapped argument with a comma, a var() in an argument.
    .{ "min-width", "red", "2px" },
    .{ "min-width", "unset", "{3px}" },
    .{ "font-family", "{serif, monospace}", "sans-serif" },
    .{ "min-width", "var(--w, 4px)", "var(--w)" },
};

/// The earlier UA rule each declaration's revert-rule rolls back to: a
/// value for every property above, unlike its initial one.
const earlier_rule =
    "letter-spacing: 3px; word-spacing: 4px; line-height: 30px; display: inline-block; " ++
    "background-color: rgb(1, 2, 3); border: 2px inset rgb(4, 5, 6); user-select: text; " ++
    "box-sizing: content-box; text-shadow: rgb(7, 8, 9) 1px 1px; color: rgb(10, 11, 12); " ++
    "min-inline-size: 5px; min-block-size: 6px; padding: 7px; align-items: end; gap: 9px; " ++
    "white-space: pre; content: 'x'; visibility: collapse; font-weight: 900; border-radius: 3px; " ++
    "field-sizing: fixed; overflow: clip; block-size: 11px; min-width: 12px; font-family: cursive";

const Attributes = struct {
    fn get(_: *const anyopaque, name: []const u8) ?[]const u8 {
        return if (std.mem.eql(u8, name, "size")) "3" else null;
    }
};
const attributes_context: u8 = 0;

/// One element: the earlier UA rule, the declaration under test (UA), an
/// author block. `size="3"` for attr().
fn styleOf(allocator: Allocator, ua: []const u8, author: []const u8, support: Support, parent: ?*const ComputedStyle) !*ComputedStyle {
    var earlier = try Block.parse(.{ .allocator = allocator, .user_agent = true }, earlier_rule);
    defer earlier.deinit();
    var block = try Block.parse(.{ .allocator = allocator, .user_agent = true }, ua);
    defer block.deinit();
    var author_block = try Block.parse(.{ .allocator = allocator }, author);
    defer author_block.deinit();
    return css.cascade.cascade(.{
        .allocator = allocator,
        .parent = parent,
        .appearance_support = support,
        .content_attributes = .{ .context = &attributes_context, .get = Attributes.get },
    }, &.{
        .{ .block = &earlier, .source = .{ .origin = .user_agent, .order = 1 } },
        .{ .block = &block, .source = .{ .origin = .user_agent, .order = 2 } },
        .{ .block = &author_block, .source = .{ .origin = .author, .order = 3 } },
    });
}

fn resolved(allocator: Allocator, style: *const ComputedStyle, l: css.properties.Longhand) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try style.serializeResolved(l, &out, allocator);
    return out.toOwnedSlice(allocator);
}

/// Where an element stands: its own support and author style, and its
/// parent's (a select's, for the elements a select contains).
const Case = struct {
    name: []const u8,
    support: Support,
    author: []const u8,
    /// Null: a root element. Otherwise the parent select's author style.
    parent_select: ?[]const u8,
    base: bool,
};

const cases = [_]Case{
    .{ .name = "a native select", .support = .select, .author = "appearance: auto", .parent_select = "", .base = false },
    .{ .name = "a base-select select", .support = .select, .author = "appearance: base-select", .parent_select = "", .base = true },
    .{ .name = "an option of a native select", .support = .none, .author = "", .parent_select = "appearance: auto", .base = false },
    .{ .name = "an option of a base-select select", .support = .none, .author = "", .parent_select = "appearance: base-select", .base = true },
    .{ .name = "a base-select picker of a native select", .support = .picker, .author = "appearance: base-select", .parent_select = "appearance: auto", .base = false },
    .{ .name = "a base-select picker of a base-select select", .support = .picker, .author = "appearance: base-select", .parent_select = "appearance: base-select", .base = true },
    .{ .name = "an auto picker of a base-select select", .support = .picker, .author = "appearance: auto", .parent_select = "appearance: base-select", .base = false },
    .{ .name = "a root select with base-select", .support = .select, .author = "appearance: base-select", .parent_select = null, .base = true },
};

/// The parent of a case's element: a styled grandparent (inherited values
/// to tell inherit from initial), then the parent select.
const Lineage = struct {
    grandparent: *ComputedStyle,
    select: *ComputedStyle,

    fn init(allocator: Allocator, select_author: []const u8) !Lineage {
        var block = try Block.parse(.{ .allocator = allocator }, "letter-spacing: 13px; word-spacing: 14px; line-height: 40px; " ++
            "text-shadow: rgb(15, 16, 17) 2px 2px; color: rgb(18, 19, 20); font-weight: 300; font-size: 20px; --w: 21px");
        defer block.deinit();
        const grandparent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .is_root = true }, &.{
            .{ .block = &block, .source = .{ .origin = .author, .order = 1 } },
        });
        errdefer grandparent.destroy();
        var author = try Block.parse(.{ .allocator = allocator }, select_author);
        defer author.deinit();
        const select = try css.cascade.cascade(.{ .allocator = allocator, .parent = grandparent, .appearance_support = .select }, &.{
            .{ .block = &author, .source = .{ .origin = .author, .order = 1 } },
        });
        return .{ .grandparent = grandparent, .select = select };
    }

    fn deinit(self: Lineage) void {
        self.select.destroy();
        self.grandparent.destroy();
    }
};

/// Whether `name: value` is a valid declaration (a UA one).
fn parses(allocator: Allocator, name: []const u8, value: []const u8) !bool {
    const text = try std.fmt.allocPrint(allocator, "{s}: {s}", .{ name, value });
    defer allocator.free(text);
    var block = try Block.parse(.{ .allocator = allocator, .user_agent = true }, text);
    defer block.deinit();
    var it = block.typed();
    return it.next() != null;
}

fn checkDeclaration(allocator: Allocator, case: Case, parent: ?*const ComputedStyle, declaration: [3][]const u8) !void {
    const name, const native, const base = declaration;
    const property = css.properties.lookup(name).?;
    const switched = try std.fmt.allocPrint(allocator, "{s}: -internal-auto-base({s}, {s})", .{ name, native, base });
    defer allocator.free(switched);
    // The argument as it would be substituted: a {}-wrapped one unwrapped.
    const argument = if (case.base) base else native;
    const unwrapped = if (argument.len > 1 and argument[0] == '{') argument[1 .. argument.len - 1] else argument;
    // An argument the grammar rejects: substituting it is invalid at
    // computed-value time, which is `unset` (Values 5 "replace substitution
    // functions in a property" step 3; CSS Variables 1 §3.1) - not the same
    // declaration written directly, which parsing drops.
    const direct = if (try parses(allocator, name, unwrapped))
        try std.fmt.allocPrint(allocator, "{s}: {s}", .{ name, unwrapped })
    else
        try std.fmt.allocPrint(allocator, "{s}: unset", .{name});
    defer allocator.free(direct);

    const via_switch = try styleOf(allocator, switched, case.author, case.support, parent);
    defer via_switch.destroy();
    const via_direct = try styleOf(allocator, direct, case.author, case.support, parent);
    defer via_direct.destroy();
    try testing.expectEqual(case.base, via_switch.in_base_appearance);
    const longhands: []const css.properties.Longhand = switch (property) {
        .longhand => |l| &.{l},
        .shorthand => |s| s.longhands(),
    };
    for (longhands) |l| {
        const expected = try resolved(allocator, via_direct, l);
        defer allocator.free(expected);
        const actual = try resolved(allocator, via_switch, l);
        defer allocator.free(actual);
        testing.expectEqualStrings(expected, actual) catch |err| {
            std.debug.print("{s}, `{s}`: {s}\n", .{ case.name, switched, l.name() });
            return err;
        };
    }
}

test "each -internal-auto-base() of the UA sheet gives its chosen argument's values, in both appearances" {
    const allocator = testing.allocator;
    for (cases) |case| {
        const lineage: ?Lineage = if (case.parent_select) |author| try Lineage.init(allocator, author) else null;
        defer if (lineage) |l| l.deinit();
        const parent: ?*const ComputedStyle = if (lineage) |l|
            (if (case.support == .select) l.grandparent else l.select)
        else
            null;
        for (declarations) |declaration| try checkDeclaration(allocator, case, parent, declaration);
    }
}

test "an argument the grammar rejects is invalid at computed-value time, in either appearance" {
    // min-width is not inherited: invalid at computed-value time is unset,
    // its initial value (Values 5 Appendix A; Blink and WebKit fail the
    // substitution the same way).
    const allocator = testing.allocator;
    const lineage = try Lineage.init(allocator, "appearance: base-select");
    defer lineage.deinit();
    for ([_]struct { []const u8, Support, ?*const ComputedStyle }{
        .{ "appearance: auto", .select, lineage.grandparent },
        .{ "appearance: base-select", .select, lineage.grandparent },
        .{ "", .none, lineage.select },
    }) |entry| {
        const author, const support, const parent = entry;
        const style = try styleOf(allocator, "min-width: -internal-auto-base(red, {2px 3px})", author, support, parent);
        defer style.destroy();
        const value = try resolved(allocator, style, .min_width);
        defer allocator.free(value);
        try testing.expectEqualStrings("auto", value);
    }
}

test "revert-rule as the chosen argument rolls back past the whole UA rule" {
    // Cascade 5 7.3.6 (revert-rule): "as if the current style rule had not
    // been present at all" - the earlier UA rule's value, for every
    // longhand of a shorthand.
    const allocator = testing.allocator;
    const lineage = try Lineage.init(allocator, "appearance: auto");
    defer lineage.deinit();
    const style = try styleOf(allocator, "border: -internal-auto-base(revert-rule, 1px solid); gap: -internal-auto-base(revert-rule, 1px)", "appearance: auto", .select, lineage.grandparent);
    defer style.destroy();
    for ([_]struct { css.properties.Longhand, []const u8 }{
        .{ .border_top_width, "2px" },
        .{ .border_left_style, "inset" },
        .{ .border_bottom_color, "rgb(4, 5, 6)" },
        .{ .row_gap, "9px" },
        .{ .column_gap, "9px" },
    }) |entry| {
        const l, const expected = entry;
        const value = try resolved(allocator, style, l);
        defer allocator.free(value);
        try testing.expectEqualStrings(expected, value);
    }
}
