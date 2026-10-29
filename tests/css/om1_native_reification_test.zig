//! Q60 singleton matrix, with Q62's background-size amendment and Q63.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Case = struct { property: []const u8, input: []const u8, class: []const u8, text: []const u8 };
const cases = [_]Case{
    .{ .property = "align-content", .input = "space-between", .class = "CSSKeywordValue", .text = "space-between" },
    .{ .property = "align-items", .input = "first baseline", .class = "CSSKeywordValue", .text = "baseline" },
    .{ .property = "align-items", .input = "safe center", .class = "CSSStyleValue", .text = "safe center" },
    .{ .property = "display", .input = "inline flow-root", .class = "CSSKeywordValue", .text = "inline-block" },
    .{ .property = "display", .input = "block ruby", .class = "CSSStyleValue", .text = "block ruby" },
    .{ .property = "display", .input = "flex", .class = "CSSKeywordValue", .text = "flex" },
    .{ .property = "background-size", .input = "10px", .class = "CSSStyleValue", .text = "10px auto" },
    .{ .property = "background-size", .input = "10px auto", .class = "CSSStyleValue", .text = "10px auto" },
    .{ .property = "background-size", .input = "10px 20px", .class = "CSSStyleValue", .text = "10px 20px" },
    .{ .property = "border-top-left-radius", .input = "10px", .class = "CSSUnitValue", .text = "10px" },
    .{ .property = "border-top-left-radius", .input = "10px 10px", .class = "CSSUnitValue", .text = "10px" },
    .{ .property = "border-top-left-radius", .input = "10px 20px", .class = "CSSStyleValue", .text = "10px 20px" },
    .{ .property = "grid-row-start", .input = "foo", .class = "CSSKeywordValue", .text = "foo" },
    .{ .property = "grid-row-start", .input = "2", .class = "CSSStyleValue", .text = "2" },
    .{ .property = "grid-row-start", .input = "span 2", .class = "CSSStyleValue", .text = "span 2" },
    .{ .property = "grid-auto-flow", .input = "row", .class = "CSSKeywordValue", .text = "row" },
    .{ .property = "grid-auto-flow", .input = "row dense", .class = "CSSKeywordValue", .text = "dense" },
    .{ .property = "contain", .input = "layout", .class = "CSSKeywordValue", .text = "layout" },
    .{ .property = "contain", .input = "strict", .class = "CSSKeywordValue", .text = "strict" },
    .{ .property = "contain", .input = "layout paint", .class = "CSSStyleValue", .text = "layout paint" },
    .{ .property = "font-family", .input = "serif", .class = "CSSStyleValue", .text = "serif" },
    .{ .property = "text-transform", .input = "uppercase", .class = "CSSKeywordValue", .text = "uppercase" },
    .{ .property = "text-transform", .input = "uppercase full-width", .class = "CSSStyleValue", .text = "uppercase full-width" },
    .{ .property = "color", .input = "currentcolor", .class = "CSSKeywordValue", .text = "currentcolor" },
    .{ .property = "color", .input = "red", .class = "CSSStyleValue", .text = "red" },
    .{ .property = "font-weight", .input = "normal", .class = "CSSKeywordValue", .text = "normal" },
    .{ .property = "font-weight", .input = "700", .class = "CSSUnitValue", .text = "700" },
};

fn check(allocator: std.mem.Allocator, case: Case) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "native_reification")) return std.testing.expect(false);
    const property = (css.properties.lookup(case.property) orelse return error.MissingProperty);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, case.input, &assignments));
    const value = assignments.items[0].value.value;
    const shape = css.typed_om.native_reification.shape(property.longhand, value);
    const class: []const u8 = switch (shape) {
        .keyword, .canonical_keyword => "CSSKeywordValue",
        .numeric => "CSSUnitValue",
        .calculation => "CSSNumericValue",
        .image => "CSSImageValue",
        .pending => "CSSUnparsedValue",
        else => "CSSStyleValue",
    };
    try std.testing.expectEqualStrings(case.class, class);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    switch (shape) {
        .keyword => |keyword| {
            const escaped = try css.serialize.serializeIdentifier(allocator, keyword);
            defer allocator.free(escaped);
            try text.appendSlice(allocator, escaped);
        },
        .numeric => |number| {
            const serialized = try css.typed_om.numeric.serialize(allocator, number);
            defer allocator.free(serialized);
            try text.appendSlice(allocator, serialized);
        },
        else => try css.properties.serializeValue(property.longhand, value, &text, allocator),
    }
    try std.testing.expectEqualStrings(case.text, text.items);
}

test "native Typed OM singleton matrix follows Q60 Q62 and existing CSSOM canonical forms" {
    for (cases) |case| try check(a, case);
}

test "native Typed OM shape classification and serialization clean up on every allocation failure" {
    for (cases) |case| try std.testing.checkAllAllocationFailures(a, check, .{case});
}

test "KNOWN-INCOMPLETE Q32 transform and position subclasses retain native values until routed family lands" {
    // Explicitly pin the interim fallback so the missing hierarchy is not
    // confused with a completed transform/position implementation.
    // Q103: translate already owns Value.transform at BASE. The transform
    // longhand itself remains row125's post-named-main WPT dependency.
    try check(a, .{ .property = "translate", .input = "2px", .class = "CSSStyleValue", .text = "2px" });
    try check(a, .{ .property = "object-position", .input = "10px 20px", .class = "CSSStyleValue", .text = "10px 20px" });
}
