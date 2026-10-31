//! The cascade's computed-initial fast path (lane cascadefast1).
//!
//! A longhand that no declaration touches takes its default without the
//! per-longhand compute walk: an inherited one stores its parent's computed
//! value, a non-inherited one on the comptime allowlist keeps its shared
//! initial computed value. These tests prove that every such longhand's
//! value equals the slow path's - forced by an `all` declaration, which
//! gives every longhand a candidate - in every element context, and pin
//! the allowlist's default ("compute it").
//!
//! Design: Blink StyleResolver::InitStyle / StyleCascade, WebKit
//! Style::Resolver::initializeStateAndStyle (tmp/plans/cascadefast1-design.md).
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const cascade_mod = css.cascade;
const Longhand = css.properties.Longhand;
const Value = css.style_values.Value;
const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;

fn hasFastPath() bool {
    return @hasDecl(cascade_mod, "DefaultPath") and @hasDecl(cascade_mod, "default_path") and @hasDecl(cascade_mod, "defaultPathFor");
}

fn parse(allocator: Allocator, text: []const u8) !DeclarationBlock {
    return DeclarationBlock.parse(.{ .allocator = allocator }, text);
}

const Counts = struct {
    fn get(_: *anyopaque) css.math_values.TreeCounts {
        return .{ .index = 3, .count = 7 };
    }
};

const Random = struct {
    fn get(_: *anyopaque, _: css.random_values.CacheKey) Allocator.Error!f64 {
        return 0.25;
    }
};

/// One element context in the matrix.
const Case = struct {
    parent_text: ?[]const u8,
    is_root: bool = false,
    pseudo: ?[]const u8 = null,
    page_dark: bool = false,
    preferred_dark: bool = false,
    with_inputs: bool = false,
};

const cases = [_]Case{
    .{ .parent_text = null, .is_root = true },
    .{ .parent_text = null, .is_root = true, .page_dark = true, .preferred_dark = true, .with_inputs = true },
    .{ .parent_text = "" },
    .{ .parent_text = "font-size: 40px; line-height: 3; color: red; writing-mode: vertical-rl; text-orientation: sideways; direction: rtl" },
    .{ .parent_text = "justify-items: legacy center; display: grid; color-scheme: dark; color: CanvasText", .preferred_dark = true },
    .{ .parent_text = "display: contents; font-size: 2em", .pseudo = "before" },
    .{ .parent_text = "display: none", .pseudo = "after", .with_inputs = true },
    .{ .parent_text = "contain: paint; content-visibility: auto; display: inline-flex", .page_dark = true },
};

fn context(allocator: Allocator, case: Case, parent: ?*const ComputedStyle, counts_ctx: *u8) cascade_mod.Context {
    return .{
        .allocator = allocator,
        .parent = parent,
        .is_root = case.is_root,
        .pseudo = case.pseudo,
        .page_color_scheme = if (case.page_dark) .dark else .light,
        .preferred_color_scheme = if (case.preferred_dark) .dark else .light,
        .root_font_size = 20,
        .tree_counts = if (case.with_inputs) .{ .context = counts_ctx, .get = Counts.get } else null,
        .random_base = if (case.with_inputs) .{ .context = counts_ctx, .get = Random.get } else null,
    };
}

/// The style of an element in `case` whose own declarations are `text`
/// (author origin), after an optional low-priority UA block `forced`.
fn styleFor(allocator: Allocator, case: Case, forced: ?[]const u8, text: []const u8) !struct { style: *ComputedStyle, parent: ?*ComputedStyle } {
    var dummy: u8 = 0;
    var parent: ?*ComputedStyle = null;
    errdefer if (parent) |p| p.destroy();
    if (case.parent_text) |pt| {
        var block = try parse(allocator, pt);
        defer block.deinit();
        parent = try cascade_mod.cascade(.{ .allocator = allocator, .parent = null, .is_root = true }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    }
    var own = try parse(allocator, text);
    defer own.deinit();
    var low = try parse(allocator, forced orelse "");
    defer low.deinit();
    const style = try cascade_mod.cascade(context(allocator, case, parent, &dummy), &.{
        .{ .block = &low, .source = .{ .origin = .user_agent, .order = 0 } },
        .{ .block = &own, .source = .{ .origin = .author, .order = 1, .specificity = .{ .b = 1 } } },
    });
    return .{ .style = style, .parent = parent };
}

fn serialize(allocator: Allocator, style: *const ComputedStyle, l: Longhand) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try style.serializeResolved(l, &out, allocator);
    return out.toOwnedSlice(allocator);
}

