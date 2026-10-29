//! Q55 / integrator probe 1026q: non-finite composition and own display:none.
const std = @import("std");
const css = @import("css");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

const finite_overflow_cases = .{
    .{ "scale(1e308) scale(2)", "matrix(infinity, 0, 0, infinity, 0, 0)" },
    .{ "scale(1e308) scale(1e308)", "matrix(infinity, 0, 0, infinity, 0, 0)" },
    .{ "scale3d(1e308, 1, 1) scale3d(2, 1, 1)", "matrix(infinity, 0, 0, 1, 0, 0)" },
    .{ "matrix(1e308, 0, 0, 1, 0, 0) matrix(2, 0, 0, 1, 0, 0)", "matrix(infinity, 0, 0, 1, 0, 0)" },
    // Q55: input storage differs in the browsers; retain Crane's f64 domain.
    .{ "translateX(1e308px) translateX(1e308px)", "matrix(1, 0, 0, 1, infinity, 0)" },
};

test "transform composition retains overflow with the Chrome Safari infinity spelling" {
    inline for (finite_overflow_cases) |case|
        try h.check(testing.allocator, "transform", case[0], case[1], true);
    // Negative infinity was NOT probed; Q55 explicitly adopts the signed
    // spelling by symmetry. This control belongs only in the native suite.
    try h.check(testing.allocator, "transform", "scale(-1e308) scale(2)", "matrix(-infinity, 0, 0, -infinity, 0, 0)", true);
    try h.check(testing.allocator, "transform", "scale3d(1e308, 1, 2) scale3d(2, 1, 1)", "matrix3d(infinity, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 0, 1)", true);
}

test "scale after overflow yields NaN only on its axes as all three browsers do" {
    // Q55: all three return this exact affine structure, including its zeros.
    try h.check(testing.allocator, "transform", "scale(1e200) scale(1e200) scale(0)", "matrix(NaN, 0, 0, NaN, 0, 0)", true);
}

test "a single huge finite scale keeps the existing f64 input domain" {
    try hugeFinite(testing.allocator);
}

fn hugeFinite(allocator: h.Allocator) !void {
    // Q55 leaves input storage and finite number formatting unchanged. Check
    // the numerical matrix instead of imposing one browser's decimal text.
    var block = try h.Block.parse(.{ .allocator = allocator }, "transform:scale(1e308)");
    defer block.deinit();
    const style = try h.compute(allocator, &block, null);
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try h.read(style, "transform", &text, allocator);
    var components = std.mem.tokenizeAny(u8, text.items, "(), ");
    try testing.expectEqualStrings("matrix", components.next() orelse return error.MissingMatrix);
    for ([_]f64{ 1e308, 0, 0, 1e308, 0, 0 }) |expected| {
        const token = components.next() orelse return error.MissingMatrixComponent;
        try testing.expectEqual(expected, try std.fmt.parseFloat(f64, token));
    }
    try testing.expect(components.next() == null);
}

test "transform underflow and finite composition keep their ordinary results" {
    try finiteCases(testing.allocator);
}

fn finiteCases(allocator: h.Allocator) !void {
    inline for (.{
        .{ "scale(1e-308) scale(1e-308)", "matrix(0, 0, 0, 0, 0, 0)" },
        .{ "scale(2) scale(3)", "matrix(6, 0, 0, 6, 0, 0)" },
        .{ "translateX(1px) translateX(2px)", "matrix(1, 0, 0, 1, 3, 0)" },
        .{ "translate(10px, 20px) scale(2, 3)", "matrix(2, 0, 0, 3, 10, 20)" },
        .{ "scale(2, 3) translate(10px, 20px)", "matrix(2, 0, 0, 3, 20, 60)" },
        .{ "rotate(90deg) scale(2, 3)", "matrix(0, 2, -3, 0, 0, 0)" },
        .{ "scale(2, 3) rotate(90deg)", "matrix(0, 3, -2, 0, 0, 0)" },
        .{ "skewX(45deg) scale(2, 3)", "matrix(2, 0, 3, 3, 0, 0)" },
        .{ "scale(2, 3) skewX(45deg)", "matrix(2, 0, 2, 3, 0, 0)" },
        .{ "matrix(1, 2, 3, 4, 5, 6) scale(2, 3)", "matrix(2, 4, 9, 12, 5, 6)" },
        .{ "scale(2, 3) matrix(1, 2, 3, 4, 5, 6)", "matrix(2, 6, 6, 12, 10, 18)" },
        .{ "scale(-1)", "matrix(-1, 0, 0, -1, 0, 0)" },
        .{ "scale(0)", "matrix(0, 0, 0, 0, 0, 0)" },
        .{ "scaleX(2) scaleY(3) scaleZ(4)", "matrix3d(2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 4, 0, 0, 0, 0, 1)" },
        .{ "scale3d(2, 3, -4) translate3d(5px, 6px, 7px)", "matrix3d(2, 0, 0, 0, 0, 3, 0, 0, 0, 0, -4, 0, 10, 18, -28, 1)" },
        .{ "translate3d(5px, 6px, 7px) scale3d(2, 3, -4)", "matrix3d(2, 0, 0, 0, 0, 3, 0, 0, 0, 0, -4, 0, 5, 6, 7, 1)" },
    }) |case| try h.check(allocator, "transform", case[0], case[1], true);
}

