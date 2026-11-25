//! Lane cs1: a ComputedStyle counts its holders (ComputedStyle.refs) - its
//! owner and each caller reading it now (dom.style.HeldStyle) - in the one
//! spare byte of the word its narrow fields share, and the last holder's
//! release frees it.

const std = @import("std");
const css = @import("css");
const testing = std.testing;

const ComputedStyle = css.computed_style.ComputedStyle;

test "a style outlives its owner's release while another holder reads it; the last release frees it" {
    const style = try ComputedStyle.initial(testing.allocator);
    try testing.expectEqual(@as(u8, 1), style.refs);
    try testing.expect(style.retain());
    try testing.expectEqual(@as(u8, 2), style.refs);
    // The owner lets go (an element's cache replacing it): the reader's
    // reference keeps it (std.testing.allocator poisons what it frees).
    style.release();
    try testing.expectEqual(@as(u8, 1), style.refs);
    try testing.expectEqual(css.style_values.Keyword.visible, style.keyword(.visibility));
    // The reader's release frees it (std.testing.allocator fails on a leak).
    style.release();
}

test "the count stops at 255: retain refuses, and a clone is a holder of its own with one reference" {
    const style = try ComputedStyle.initial(testing.allocator);
    var retained: usize = 0;
    while (style.retain()) retained += 1;
    try testing.expectEqual(@as(usize, 254), retained);
    try testing.expectEqual(@as(u8, 255), style.refs);
    const copy = try style.clone(testing.allocator);
    try testing.expectEqual(@as(u8, 1), copy.refs);
    copy.destroy();
    for (0..retained) |_| style.release();
    // The owner alone again: destroy, the sole holder's end.
    style.destroy();
}

test "the hold count costs a style no bytes: the fields narrower than a word still share one" {
    var narrow: usize = 0;
    inline for (@typeInfo(ComputedStyle).@"struct".field_types) |T| {
        if (@sizeOf(T) < 8) narrow += @sizeOf(T);
    }
    std.debug.print("CS1_STYLE_NARROW_FIELDS {d} B, ComputedStyle {d} B\n", .{ narrow, @sizeOf(ComputedStyle) });
    try testing.expect(narrow <= 8);
    try testing.expectEqual(@as(usize, 1), @sizeOf(@FieldType(ComputedStyle, "refs")));
}
