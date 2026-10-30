//! Q179: shipper-specific Typed OM classes for the named-main box values.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Class = enum { keyword, numeric, style_value };
const Case = struct {
    property: []const u8,
    input: []const u8,
    class: Class,
    text: ?[]const u8 = null,
};

fn check(case: Case) !void {
    const allocator = testing.allocator;
    const property = css.properties.lookup(case.property) orelse return error.MissingProperty;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, case.input, &assignments));
    try testing.expectEqual(@as(usize, 1), assignments.items.len);
    const value = assignments.items[0].value.value;
    const shape = css.typed_om.native_reification.shape(property.longhand, value);
    switch (case.class) {
        .keyword => {
            try testing.expect(shape == .keyword);
            try testing.expectEqualStrings(case.text.?, shape.keyword);
        },
        .numeric => {
            try testing.expect(shape == .numeric);
            try testing.expectEqual(@as(f64, 3), shape.numeric.value);
            try testing.expectEqual(css.math_values.Unit.number, shape.numeric.unit);
        },
        .style_value => try testing.expect(shape == .unsupported),
    }
    var serialized: std.ArrayList(u8) = .empty;
    defer serialized.deinit(allocator);
    try css.properties.serializeValue(property.longhand, value, &serialized, allocator);
    if (case.text) |expected| try testing.expectEqualStrings(expected, serialized.items);
    // The calc control checks its owning parser and retained opaque shape;
    // parsing/serialization are not changed by this reification family.
    try testing.expect(serialized.items.len != 0);
}

// Q179 probe, 2026-10-29: Chrome 156 is the sole shipper (3/3).
// Typed OM §5.5 and Q60 step 1: native singletons are keywords, pairs opaque.
test "Q179 scroll-marker-group none is a keyword" {
    try check(.{ .property = "scroll-marker-group", .input = "none", .class = .keyword, .text = "none" });
}

test "Q179 scroll-marker-group before is a keyword" {
    try check(.{ .property = "scroll-marker-group", .input = "before", .class = .keyword, .text = "before" });
}

test "Q179 scroll-marker-group after is a keyword" {
    try check(.{ .property = "scroll-marker-group", .input = "after", .class = .keyword, .text = "after" });
}

test "Q179 scroll-marker-group before links is opaque" {
    try check(.{ .property = "scroll-marker-group", .input = "before links", .class = .style_value, .text = "before links" });
}

// Q179 / Q60 step 1: overflow-clip-margin is always opaque in Chrome,
// even when the existing serializer emits one number or one identifier.
test "Q179 overflow-clip-margin scalar stays opaque" {
    try check(.{ .property = "overflow-clip-margin", .input = "5px", .class = .style_value, .text = "5px" });
}

test "Q179 overflow-clip-margin default box stays opaque" {
    try check(.{ .property = "overflow-clip-margin", .input = "padding-box 5px", .class = .style_value, .text = "5px" });
}

test "Q179 overflow-clip-margin content box singleton stays opaque" {
    try check(.{ .property = "overflow-clip-margin", .input = "content-box 0px", .class = .style_value, .text = "content-box" });
}

test "Q179 overflow-clip-margin border box singleton stays opaque" {
    try check(.{ .property = "overflow-clip-margin", .input = "border-box 0px", .class = .style_value, .text = "border-box" });
}

test "Q179 overflow-clip-margin compound stays opaque" {
    try check(.{ .property = "overflow-clip-margin", .input = "content-box 5px", .class = .style_value, .text = "content-box 5px" });
}

test "Q179 overflow-clip-margin existing calc representation stays opaque" {
    try check(.{ .property = "overflow-clip-margin", .input = "calc(1px + 2px)", .class = .style_value });
}

// Q179: nobody ships max-lines. Apply Q60's singleton principle using
// the existing parsed integer/keyword and retain a compound per §5.2.
test "Q179 max-lines integer is numeric" {
    try check(.{ .property = "max-lines", .input = "3", .class = .numeric, .text = "3" });
}

test "Q179 max-lines auto is a keyword" {
    try check(.{ .property = "max-lines", .input = "auto", .class = .keyword, .text = "auto" });
}

test "Q179 max-lines integer with auto is opaque" {
    try check(.{ .property = "max-lines", .input = "3 auto", .class = .style_value, .text = "3 auto" });
}

test "Q180 initial overflow-clip-margin is opaque regardless of its native representation" {
    const allocator = testing.allocator;
    const style = try css.computed_style.ComputedStyle.initial(allocator);
    defer style.destroy();
    const value = style.get(.overflow_clip_margin);
    try testing.expect(css.typed_om.native_reification.shape(.overflow_clip_margin, value) == .unsupported);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try css.properties.serializeValue(.overflow_clip_margin, value, &text, allocator);
    try testing.expectEqualStrings("0px", text.items);
}

test "Q180 overflow-clip-margin pending values keep the section 5.3 reification priority" {
    const allocator = testing.allocator;
    const pending = (try css.pending_values.Pending.create(.{ .allocator = allocator }, .{ .longhand = .overflow_clip_margin }, "var(--gap)")) orelse return error.TestUnexpectedResult;
    defer pending.unref();
    const value = css.style_values.Value{ .pending = pending };
    const shape = css.typed_om.native_reification.shape(.overflow_clip_margin, value);
    try testing.expect(shape == .pending);
    try testing.expect(shape.pending == pending);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try css.properties.serializeValue(.overflow_clip_margin, value, &text, allocator);
    try testing.expectEqualStrings("var(--gap)", text.items);
}
