//! Images 5 §3.1 / Shapes 1 §§3.1–3.3: rectangular view-box values.
//! Q61 grants this property; Q63 retains unavailable geometry lengths.
//! Shared shape interpolation remains with its routed owner (Q63).
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const geometry = @import("fm1_geometry_helpers.zig");
const metrics = @import("bx1_metric_helpers.zig");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const property_name = "object-view-box";

// String lookup lets these exact tests compile on the committed predecessor:
// its absent registration is a runtime RED, not an unknown enum member.
fn property() !css.properties.Longhand {
    const found = css.properties.lookup(property_name) orelse return error.MissingObjectViewBox;
    try testing.expect(found == .longhand);
    return found.longhand;
}

const Case = struct { input: []const u8, specified: []const u8, computed: []const u8 };

// The six accepted inputs in css/css-images/object-view-box-parsing.html.
// Computed rect/xywh expectations use Shapes 1 §3.2's inset conversion,
// also pinned for the shared owner by clip-path-computed.html.
const valid_cases = [_]Case{
    .{ .input = "inset(10%)", .specified = "inset(10%)", .computed = "inset(10%)" },
    .{ .input = "inset(10px 20px 30px 40px)", .specified = "inset(10px 20px 30px 40px)", .computed = "inset(10px 20px 30px 40px)" },
    .{ .input = "rect(1px 10% 100px 50%)", .specified = "rect(1px 10% 100px 50%)", .computed = "inset(1px 90% calc(100% - 100px) 50%)" },
    .{ .input = "rect(auto auto auto auto)", .specified = "rect(auto auto auto auto)", .computed = "inset(0%)" },
    .{ .input = "rect(auto 5px auto 10%)", .specified = "rect(auto 5px auto 10%)", .computed = "inset(0% calc(100% - 5px) 0% 10%)" },
    .{ .input = "xywh(1px 10% 100px 50%)", .specified = "xywh(1px 10% 100px 50%)", .computed = "inset(10% calc(100% - 101px) 40% 1px)" },
};

fn accepted(allocator: Allocator, case: Case) !void {
    const longhand = try property();
    var block = h.Block.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, property_name, case.input, ""));
    const declaration = block.get(longhand) orelse return error.MissingObjectViewBoxAssignment;
    try testing.expect(declaration.value == .value);
    const value = declaration.value.value;
    // Registration must reach the existing typed owner, not raw readback.
    if (std.mem.eql(u8, case.specified, "none"))
        try testing.expect(value.isKeyword(.none))
    else
        try testing.expect(value == .shape);
    try h.specified(&block, property_name, case.specified, allocator);
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    try h.expect(style, property_name, case.computed, allocator);
}

test "object view box registers its initial non inherited basic shape animation type" {
    const longhand = try property();
    try testing.expect(!longhand.info().inherited);
    try testing.expect(longhand.info().initial.isKeyword(.none));
    try testing.expectEqual(css.interpolation.AnimationType.by_computed_value, css.interpolation.animationType(longhand));
    var block = h.Block.init(testing.allocator);
    defer block.deinit();
    const initial = try h.compute(testing.allocator, &block, null);
    defer initial.destroy();
    try h.expect(initial, property_name, "none", testing.allocator);
}

test "object view box preserves all six valid WPT values and computes rectangular complements" {
    for (valid_cases) |case| try accepted(testing.allocator, case);
}

test "object view box accepts none decoded names signed positions and rounded rectangles" {
    for ([_]Case{
        .{ .input = "NONE", .specified = "none", .computed = "none" },
        .{ .input = "\\6e one", .specified = "none", .computed = "none" },
        .{ .input = "INSET(10%)", .specified = "inset(10%)", .computed = "inset(10%)" },
        .{ .input = "\\69 nset(10%)", .specified = "inset(10%)", .computed = "inset(10%)" },
        .{ .input = "\\72 ect(auto auto auto auto)", .specified = "rect(auto auto auto auto)", .computed = "inset(0%)" },
        .{ .input = "XYWH(10% 20% 30% 40%)", .specified = "xywh(10% 20% 30% 40%)", .computed = "inset(20% 60% 40% 10%)" },
        .{ .input = "inset(-1px -2% 3px)", .specified = "inset(-1px -2% 3px)", .computed = "inset(-1px -2% 3px)" },
        .{ .input = "inset(1px 2px 1px 2px)", .specified = "inset(1px 2px)", .computed = "inset(1px 2px)" },
        .{ .input = "inset(0 round 1px 2px / 3px 4px)", .specified = "inset(0px round 1px 2px / 3px 4px)", .computed = "inset(0px round 1px 2px / 3px 4px)" },
        .{ .input = "rect(auto auto auto auto round 1px)", .specified = "rect(auto auto auto auto round 1px)", .computed = "inset(0% round 1px)" },
        .{ .input = "xywh(-1px -2px 3px 4px round 5px)", .specified = "xywh(-1px -2px 3px 4px round 5px)", .computed = "inset(-2px calc(100% - 2px) calc(100% - 2px) -1px round 5px)" },
    }) |case| try accepted(testing.allocator, case);
}

