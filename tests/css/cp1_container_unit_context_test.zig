//! Conditional 5 §7 and Q95–98: synchronous unavailable-container notes.
const std = @import("std");
const css = @import("css");
const math = css.math_values;
const a = std.testing.allocator;

test "cp1 legacy length literal conversions accept every reachable math unit" {
    inline for (std.meta.fields(math.Unit)) |field| {
        const unit: math.Unit = @enumFromInt(field.value);
        if (unit.base() == .length) {
            var stream = css.properties.Stream.init(comptime "1" ++ unit.name());
            const number = (try css.numeric_values.Number.consume(.{ .allocator = a }, &stream, .{ .kind = .length }, false)) orelse return error.MissingUnit;
            defer number.unref();
            switch (number) {
                .literal => |n| try std.testing.expect(css.style_values.LengthUnit.fromString(n.unit.name()) != null),
                .calculation => {},
            }
        }
    }
}

const Probe = struct {
    width: bool = true,
    height: bool = true,
    calls: usize = 0,

    fn get(raw: *anyopaque, axis: math.Context.ContainerAxis) math.Context.ContainerEligibility {
        const self: *Probe = @ptrCast(@alignCast(raw));
        self.calls += 1;
        const eligible = switch (axis) {
            .width => self.width,
            .height => self.height,
            else => unreachable, // Context maps logical to physical axes.
        };
        return if (eligible) .eligible_geometry_unavailable else .no_eligible_container;
    }

    fn input(self: *Probe, note: *math.UnavailableNote) math.ContainerInput {
        return .{ .context = self, .get = get, .note = note };
    }
};

test "cp1 null container default preserves every viewport fallback" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    const context: math.Context = .{ .viewport_width = 800, .viewport_height = 600 };
    try std.testing.expect(context.container == null);
    inline for (.{ .width, .height, .inline_axis, .block_axis }) |axis|
        try std.testing.expectEqual(.no_eligible_container, context.containerEligibility(axis));
    inline for (.{ .{ .cqw, 8.0 }, .{ .cqh, 6.0 }, .{ .cqi, 8.0 }, .{ .cqb, 6.0 }, .{ .cqmin, 6.0 }, .{ .cqmax, 8.0 } }) |row| {
        const result = context.resolve(.{ .value = 1, .unit = row[0] });
        try std.testing.expectEqual(math.Unit.px, result.unit);
        try std.testing.expectEqual(@as(f64, row[1]), result.value);
    }
}

test "cp1 ordinary numeric values never call the container provider" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    var note: math.UnavailableNote = .{};
    var probe: Probe = .{};
    const context: math.Context = .{ .container = probe.input(&note) };
    inline for (.{ .px, .em, .svw, .s, .deg, .number, .percent }) |unit|
        _ = context.resolve(.{ .value = 2, .unit = unit });
    const parsed = (try math.parse(a, "calc(1em + 2px)", .{ .kind = .length })) orelse return error.Parse;
    defer parsed.expression.unref();
    const computed = try parsed.expression.compute(a, context);
    defer computed.unref();
    try std.testing.expectEqual(@as(usize, 0), probe.calls);
    try std.testing.expect(!note.retained_length and !note.scalar);
}

test "cp1 per-axis provider retains only unavailable axes and logical minmax" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    var note: math.UnavailableNote = .{};
    var probe: Probe = .{ .height = false };
    const context: math.Context = .{ .container = probe.input(&note), .viewport_vertical = true, .viewport_width = 800, .viewport_height = 600 };
    inline for (.{ .cqw, .cqb, .cqmin, .cqmax }) |unit| {
        note = .{};
        const n = context.resolve(.{ .value = 2, .unit = unit });
        try std.testing.expectEqual(unit, n.unit);
        try std.testing.expectEqual(@as(f64, 2), n.value);
        try std.testing.expect(note.retained_length and !note.scalar);
    }
    inline for (.{ .cqh, .cqi }) |unit| {
        note = .{};
        const n = context.resolve(.{ .value = 2, .unit = unit });
        try std.testing.expectEqual(math.Unit.px, n.unit);
        try std.testing.expectEqual(@as(f64, 12), n.value);
        try std.testing.expect(!note.retained_length and !note.scalar);
    }
}

fn lengthCompute(allocator: std.mem.Allocator) !void {
    var note: math.UnavailableNote = .{};
    var probe: Probe = .{};
    const parsed = (try math.parse(allocator, "calc(2cqw + 3px)", .{ .kind = .length })) orelse return error.Parse;
    defer parsed.expression.unref();
    const computed = try parsed.expression.compute(allocator, .{ .container = probe.input(&note) });
    defer computed.unref();
    try std.testing.expect(note.retained_length and !note.scalar);
    try std.testing.expect(computed.computedNumber() == null);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try computed.serialize(&out, allocator);
    try std.testing.expect(std.mem.indexOf(u8, out.items, "cqw") != null);
}

test "cp1 computed length retains an unavailable container term" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    try lengthCompute(a);
}

test "cp1 retained container expressions survive every allocation failure" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    try std.testing.checkAllAllocationFailures(a, lengthCompute, .{});
}

