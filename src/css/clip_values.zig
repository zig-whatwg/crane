//! CSS Masking 1 Appendix A: the deprecated clip property's rect().
//!
//! rect( <top>, <right>, <bottom>, <left> ), each a <length> or auto. "User
//! agents must support separation with commas, but may also support
//! separation without commas (but not a combination)": all three browsers
//! take both forms (Blink ConsumeClipComponent, Gecko ClipRectOrAuto), and
//! serialize with commas. The computed value holds the four offsets with
//! lengths made absolute - CSS 2.1 §11.1.2's "for rectangle values, a
//! rectangle consisting of four computed lengths", which all three
//! browsers return (css/css-masking/parsing/clip-computed.html 4/4 each,
//! wpt.fyi 2026-11-11) over Masking 1's "as specified" (golden rule 2).
//!
//! The rectangle is a text_values.Components list of four, so it computes
//! and combines component by component.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const Components = @import("text_values.zig").Components;
const Allocator = std.mem.Allocator;
const Value = values.Value;

/// rect() after `clip: auto` was ruled out. `quirky`: Values 4 Appendix C
/// allows a <quirky-length> inside clip's rect() in quirks mode.
pub fn parse(options: properties.ParseOptions, stream: *properties.Stream, quirky: bool) Allocator.Error!?Value {
    const token = stream.peek();
    if (token.token_type != .function or !tokenizer.nameEql(token.value, "rect")) return null;
    _ = stream.next();
    if (stream.next().token_type != .left_paren) return null;
    var sides: [4]Value = undefined;
    var count: usize = 0;
    defer for (sides[0..count]) |side| side.release();
    var commas: ?bool = null;
    while (count < 4) : (count += 1) {
        if (count > 0) {
            const comma = stream.peek().token_type == .comma;
            // Commas between all four offsets, or between none.
            if (commas) |expected| {
                if (comma != expected) return null;
            } else commas = comma;
            if (comma) _ = stream.next();
        }
        sides[count] = (try offset(options, stream, quirky)) orelse return null;
    }
    if (stream.next().token_type != .right_paren) return null;
    return .{ .text_values = try Components.create(options.allocator, .clip, &sides) };
}

/// <length> | auto; negative lengths are permitted.
fn offset(options: properties.ParseOptions, stream: *properties.Stream, quirky: bool) Allocator.Error!?Value {
    const token = stream.peek();
    if (token.token_type == .ident and tokenizer.nameEql(token.value, "auto")) {
        _ = stream.next();
        return Value.kw(.auto);
    }
    return properties.lengthPercentage(options, stream, .{ .negative = true, .percent = false, .quirky = quirky });
}

/// `rect(top, right, bottom, left)`, each offset serialized as a length or
/// auto.
pub fn serialize(sides: []const Value, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try out.appendSlice(allocator, "rect(");
    for (sides, 0..) |side, i| {
        if (i > 0) try out.appendSlice(allocator, ", ");
        try properties.serializeValue(.clip, side, out, allocator);
    }
    try out.append(allocator, ')');
}