// Includes every rejected value from object-view-box-parsing.html plus
// well-formed nonrectangular shapes, so subset admission is tested separately
// from a shared parser's rejection of an already malformed shape.
const invalid_cases = [_][]const u8{
    "circle(10px)",
    "ellipse(10px 20px)",
    "polygon(10px 20px 30px)",
    "path(\"M20,80 L50,20\")",
    "blah",
    "xywh(1px 10%)",
    "polygon(1px 2px, 3px 4px)",
    "shape(from 1px 2px, line to 3px 4px)",
    "url(example.svg#view)",
    "border-box",
    "border-box inset(1px)",
    "inset(1px) border-box",
    "none inset(1px)",
    "inset(1px) inset(2px)",
    "inset(1px) trailing",
    "inset()",
    "inset(1px 2px 3px 4px 5px)",
    "inset(2)",
    "inset(1deg)",
    "inset(auto)",
    "inset(0 round -1px)",
    "inset(0 round 1px /)",
    "rect(1px 2px 3px)",
    "rect(1px, 2px, 3px, 4px)",
    "xywh(1px 2px -3px 4px)",
    "xywh(1px 2px 3px -4px)",
    "xywh(1px 2px auto 4px)",
};

fn rejected(allocator: Allocator, input: []const u8, quirks_mode: bool) !void {
    _ = try property();
    const options: css.properties.ParseOptions = .{ .allocator = allocator, .quirks = quirks_mode };
    var block = h.Block.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(options, property_name, "inset(9px)", "important"));
    try testing.expect(!try block.setProperty(options, property_name, input, ""));
    try testing.expect(block.getPropertyPriority(property_name));
    try h.specified(&block, property_name, "inset(9px)", allocator);
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    try h.expect(style, property_name, "inset(9px)", allocator);
}

test "object view box rejects every nonrectangular and malformed value without replacing a declaration" {
    for (invalid_cases) |input| try rejected(testing.allocator, input, false);
}

fn quirks(allocator: Allocator) !void {
    try rejected(allocator, "inset(2)", true);
    try rejected(allocator, "xywh(1px 2px 3 4px)", true);
    var block = h.Block.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator, .quirks = true }, property_name, "inset(0)", ""));
    try h.specified(&block, property_name, "inset(0px)", allocator);
    // A control for the destination-property-specific margin quirk.
    try testing.expect(try block.setProperty(.{ .allocator = allocator, .quirks = true }, "margin-left", "2", ""));
    try h.specified(&block, "margin-left", "2px", allocator);
}

test "object view box borrows rectangular lengths without margins unitless quirks" {
    try quirks(testing.allocator);
}

fn sharedShapes(allocator: Allocator) !void {
    inline for (.{ "clip-path", "shape-outside" }) |name| {
        try h.check(allocator, name, "circle(10px)", "circle(10px)", false);
        try h.check(allocator, name, "ellipse(10px 20px)", "ellipse(10px 20px)", false);
        try h.check(allocator, name, "polygon(1px 2px, 3px 4px)", "polygon(1px 2px, 3px 4px)", false);
        try h.check(allocator, name, "path('M 0 0 L 1 1')", "path(\"M 0 0 L 1 1\")", false);
        try h.check(allocator, name, "shape(from 1px 2px, line to 3px 4px)", "shape(from 1px 2px, line to 3px 4px)", false);
    }
}

test "object view box rectangular admission leaves other shape consumers intact" {
    try sharedShapes(testing.allocator);
}