/// Every longhand whose default takes `path` has the identical computed
/// value (same tag, same payload, same shared reference) in both styles.
fn expectSameDefaults(fast: *const ComputedStyle, slow: *const ComputedStyle, path: anytype, case_index: usize) !void {
    for (0..Longhand.count) |i| {
        if (cascade_mod.default_path[i] != path) continue;
        const l: Longhand = @fromBackingInt(@intCast(i));
        if (!std.meta.eql(fast.get(l), slow.get(l))) {
            std.debug.print("case {d}: {s} differs between the fast and slow default\n", .{ case_index, l.name() });
            return error.FastPathDiffers;
        }
    }
}

test "fast-path defaults equal the slow path's in every element context" {
    if (comptime !hasFastPath()) return error.FastPathNotImplemented;
    const allocator = testing.allocator;
    for (cases, 0..) |case, n| {
        const fast = try styleFor(allocator, case, null, "");
        defer {
            fast.style.destroy();
            if (fast.parent) |p| p.destroy();
        }
        // `all: initial` gives every non-inherited longhand an `initial`
        // candidate: today's compute(.initial) -> computeValue.
        const initial = try styleFor(allocator, case, "all: initial", "");
        defer {
            initial.style.destroy();
            if (initial.parent) |p| p.destroy();
        }
        try expectSameDefaults(fast.style, initial.style, cascade_mod.DefaultPath.initial, n);
        // `all: inherit`: today's compute(.inherit), the root included.
        const inherit = try styleFor(allocator, case, "all: inherit", "");
        defer {
            inherit.style.destroy();
            if (inherit.parent) |p| p.destroy();
        }
        try expectSameDefaults(fast.style, inherit.style, cascade_mod.DefaultPath.inherit, n);
        // `all: unset` is the defaulting step itself, for every longhand.
        const unset = try styleFor(allocator, case, "all: unset", "");
        defer {
            unset.style.destroy();
            if (unset.parent) |p| p.destroy();
        }
        try expectSameDefaults(fast.style, unset.style, cascade_mod.DefaultPath.initial, n);
        try expectSameDefaults(fast.style, unset.style, cascade_mod.DefaultPath.inherit, n);
    }
}

test "authored values read fast-path defaults as the slow path does" {
    if (comptime !hasFastPath()) return error.FastPathNotImplemented;
    const allocator = testing.allocator;
    // Each dependency class: font-relative (em, rem, lh), currentcolor,
    // tree counts, random(), explicit CSS-wide keywords, revert and
    // revert-layer, logical mapping, and the adjustments (blockification,
    // overflow, border widths, containment).
    const authored = [_][]const u8{
        "margin-left: 2em; padding-top: 1rem; text-indent: 1lh; border-top: 2px solid currentcolor; outline: 1px solid",
        "width: calc(sibling-index() * 1px); height: calc(sibling-count() * 2px); opacity: calc(1 / sibling-index())",
        "padding-left: random(1px, 5px); margin-top: random(--x, 1px, 9px)",
        "color: inherit; font-size: initial; visibility: unset; display: revert; float: revert-layer",
        "margin-inline-start: 4px; padding-block: 3px; writing-mode: vertical-lr; direction: rtl",
        "position: absolute; float: left; overflow-x: hidden; display: inline-grid; contain: layout",
        "border-top-style: solid; border-left-width: 9px; background-color: currentcolor; outline-color: Canvas",
        "justify-items: legacy; align-self: flex-start; content: \"x\"",
    };
    for (cases, 0..) |case, n| {
        for (authored) |text| {
            const fast = try styleFor(allocator, case, null, text);
            defer {
                fast.style.destroy();
                if (fast.parent) |p| p.destroy();
            }
            const slow = try styleFor(allocator, case, "all: unset", text);
            defer {
                slow.style.destroy();
                if (slow.parent) |p| p.destroy();
            }
            for (0..Longhand.count) |i| {
                const l: Longhand = @fromBackingInt(@intCast(i));
                const a = try serialize(allocator, fast.style, l);
                defer allocator.free(a);
                const b = try serialize(allocator, slow.style, l);
                defer allocator.free(b);
                if (!std.mem.eql(u8, a, b)) {
                    std.debug.print("case {d} '{s}': {s} fast '{s}' slow '{s}'\n", .{ n, text, l.name(), a, b });
                    return error.FastPathDiffers;
                }
            }
            try testing.expectEqual(fast.style.box_context, slow.style.box_context);
            try testing.expectEqual(fast.style.subgrid_ineligible, slow.style.subgrid_ineligible);
            try testing.expectEqual(fast.style.used_color_scheme, slow.style.used_color_scheme);
        }
    }
}

