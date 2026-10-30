//! Lane gaps1: Value's size, pinned before Value.gap_list exists (main
//! 859133127b3 prints Value=32 in CF2_STYLE_LAYOUT). A gap decoration list
//! is a pointer payload, so adding it must not grow every stored value.
const std = @import("std");
const css = @import("css");

test "a style value stays 32 bytes" {
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(css.style_values.Value));
}