// Source text ends before computation; declarations end before caller readback.
fn detachedStyle(allocator: Allocator, text: []const u8) !*h.Style {
    _ = try property();
    var block = blk: {
        const owned = try allocator.dupe(u8, text);
        defer allocator.free(owned);
        break :blk try h.Block.parse(.{ .allocator = allocator }, owned);
    };
    defer block.deinit();
    const longhand = try property();
    try testing.expect(block.get(longhand) != null);
    return h.compute(allocator, &block, null);
}

const owned_declaration = "font-size:20px;object-view-box:inset(calc(1em + 2px) 10% 2em 20% round 1em 2em / 3em 4em)";
const owned_computed = "inset(22px 10% 40px 20% round 20px 40px / 60px 80px)";

fn ownedComputation(allocator: Allocator) !void {
    const style = try detachedStyle(allocator, owned_declaration);
    defer style.destroy();
    try h.expect(style, property_name, owned_computed, allocator);
    // These mixed math inputs/outputs are pinned for clip-path in the shared
    // ci1_image_math_test; this property must call that same typed owner.
    const math_style = try detachedStyle(allocator, "object-view-box:xywh(10px 20px calc(30% + 5px) calc(40% + 6px))");
    defer math_style.destroy();
    try h.expect(math_style, property_name, "inset(20px calc(70% - 15px) calc(60% - 26px) 10px)", allocator);
}

test "object view box computed math and radii survive their source text and declarations" {
    try ownedComputation(testing.allocator);
}

fn inheritance(allocator: Allocator) !void {
    const parent = try detachedStyle(allocator, owned_declaration);
    defer parent.destroy();
    var empty = h.Block.init(allocator);
    defer empty.deinit();
    const child = try h.compute(allocator, &empty, parent);
    defer child.destroy();
    try h.expect(child, property_name, "none", allocator);
    inline for (.{ "unset", "initial" }) |keyword| {
        try testing.expect(try empty.setProperty(.{ .allocator = allocator }, property_name, keyword, ""));
        const reset = try h.compute(allocator, &empty, parent);
        defer reset.destroy();
        try h.expect(reset, property_name, "none", allocator);
    }
    try testing.expect(try empty.setProperty(.{ .allocator = allocator }, property_name, "inherit", ""));
    try testing.expect(try empty.setProperty(.{ .allocator = allocator }, "font-size", "40px", ""));
    const inherited = try h.compute(allocator, &empty, parent);
    defer inherited.destroy();
    try h.expect(inherited, property_name, owned_computed, allocator);
    // inherit at the root has the initial value, not a stale parent's shape.
    const root = try h.compute(allocator, &empty, null);
    defer root.destroy();
    try h.expect(root, property_name, "none", allocator);
}

fn inheritedAfterSources(allocator: Allocator) !void {
    const child = blk: {
        const parent = try detachedStyle(allocator, owned_declaration);
        defer parent.destroy();
        var block = try h.Block.parse(.{ .allocator = allocator }, "font-size:40px;object-view-box:inherit");
        defer block.deinit();
        break :blk try h.compute(allocator, &block, parent);
    };
    defer child.destroy();
    try h.expect(child, property_name, owned_computed, allocator);
}

test "object view box is initially none and inherits only when explicitly requested" {
    try inheritance(testing.allocator);
    try inheritedAfterSources(testing.allocator);
}

fn computedPercentages(allocator: Allocator) !void {
    inline for (.{
        "width:0px;height:0px;object-view-box:inset(75% 0px 50% 0px)",
        "width:1000px;height:500px;object-view-box:inset(75% 0px 50% 0px)",
    }) |text| {
        const style = try detachedStyle(allocator, text);
        defer style.destroy();
        // Images5 §3.1 (:274–284) and ANSWER Q64: the reference box uses
        // natural width/height at use, not these CSS sizes during computation.
        // Shapes1 §3.3 / ANSWER Q69 omit the redundant fourth computed side.
        try h.expect(style, property_name, "inset(75% 0px 50%)", allocator);
    }
}

test "object view box computation retains percentages without inventing natural geometry" {
    try computedPercentages(testing.allocator);
}