test "cp1 scalar and unknown numeric kinds set the safe unavailable default" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    inline for (.{ .{ "sign(2cqw - 10px)", .number }, .{ "calc(1cqw / 1px * 1s)", .time } }) |row| {
        var note: math.UnavailableNote = .{};
        var probe: Probe = .{};
        const parsed = (try math.parse(a, row[0], .{ .kind = row[1] })) orelse return error.Parse;
        defer parsed.expression.unref();
        const computed = try parsed.expression.compute(a, .{ .container = probe.input(&note) });
        defer computed.unref();
        try std.testing.expect(note.scalar and !note.retained_length);
        // This scalar is a placeholder: the owning cascade must discard it.
        try std.testing.expect(computed.computedNumber() != null);
    }
}

test "cp1 algebraic cancellation removes the container dependency" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    var note: math.UnavailableNote = .{};
    var probe: Probe = .{};
    const parsed = (try math.parse(a, "calc(2cqw / 1cqw)", .{ .kind = .number })) orelse return error.Parse;
    defer parsed.expression.unref();
    const computed = try parsed.expression.compute(a, .{ .container = probe.input(&note) });
    defer computed.unref();
    const n = computed.computedNumber() orelse return error.UnresolvedCancellation;
    try std.testing.expectEqual(@as(f64, 2), n.value);
    try std.testing.expectEqual(@as(usize, 0), probe.calls);
    try std.testing.expect(!note.scalar and !note.retained_length);
}

fn expectStyle(style: *const css.computed_style.ComputedStyle, property: css.properties.Longhand, text: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try style.serializeResolved(property, &out, a);
    try std.testing.expectEqualStrings(text, out.items);
}

fn retry(allocator: std.mem.Allocator, revert: bool) !void {
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "tab-size: 7; font-size: 14px; width: 5px");
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "tab-size: sign(2cqw - 10px); font-size: 10cqw; width: 10cqw");
    defer high.deinit();
    var rollback = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "tab-size: revert-layer; font-size: revert-layer; width: revert-layer");
    defer rollback.deinit();
    var note: math.UnavailableNote = .{};
    var probe: Probe = .{};
    const matched = [_]css.cascade.Matched{
        .{ .block = &low, .source = .{ .origin = .author, .order = 1, .layer = 0 } },
        .{ .block = &high, .source = .{ .origin = .author, .order = 2, .layer = 0 } },
        .{ .block = &rollback, .source = .{ .origin = .author, .order = 3, .layer = 1 } },
    };
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .container = probe.input(&note) }, matched[0..if (revert) 3 else 2]);
    defer style.destroy();
    try std.testing.expectEqual(@as(f64, 7), style.get(.tab_size).number);
    try std.testing.expectEqual(@as(f64, 14), style.get(.font_size).length.value);
    try std.testing.expect(style.get(.width) == .calculation);
    try std.testing.expect(!note.scalar and !note.retained_length);
}

test "cp1 unavailable candidates preserve lower declarations in the same layer" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    try retry(a, false);
}

test "cp1 revert layer bookkeeping survives an unavailable candidate retry" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    try retry(a, true);
}

test "cp1 exact candidate retry survives every allocation failure" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    try std.testing.checkAllAllocationFailures(a, retry, .{false});
}

fn registered(syntax: []const u8, initial_text: []const u8, low_text: []const u8, high_text: []const u8, expected: []const u8, consume: []const u8, width: []const u8, font: []const u8) !void {
    var definition = try css.syntax_definitions.parse(a, syntax);
    defer definition.deinit();
    var initial = (try definition.parseValue(.{ .allocator = a }, initial_text)) orelse return error.Initial;
    defer initial.deinit();
    const snapshot = try css.registered_properties.Snapshot.create(a, .{}, &.{.{ .name = "--cq", .syntax_text = syntax, .inherits = false, .initial_value = &initial }});
    defer snapshot.release();
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, low_text);
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, high_text);
    defer high.deinit();
    var consumer = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, consume);
    defer consumer.deinit();
    var note: math.UnavailableNote = .{};
    var probe: Probe = .{};
    const style = try css.cascade.cascade(.{ .allocator = a, .parent = null, .registered = snapshot, .container = probe.input(&note) }, &.{
        .{ .block = &low, .source = .{ .origin = .author, .order = 1 } },
        .{ .block = &high, .source = .{ .origin = .author, .order = 2 } },
        .{ .block = &consumer, .source = .{ .origin = .author, .order = 3 } },
    });
    defer style.destroy();
    const stored = style.customValue("--cq") orelse return error.CustomMissing;
    try std.testing.expectEqualStrings(expected, stored.bytes);
    try expectStyle(style, .width, width);
    try expectStyle(style, .font_size, font);
    try std.testing.expect(!note.scalar and !note.retained_length);
}

test "cp1 registered number skips before custom storage and substitutes into lengths" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    try registered("<number>", "4", "--cq: 7", "--cq: sign(2cqw - 10px)", "7", "width: calc(var(--cq) * 1px); font-size: calc(var(--cq) * 1px)", "7px", "7px");
}

