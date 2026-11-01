//! Fonts4 §4.4/§5.2 and Values4 §9.1/§10.12: consume specified stretch ranges.
//! Q66/Q67: exercise the same Block-to-MatchFace mapping used by selection,
//! then the existing face selector. No platform object or alternate parser.
const std = @import("std");
const dom = @import("dom");
const fonts = dom.style.engine.resource_loading.font_loading;
const Block = dom.style.css.declarations.DeclarationBlock;
const Allocator = std.mem.Allocator;
const testing = std.testing;

const Fixture = struct {
    block: Block,
    stretch: []u8,
    weight: []u8,
    style: []u8,

    fn init(text: []const u8) !Fixture {
        var block = try fonts.descriptorBlock(testing.allocator, text);
        errdefer block.deinit();
        return snapshot(block);
    }

    fn fromStretch(input: []const u8) !Fixture {
        var block = try fonts.descriptorBlock(testing.allocator, "");
        errdefer block.deinit();
        try testing.expect(try fonts.setDescriptor(&block, "font-stretch", input, ""));
        return snapshot(block);
    }

    fn snapshot(block: Block) !Fixture {
        const stretch = try testing.allocator.dupe(u8, fonts.descriptorValue(&block, "font-stretch"));
        errdefer testing.allocator.free(stretch);
        const weight = try testing.allocator.dupe(u8, fonts.descriptorValue(&block, "font-weight"));
        errdefer testing.allocator.free(weight);
        const style = try testing.allocator.dupe(u8, fonts.descriptorValue(&block, "font-style"));
        return .{ .block = block, .stretch = stretch, .weight = weight, .style = style };
    }

    fn deinit(self: *Fixture) void {
        self.block.deinit();
        testing.allocator.free(self.stretch);
        testing.allocator.free(self.weight);
        testing.allocator.free(self.style);
    }

    fn expectUnchanged(self: *const Fixture) !void {
        try testing.expectEqualStrings(self.stretch, fonts.descriptorValue(&self.block, "font-stretch"));
        try testing.expectEqualStrings(self.stretch, fonts.descriptorValue(&self.block, "font-width"));
        try testing.expectEqualStrings(self.weight, fonts.descriptorValue(&self.block, "font-weight"));
        try testing.expectEqualStrings(self.style, fonts.descriptorValue(&self.block, "font-style"));
    }
};

fn map(allocator: Allocator, fixture: *const Fixture) !fonts.MatchFace {
    const mapped = fonts.matchingDescriptors(allocator, &fixture.block) catch |err| {
        try fixture.expectUnchanged();
        return err;
    };
    try fixture.expectUnchanged();
    return mapped;
}

fn expectSelected(faces: []const fonts.MatchFace, width: f64, expected: []const usize) !void {
    const selected = try fonts.matchFaces(testing.allocator, faces, .{ .width = width });
    defer testing.allocator.free(selected);
    try testing.expectEqualSlices(usize, expected, selected);
}

test "stretch calculation selects its context-free percentage through the descriptor consumer" {
    var calculated = try Fixture.fromStretch("calc(50%)");
    defer calculated.deinit();
    var literal = try Fixture.fromStretch("75%");
    defer literal.deinit();
    const faces = [_]fonts.MatchFace{ try map(testing.allocator, &calculated), try map(testing.allocator, &literal) };
    try expectSelected(&faces, 50, &.{0});
    try testing.expectEqualStrings("calc(50%)", calculated.stretch);
}

test "negative stretch calculation clamps at use and ties the literal zero face" {
    var calculated = try Fixture.fromStretch("calc(0% - 10%)");
    defer calculated.deinit();
    var zero = try Fixture.fromStretch("0%");
    defer zero.deinit();
    const faces = [_]fonts.MatchFace{ try map(testing.allocator, &calculated), try map(testing.allocator, &zero) };
    // A winner against 50% would also pass with an unclamped -10%.
    // Tying literal0 proves that the negative result actually became zero.
    try expectSelected(&faces, 0, &.{ 0, 1 });
    try testing.expectEqualStrings("calc(-10%)", calculated.stretch);
}

fn expectPositiveZero(mapped: fonts.MatchFace) !void {
    try testing.expectEqualDeep(fonts.MatchFace{ .width = .{ .first = 0, .last = 0 } }, mapped);
    try testing.expect(!std.math.signbit(mapped.width.first));
    try testing.expect(!std.math.signbit(mapped.width.last));
}

fn expectCensoredZero(input: []const u8) !void {
    // Q68 / Values4 §10.9.2: known NaN, infinities and signed zero receive
    // outer censoring, rather than the unavailable-context auto fallback.
    // https://drafts.csswg.org/css-values-4/#calc-ieee
    var calculated = try Fixture.fromStretch(input);
    defer calculated.deinit();
    var zero = try Fixture.fromStretch("0%");
    defer zero.deinit();
    const faces = [_]fonts.MatchFace{ try map(testing.allocator, &calculated), try map(testing.allocator, &zero) };
    try expectSelected(&faces, 0, &.{ 0, 1 });
    try expectPositiveZero(faces[0]);
    try calculated.expectUnchanged();
}