test "the allowlist's default is to compute" {
    if (comptime !hasFastPath()) return error.FastPathNotImplemented;
    const DefaultPath = cascade_mod.DefaultPath;
    const forFn = cascade_mod.defaultPathFor;
    // Element context the initial value needs: ::before/::after content,
    // and justify-items' legacy, which reads the parent.
    try testing.expectEqual(DefaultPath.compute, cascade_mod.default_path[@backingInt(Longhand.content)]);
    try testing.expectEqual(DefaultPath.compute, cascade_mod.default_path[@backingInt(Longhand.justify_items)]);
    // The high-priority longhands and the logical ones are not in the loop.
    for ([_]Longhand{ .writing_mode, .direction, .text_orientation, .color_scheme, .font_size, .line_height, .color, .margin_inline_start, .block_size }) |l|
        try testing.expectEqual(DefaultPath.compute, cascade_mod.default_path[@backingInt(l)]);
    // Any value outside the proven tag list computes: font-relative and
    // viewport lengths, math, images, transforms, lists.
    try testing.expectEqual(DefaultPath.compute, forFn(.margin_left, .{ .length = .{ .value = 1, .unit = .em } }));
    try testing.expectEqual(DefaultPath.compute, forFn(.margin_left, .{ .length = .{ .value = 1, .unit = .vw } }));
    try testing.expectEqual(DefaultPath.compute, forFn(.margin_left, .{ .length = .{ .value = 1, .unit = .rem } }));
    for ([_][]const u8{
        "width: calc(1px + sibling-index() * 1px)",
        "background-image: linear-gradient(red, blue)",
        "translate: 1px 2px",
        "color: color-mix(in srgb, red, currentcolor)",
        "margin-left: random(1px, 5px)",
    }) |text| {
        var block = try parse(testing.allocator, text);
        defer block.deinit();
        var it = block.typed();
        const d = it.next() orelse {
            std.debug.print("'{s}' did not parse\n", .{text});
            return error.TestDeclarationDidNotParse;
        };
        try testing.expect(d.value == .value);
        try testing.expectEqual(DefaultPath.compute, forFn(.margin_left, d.value.value));
        try testing.expectEqual(DefaultPath.compute, forFn(.background_color, d.value.value));
    }
    // A symbolic currentcolor is proven only outside `color` itself.
    try testing.expectEqual(DefaultPath.initial, forFn(.border_top_color, .{ .color = .current }));
    try testing.expectEqual(DefaultPath.compute, forFn(.color, .{ .color = .current }));
    // Inherited longhands default to their parent's value.
    try testing.expectEqual(DefaultPath.inherit, cascade_mod.default_path[@backingInt(Longhand.visibility)]);
    // Plain absolute values are proven.
    try testing.expectEqual(DefaultPath.initial, forFn(.margin_left, Value.px(0)));
    try testing.expectEqual(DefaultPath.initial, cascade_mod.default_path[@backingInt(Longhand.margin_left)]);
    try testing.expectEqual(DefaultPath.initial, cascade_mod.default_path[@backingInt(Longhand.background_color)]);
}

fn cascadeTree(allocator: Allocator) !void {
    var root_block = try parse(allocator, "font-family: \"A B\", serif; color: red; display: grid");
    defer root_block.deinit();
    const root = try cascade_mod.cascade(.{ .allocator = allocator, .parent = null, .is_root = true }, &.{.{ .block = &root_block, .source = .{ .origin = .author } }});
    defer root.destroy();
    var child_block = try parse(allocator, "margin-left: 2em; background-image: url(x.png)");
    defer child_block.deinit();
    const child = try cascade_mod.cascade(.{ .allocator = allocator, .parent = root }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    const grandchild = try cascade_mod.cascade(.{ .allocator = allocator, .parent = child }, &.{});
    defer grandchild.destroy();
    try testing.expect(std.meta.eql(root.get(.font_family), grandchild.get(.font_family)));
}

test "fast-path defaults leak nothing under every allocation failure" {
    if (comptime !hasFastPath()) return error.FastPathNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, cascadeTree, .{});
}
