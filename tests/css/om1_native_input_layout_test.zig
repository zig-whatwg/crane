//! Q71: the parser's Stream and ParseOptions sizes with NativeInput, against the sizes before it.
const std = @import("std");
const css = @import("css");

test "native input keeps default parser state empty and bounds its storage cost" {
    // The sizes measured before NativeInput existed.
    const base_stream: usize = 144;
    const base_options: usize = 96;
    if (comptime !@hasField(css.properties.Stream, "native_input")) return std.testing.expect(false);
    const stream = css.properties.Stream.init("");
    try std.testing.expect(stream.native_input == null);
    try std.testing.expect(@sizeOf(css.properties.Stream) <= base_stream + @sizeOf(usize));
    try std.testing.expectEqual(base_options, @sizeOf(css.properties.ParseOptions));
}