test "known NaN stretch censors to positive zero and ties literal zero" {
    try expectCensoredZero("calc(NaN * 1%)");
}

test "known negative infinite stretch clamps to positive zero and ties literal zero" {
    try expectCensoredZero("calc(-infinity * 1%)");
}

test "produced negative zero stretch matches with a positive zero sign bit" {
    // Produce 0-minus with arithmetic instead of spelling a literal -0.
    // The specified-text serializer may already spell this calc(0%); the
    // public descriptor consumer must still return unsigned zero on both ends.
    try expectCensoredZero("calc(-1% * 0)");
}

test "positive infinite stretch clamps to its finite grammar maximum and selects above finite faces" {
    var calculated = try Fixture.fromStretch("calc(infinity * 1%)");
    defer calculated.deinit();
    var finite = try Fixture.fromStretch("200%");
    defer finite.deinit();
    const faces = [_]fonts.MatchFace{ try map(testing.allocator, &calculated), try map(testing.allocator, &finite) };
    // Fonts4 §5.2 step4.1 searches at/above requests over100 before below.
    try expectSelected(&faces, 250, &.{0});
    const grammar: dom.style.css.math_values.Grammar = .{ .kind = .percentage, .minimum = 0 };
    try testing.expect(std.math.isFinite(faces[0].width.first));
    try testing.expect(std.math.isFinite(faces[0].width.last));
    try testing.expectEqual(grammar.maximum, faces[0].width.first);
    try testing.expectEqual(grammar.maximum, faces[0].width.last);
    try calculated.expectUnchanged();
}

const Probe = struct { text: []const u8, width: f64, expected: []const usize };
const range_probes = [_]Probe{
    .{ .text = "25%", .width = 25, .expected = &.{1} },
    .{ .text = "50%", .width = 50, .expected = &.{ 0, 1 } },
    .{ .text = "75%", .width = 75, .expected = &.{ 0, 1 } },
    .{ .text = "125%", .width = 125, .expected = &.{ 0, 1 } },
    .{ .text = "150%", .width = 150, .expected = &.{ 0, 1 } },
    .{ .text = "175%", .width = 175, .expected = &.{1} },
};

fn expectRange(input: []const u8) !void {
    var range = try Fixture.fromStretch(input);
    defer range.deinit();
    const mapped = try map(testing.allocator, &range);
    for (range_probes) |probe| {
        var point = try Fixture.fromStretch(probe.text);
        defer point.deinit();
        const faces = [_]fonts.MatchFace{ mapped, try map(testing.allocator, &point) };
        // A tie with an exact point distinguishes a range from either endpoint.
        try expectSelected(&faces, probe.width, probe.expected);
    }
    try range.expectUnchanged();
}

test "stretch range keeps a calculated first endpoint and a literal second endpoint" {
    try expectRange("calc(50%) 150%");
}

test "stretch range sorts a literal first endpoint and a smaller calculated second endpoint" {
    try expectRange("150% calc(50%)");
}

test "stretch range keeps a literal first endpoint and a calculated second endpoint" {
    try expectRange("50% calc(150%)");
}

test "stretch range sorts a calculated first endpoint and a smaller literal second endpoint" {
    try expectRange("calc(150%) 50%");
}

fn expectClampedRange(input: []const u8) !void {
    var range = try Fixture.fromStretch(input);
    defer range.deinit();
    const mapped = try map(testing.allocator, &range);
    for ([_]Probe{
        .{ .text = "0%", .width = 0, .expected = &.{ 0, 1 } },
        .{ .text = "40%", .width = 40, .expected = &.{ 0, 1 } },
        .{ .text = "80%", .width = 80, .expected = &.{ 0, 1 } },
        .{ .text = "90%", .width = 90, .expected = &.{1} },
    }) |probe| {
        var point = try Fixture.fromStretch(probe.text);
        defer point.deinit();
        const faces = [_]fonts.MatchFace{ mapped, try map(testing.allocator, &point) };
        try expectSelected(&faces, probe.width, probe.expected);
    }
    try range.expectUnchanged();
}

test "stretch range clamps both calculation endpoints without changing specified order" {
    try expectClampedRange("calc(-10%) calc(80%)");
    try expectClampedRange("calc(80%) calc(-10%)");
}

const unresolved = "calc(50% + 25% * sign(100em - 1px))";