test "cp1 registered unavailable length selects its lower absolute value" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    try registered("<length>", "4px", "--cq: 7px; font-size: 14px", "--cq: 10cqw", "7px", "width: var(--cq); font-size: var(--cq)", "7px", "7px");
}

test "cp1 repeated scalar registration discards the whole unavailable candidate" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    try registered("<number>#", "4, 5", "--cq: 7, 8", "--cq: 9, sign(2cqw - 10px)", "7, 8", "width: 3px; font-size: 14px", "3px", "14px");
}

test "cp1 repeated length registration discards the whole unavailable candidate" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    try registered("<length>#", "4px, 5px", "--cq: 7px, 8px", "--cq: 9px, 10cqw", "7px, 8px", "width: 3px; font-size: 14px", "3px", "14px");
}

test "cp1 union registration rejects unavailable scalar and length inputs" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    try registered("<number> | <length>", "4", "--cq: 7px", "--cq: sign(2cqw - 10px)", "7px", "width: var(--cq); font-size: var(--cq)", "7px", "7px");
    try registered("<number> | <length>", "4", "--cq: 7px; font-size: 14px", "--cq: 10cqw", "7px", "width: var(--cq); font-size: var(--cq)", "7px", "7px");
}

fn inheritedLength(is_registered: bool, lower: bool) !void {
    var definition = try css.syntax_definitions.parse(a, "<length>");
    defer definition.deinit();
    var initial = (try definition.parseValue(.{ .allocator = a }, "4px")) orelse return error.Initial;
    defer initial.deinit();
    const snapshot = try css.registered_properties.Snapshot.create(a, .{}, &.{.{ .name = "--cq", .syntax_text = "<length>", .inherits = true, .initial_value = &initial }});
    defer snapshot.release();
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, "--cq:7px");
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, "--cq:2cqi; writing-mode:horizontal-tb");
    defer high.deinit();
    var consumer = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, "writing-mode:vertical-rl; width:var(--cq)");
    defer consumer.deinit();
    var note: math.UnavailableNote = .{};
    var probe: Probe = .{ .height = false };
    const candidates = [_]css.cascade.Matched{
        .{ .block = &high, .source = .{ .origin = .author, .order = 2 } },
        .{ .block = &low, .source = .{ .origin = .author, .order = 1 } },
    };
    const parent = try css.cascade.cascade(.{
        .allocator = a,
        .parent = null,
        .registered = if (is_registered) snapshot else null,
        .container = probe.input(&note),
        .viewport_width = 800,
        .viewport_height = 600,
    }, candidates[0..if (lower) 2 else 1]);
    defer parent.destroy();
    const child = try css.cascade.cascade(.{
        .allocator = a,
        .parent = parent,
        .registered = if (is_registered) snapshot else null,
        .container = probe.input(&note),
        .viewport_width = 800,
        .viewport_height = 600,
    }, &.{.{ .block = &consumer, .source = .{ .origin = .author } }});
    defer child.destroy();
    const expected = if (is_registered) (if (lower) "7px" else "4px") else "12px";
    try expectStyle(child, .width, expected);
    const parent_value = parent.customValue("--cq") orelse return error.CustomMissing;
    try std.testing.expectEqualStrings(if (is_registered) expected else "2cqi", parent_value.bytes);
    try std.testing.expect(!note.scalar and !note.retained_length);
}

test "cp1 registered inherited length cannot be remapped by child writing mode" {
    try inheritedLength(true, true);
    try inheritedLength(true, false);
}

test "cp1 unregistered inherited length uses the consuming child axis" {
    try inheritedLength(false, true);
}

test "cp1 cached shorthand placeholder never replaces lower side candidates" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, "margin: 1px 2px 3px 4px");
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, "margin: random-item(fixed sign(2cqw - 10px), 11px, 12px)");
    defer high.deinit();
    var note: math.UnavailableNote = .{};
    var probe: Probe = .{};
    const style = try css.cascade.cascade(.{ .allocator = a, .parent = null, .container = probe.input(&note) }, &.{
        .{ .block = &low, .source = .{ .origin = .author, .order = 1 } },
        .{ .block = &high, .source = .{ .origin = .author, .order = 2 } },
    });
    defer style.destroy();
    inline for (.{ .{ .margin_top, "1px" }, .{ .margin_right, "2px" }, .{ .margin_bottom, "3px" }, .{ .margin_left, "4px" } }) |row|
        try expectStyle(style, row[0], row[1]);
    try std.testing.expect(!note.scalar and !note.retained_length);
}

test "cp1 selected pending length keeps the geometry allowance" {
    if (comptime !@hasField(math.Context, "container")) return error.MissingContainerInput;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, "margin: random-item(fixed 0, 2cqw, 3px)");
    defer block.deinit();
    var note: math.UnavailableNote = .{};
    var probe: Probe = .{};
    const style = try css.cascade.cascade(.{ .allocator = a, .parent = null, .container = probe.input(&note) }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    inline for (.{ .margin_top, .margin_right, .margin_bottom, .margin_left }) |l| try expectStyle(style, l, "2cqw");
    try std.testing.expect(!note.scalar and !note.retained_length);
}
