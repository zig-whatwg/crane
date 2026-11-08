//! Lane forms1 batch 2: a UA declaration whose whole value is one
//! -internal-auto-base(<native>, <base>) holds both arguments parsed with
//! the property's grammar from the moment the sheet is built
//! (pending_values.Pending.AutoBase), so the cascade picks one by the
//! element's base appearance without substituting or parsing (batch 1's
//! substitution path cost 200 selects x8.8 in
//! crane/forms1-computed-style-cost.html). WebKit's design: a
//! CSSSubstitutionValue that is one -internal-auto-base() is a "simple
//! reference" whose parsed value Style::SubstitutionResolver reuses by
//! isBaseAppearance(); Crane parses both up front, since the UA sheet is
//! immortal and read by every thread. What the values are is pinned by
//! forms1b2_auto_base_values_test.zig.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Block = css.declarations.DeclarationBlock;
const Pending = css.pending_values.Pending;
const Longhand = css.properties.Longhand;

/// The one Pending every typed declaration of `block` holds.
fn onlyPending(block: *const Block) !*Pending {
    var found: ?*Pending = null;
    var it = block.typed();
    while (it.next()) |d| {
        try testing.expect(d.value == .value and d.value.value == .pending);
        const pending = d.value.value.pending;
        if (found) |f| try testing.expect(f == pending) else found = pending;
    }
    return found orelse error.TestUnexpectedResult;
}

fn expectValue(l: Longhand, assigned: css.properties.Assigned, expected: []const u8) !void {
    try testing.expect(assigned == .value);
    try testing.expect(assigned.value != .pending);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try css.properties.serializeValue(l, assigned.value, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "a UA declaration that is one -internal-auto-base() holds both arguments parsed, for every longhand" {
    var block = try Block.parse(.{ .allocator = testing.allocator, .user_agent = true }, "border: -internal-auto-base(revert-rule, 2px solid currentColor)");
    defer block.deinit();
    const pending = try onlyPending(&block);
    const auto_base = pending.auto_base orelse return error.TestUnexpectedResult;
    for (css.properties.Shorthand.border.longhands()) |l| {
        try testing.expectEqual(css.properties.Assigned{ .css_wide = .revert_rule }, auto_base.select(false, l));
        try testing.expect(auto_base.select(true, l) != .css_wide or auto_base.select(true, l).css_wide == .initial);
    }
    try expectValue(.border_top_width, auto_base.select(true, .border_top_width), "2px");
    try expectValue(.border_left_style, auto_base.select(true, .border_left_style), "solid");
    try expectValue(.border_right_color, auto_base.select(true, .border_right_color), "currentcolor");
}

test "an argument with a substitution function of its own is a pending value" {
    var block = try Block.parse(.{ .allocator = testing.allocator, .user_agent = true }, "block-size: -internal-auto-base(revert-rule, calc(24px * attr(size type(<integer>), 4)))");
    defer block.deinit();
    const auto_base = (try onlyPending(&block)).auto_base orelse return error.TestUnexpectedResult;
    try testing.expectEqual(css.properties.Assigned{ .css_wide = .revert_rule }, auto_base.select(false, .block_size));
    const base = auto_base.select(true, .block_size);
    try testing.expect(base == .value and base.value == .pending);
    try testing.expect(base.value.pending.auto_base == null);
}

test "an argument the property's grammar rejects selects unset" {
    var block = try Block.parse(.{ .allocator = testing.allocator, .user_agent = true }, "min-width: -internal-auto-base(red, 2px)");
    defer block.deinit();
    const auto_base = (try onlyPending(&block)).auto_base orelse return error.TestUnexpectedResult;
    try testing.expect(auto_base.arguments[0] == null);
    try testing.expectEqual(css.properties.Assigned{ .css_wide = .unset }, auto_base.select(false, .min_width));
    try expectValue(.min_width, auto_base.select(true, .min_width), "2px");
}

test "the function anywhere but alone stays a value to substitute, and author style never has it" {
    for ([_][]const u8{
        "min-width: calc(-internal-auto-base(1px, 2px) + 1px)",
        "min-width: -internal-auto-base(1px, 2px) -internal-auto-base(1px, 2px)",
        "min-width: var(--x, -internal-auto-base(1px, 2px))",
    }) |text| {
        var block = try Block.parse(.{ .allocator = testing.allocator, .user_agent = true }, text);
        defer block.deinit();
        const pending = try onlyPending(&block);
        testing.expect(pending.auto_base == null) catch |err| {
            std.debug.print("{s}\n", .{text});
            return err;
        };
    }
    // An author declaration of a custom property keeps it as tokens.
    var author = try Block.parse(.{ .allocator = testing.allocator }, "--x: -internal-auto-base(1px, 2px); min-width: var(--x)");
    defer author.deinit();
    try testing.expect((try onlyPending(&author)).auto_base == null);
}

test "an immortal declaration frees its arguments' text once" {
    // The UA sheet's policy (ua_sheet.makeImmortal): its text values are
    // uncounted, so any thread may copy them into a computed style; the
    // last reference frees each one once, though a shorthand's longhands
    // share a value. The testing allocator sees a leak or a double free.
    var block = try Block.parse(.{ .allocator = testing.allocator, .user_agent = true }, "border: -internal-auto-base(1px solid red, 2px dashed blue); container-name: -internal-auto-base(none, sidebar)");
    defer block.deinit();
    var it = block.typed();
    var texts: usize = 0;
    while (it.next()) |d| {
        const pending = d.value.value.pending;
        pending.makeImmortal();
        const auto_base = pending.auto_base.?;
        for ([_]bool{ false, true }) |base| {
            const assigned = auto_base.select(base, d.longhand);
            if (assigned != .value) continue;
            const text = assigned.value.sharedText() orelse continue;
            try testing.expectEqual(std.math.maxInt(u32), text.refs);
            texts += 1;
        }
    }
    // red and blue (each on four longhands), sidebar.
    try testing.expect(texts >= 3);
}

fn parseAndCascade(allocator: Allocator) !void {
    var block = try Block.parse(.{ .allocator = allocator, .user_agent = true }, "border: -internal-auto-base(revert-rule, 1px solid red); min-width: -internal-auto-base(red, calc(24px * attr(size type(<integer>), 4)))");
    defer block.deinit();
    var author = try Block.parse(.{ .allocator = allocator }, "appearance: base-select");
    defer author.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .appearance_support = .select }, &.{
        .{ .block = &block, .source = .{ .origin = .user_agent, .order = 1 } },
        .{ .block = &author, .source = .{ .origin = .author, .order = 2 } },
    });
    style.destroy();
}

test "parsing both arguments and picking one survive every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, parseAndCascade, .{});
}