fn expectAbsent(input: []const u8) !void {
    // Q66's native ruling follows Gecko engine head:
    // font_face.rs FontWidthRange::compute computes both bounds before sorting;
    // percentage.rs NonNegativePercentage::compute uses context-free resolve;
    // glue.rs Servo_FontFaceRule_GetFontWidth reports unavailable to
    // FontFaceImpl.cpp GetAttributesFromRule, which leaves auto-width intact.
    // https://github.com/mozilla-firefox/firefox/blob/main/servo/components/style/font_face.rs#L372
    // https://github.com/mozilla-firefox/firefox/blob/main/servo/components/style/values/specified/percentage.rs#L355
    // https://github.com/mozilla-firefox/firefox/blob/main/servo/ports/geckolib/glue.rs#L3810
    // https://github.com/mozilla-firefox/firefox/blob/main/layout/style/FontFaceImpl.cpp#L639
    var calculated = try Fixture.fromStretch(input);
    defer calculated.deinit();
    var absent = try Fixture.init("");
    defer absent.deinit();
    var narrower = try Fixture.fromStretch("75%");
    defer narrower.deinit();
    const faces = [_]fonts.MatchFace{
        try map(testing.allocator, &calculated),
        try map(testing.allocator, &absent),
        try map(testing.allocator, &narrower),
    };
    try expectSelected(&faces, 75, &.{2});
    try expectSelected(&faces, 100, &.{ 0, 1 });
    try expectSelected(&faces, 125, &.{ 0, 1 });
    try testing.expectEqualDeep(faces[1], faces[0]);
    try calculated.expectUnchanged();
}

test "unresolved stretch calculation matches an absent descriptor" {
    // This single-calc case passes before Q66; it is a fallback control.
    try expectAbsent(unresolved);
}

test "unresolved first stretch endpoint discards the whole descriptor for matching" {
    try expectAbsent(unresolved ++ " 75%");
    try expectAbsent(unresolved ++ " calc(75%)");
}

test "unresolved second stretch endpoint discards a known literal or calculated first endpoint" {
    // The literal-first case catches today's partial first-endpoint fallback.
    try expectAbsent("75% " ++ unresolved);
    try expectAbsent("calc(75%) " ++ unresolved);
}

test "absent stretch weight and style match explicit normal and auto on all axes" {
    var absent = try Fixture.init("");
    defer absent.deinit();
    var normal = try Fixture.init("font-stretch: normal; font-weight: normal; font-style: normal");
    defer normal.deinit();
    var automatic = try Fixture.init("font-stretch: auto; font-weight: auto; font-style: auto");
    defer automatic.deinit();
    const faces = [_]fonts.MatchFace{
        try map(testing.allocator, &absent),
        try map(testing.allocator, &normal),
        try map(testing.allocator, &automatic),
    };
    try testing.expectEqualDeep(fonts.MatchFace{}, faces[0]);
    try testing.expectEqualDeep(faces[0], faces[1]);
    try testing.expectEqualDeep(faces[0], faces[2]);
    try expectSelected(&faces, 100, &.{ 0, 1, 2 });
}

test "literal and keyword stretch ranges keep their existing selection" {
    for ([_][]const u8{ "50% 150%", "150% 50%", "ultra-condensed extra-expanded", "extra-expanded ultra-condensed" }) |input| {
        try expectRange(input);
    }
}

test "literal weight and style mapping retain their existing endpoints" {
    var fixture = try Fixture.init("font-stretch: condensed; font-weight: 700 300; font-style: oblique 20deg -10deg");
    defer fixture.deinit();
    const mapped = try map(testing.allocator, &fixture);
    try testing.expectEqualDeep(fonts.MatchFace{
        .width = .{ .first = 75, .last = 75 },
        .weight = .{ .first = 700, .last = 300 },
        .style = .{ .axis = .oblique, .range = .{ .first = 20, .last = -10 } },
    }, mapped);
    const selected = try fonts.matchFaces(testing.allocator, &.{ mapped, .{} }, .{ .width = 75, .style = .oblique, .angle = 10, .weight = 400 });
    defer testing.allocator.free(selected);
    try testing.expectEqualSlices(usize, &.{0}, selected);
}

fn mapping100(allocator: Allocator, fixture: *const Fixture) !void {
    const mapped = try map(allocator, fixture);
    try testing.expectEqualDeep(fonts.MatchFace{}, mapped);
}

test "stretch descriptor mapping propagates every allocation failure and preserves specified text" {
    // Fixtures keep their original testing allocator; only the real consumer
    // uses the failing allocator. calc100 has the same expected result at RED
    // and GREEN. Step A's zero-allocation pass is not ownership evidence.
    // The pinned std helper sets resize_fail_index=0 for every walk.
    for ([_][]const u8{
        "calc(100%)",
        "calc(100%) 100%",
        "100% calc(100%)",
        "calc(100%) " ++ unresolved,
        "100% " ++ unresolved,
    }) |input| {
        var fixture = try Fixture.fromStretch(input);
        defer fixture.deinit();
        try mapping100(testing.allocator, &fixture);
        try testing.checkAllAllocationFailures(testing.allocator, mapping100, .{&fixture});
        try fixture.expectUnchanged();
    }
}

fn mappingZero(allocator: Allocator, fixture: *const Fixture) !void {
    try expectPositiveZero(try map(allocator, fixture));
}

test "censored stretch mapping propagates every allocation failure without mutating specified math" {
    var fixture = try Fixture.fromStretch("calc(NaN * 1%)");
    defer fixture.deinit();
    // Step A fails the initial semantic check at100, before an OOM walk.
    // GREEN must reach every allocation failure of the real calc consumer.
    try mappingZero(testing.allocator, &fixture);
    try testing.checkAllAllocationFailures(testing.allocator, mappingZero, .{&fixture});
    try fixture.expectUnchanged();
}