fn displayCase(allocator: h.Allocator, mode: []const u8, input: []const u8, ordinary: []const u8) !void {
    const suppressed = std.mem.eql(u8, mode, "suppressed");
    var parent_block = h.Block.init(allocator);
    defer parent_block.deinit();
    _ = try parent_block.setProperty(.{ .allocator = allocator }, "display", if (suppressed) "none" else "block", "");
    const parent = try h.compute(allocator, &parent_block, null);
    defer parent.destroy();
    var block = h.Block.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "display", if (suppressed) "block" else mode, "");
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "transform", input, ""));
    try h.specified(&block, "transform", input, allocator);
    const style = try h.compute(allocator, &block, parent);
    defer style.destroy();
    try testing.expect(style.get(.transform) == .transform_list);
    var before: std.ArrayList(u8) = .empty;
    defer before.deinit(allocator);
    try css.properties.serializeValue(.transform, style.get(.transform), &before, allocator);
    const expected = if (std.mem.eql(u8, mode, "none")) "none" else ordinary;
    try h.expect(style, "transform", expected, allocator);
    var after: std.ArrayList(u8) = .empty;
    defer after.deinit(allocator);
    try css.properties.serializeValue(.transform, style.get(.transform), &after, allocator);
    try testing.expectEqualStrings(before.items, after.items);
}

test "own display none resolves transform to none while keeping its stored list" {
    // Q55 Chrome+Safari majority, despite Transforms 1 section 3.2 having
    // no box condition. Only the element's OWN none is covered by the probe.
    try displayCase(testing.allocator, "none", "scale(2) scale(3)", "matrix(6, 0, 0, 6, 0, 0)");
    try displayCase(testing.allocator, "none", "translateX(25%)", "translateX(25%)");
}

test "transform display guard leaves contents and ancestor suppression unchanged" {
    // Contents and suppressed descendants were not probed. These pin the
    // draft's existing path; they do not claim measured browser agreement.
    inline for (.{ "block", "inline", "contents", "suppressed" }) |mode| {
        try displayCase(testing.allocator, mode, "scale(2) scale(3)", "matrix(6, 0, 0, 6, 0, 0)");
        try displayCase(testing.allocator, mode, "translateX(25%)", "translateX(25%)");
    }
}

test "transform nonfinite and own display none paths release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: h.Allocator) !void {
    inline for (finite_overflow_cases) |case|
        try h.check(allocator, "transform", case[0], case[1], true);
    try hugeFinite(allocator);
    try finiteCases(allocator);
    try h.check(allocator, "transform", "scale(-1e308) scale(2)", "matrix(-infinity, 0, 0, -infinity, 0, 0)", true);
    try h.check(allocator, "transform", "scale(1e200) scale(1e200) scale(0)", "matrix(NaN, 0, 0, NaN, 0, 0)", true);
    try h.check(allocator, "transform", "scale3d(1e308, 1, 2) scale3d(2, 1, 1)", "matrix3d(infinity, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 0, 1)", true);
    try displayCase(allocator, "none", "scale(2) scale(3)", "matrix(6, 0, 0, 6, 0, 0)");
    try displayCase(allocator, "none", "translateX(25%)", "translateX(25%)");
    try displayCase(allocator, "contents", "scale(2) scale(3)", "matrix(6, 0, 0, 6, 0, 0)");
}