fn declarations(allocator: Allocator) !void {
    _ = try property();
    var block = try h.Block.parse(.{ .allocator = allocator }, "object-view-box:inset(1px);object-view-box:inset(2px) !important;object-view-box:inset(3px)");
    defer block.deinit();
    try h.specified(&block, property_name, "inset(2px)", allocator);
    try testing.expect(block.getPropertyPriority(property_name));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings("object-view-box: inset(2px) !important;", out.items);
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, property_name, "rect(auto auto auto auto)", ""));
    try h.specified(&block, property_name, "rect(auto auto auto auto)", allocator);
    try testing.expect(!block.getPropertyPriority(property_name));
    try testing.expect(!try block.setProperty(.{ .allocator = allocator }, property_name, "inset(4px)", "invalid-priority"));
    try testing.expect(!try block.setProperty(.{ .allocator = allocator }, property_name, "inset(1px) trailing", "important"));
    try h.specified(&block, property_name, "rect(auto auto auto auto)", allocator);
    out.clearRetainingCapacity();
    try testing.expect(try block.removeProperty(property_name, &out));
    try testing.expectEqualStrings("rect(auto auto auto auto)", out.items);
    try h.specified(&block, property_name, "", allocator);
    try testing.expect(!block.getPropertyPriority(property_name));
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, property_name, "inset(5px)", ""));
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, property_name, "", ""));
    try h.specified(&block, property_name, "", allocator);
}

test "object view box CSSOM parse replacement priority serialization and removal use typed storage" {
    try declarations(testing.allocator);
}

const GeometryProbe = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque, _: css.math_values.Context.ContainerAxis) css.math_values.Context.ContainerEligibility {
        const self: *GeometryProbe = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .eligible_geometry_unavailable;
    }
};

fn exactRetainedLength(allocator: Allocator) !void {
    _ = try property();
    var low = h.Block.init(allocator);
    defer low.deinit();
    var high = h.Block.init(allocator);
    defer high.deinit();
    const input = "inset(calc(1px * sign(10cqw - 1px)))";
    try testing.expect(try low.setProperty(.{ .allocator = allocator }, property_name, "inset(9px)", ""));
    try testing.expect(try high.setProperty(.{ .allocator = allocator }, property_name, input, ""));
    var probe: GeometryProbe = .{};
    var note: css.math_values.UnavailableNote = .{};
    const style = try css.cascade.cascade(.{
        .allocator = allocator,
        .parent = null,
        .container = .{ .context = &probe, .get = GeometryProbe.get, .note = &note },
    }, &.{
        .{ .block = &low, .source = .{ .origin = .author, .order = 1 } },
        .{ .block = &high, .source = .{ .origin = .author, .order = 2 } },
    });
    defer style.destroy();
    try testing.expect(probe.calls > 0);
    try testing.expect(!note.scalar and !note.retained_length);
    // ANSWER Q69: the OUTER coordinate is a length. Its nested numeric
    // sign() does not make this a scalar consumer; retain the exact tree.
    try h.expect(style, property_name, input, allocator);
}

fn unavailableGeometry(allocator: Allocator) !void {
    _ = try property();
    // Q63: the exact existing capability context says geometry is unavailable.
    // It supplies no invented box dimensions. Both checks assert it was queried.
    try geometry.check(allocator, property_name, "inset(10cqw)", "none", true);
    try exactRetainedLength(allocator);
    try metrics.check(allocator, property_name, "inset(9px)", "inset(calc(1cap + 2px))", null);
}

test "object view box retains unavailable container and font geometry lengths" {
    try unavailableGeometry(testing.allocator);
}

fn scalarRetry(allocator: Allocator) !void {
    // ANSWER Q69: opacity is an existing SCALAR consumer. This control has
    // no object-view-box lookup, so it passes before the new registration.
    try geometry.check(allocator, "opacity", "calc(sign(10cqw - 1px))", "0.3", false);
}

test "unavailable scalar opacity retries on the predecessor with all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, scalarRetry, .{});
}

fn allocationFailure(allocator: Allocator) !void {
    try scalarRetry(allocator);
    for (valid_cases) |case| try accepted(allocator, case);
    try accepted(allocator, .{ .input = "inset(0 round 1px 2px / 3px 4px)", .specified = "inset(0px round 1px 2px / 3px 4px)", .computed = "inset(0px round 1px 2px / 3px 4px)" });
    try rejected(allocator, "inset(1px round 2px) trailing", false);
    try rejected(allocator, "xywh(1px 2px 3px 4px round 5px) border-box", false);
    try quirks(allocator);
    try ownedComputation(allocator);
    try inheritance(allocator);
    try inheritedAfterSources(allocator);
    try computedPercentages(allocator);
    try declarations(allocator);
    try unavailableGeometry(allocator);
}

test "object view box releases every allocation failure across parse compute inherit and retry" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
