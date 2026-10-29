//! Q71: measure before editing the shared parser; later pin both literals.
const std = @import("std");
const css = @import("css");

test "native input keeps default parser state empty and bounds its storage cost" {
    // The RED log supplies the BASE sizes before NativeInput exists. Replace
    // these sentinels ONLY with that measured pair before installing it.
    const base_stream: usize = 144;
    const base_options: usize = 96;
    std.debug.print("om1 parser layout: Stream={d} ParseOptions={d} pointer={d}\n", .{ @sizeOf(css.properties.Stream), @sizeOf(css.properties.ParseOptions), @sizeOf(usize) });
    if (comptime !@hasField(css.properties.Stream, "native_input")) return std.testing.expect(false);
    const stream = css.properties.Stream.init("");
    try std.testing.expect(stream.native_input == null);
    try std.testing.expect(@sizeOf(css.properties.Stream) <= base_stream + @sizeOf(usize));
    try std.testing.expectEqual(base_options, @sizeOf(css.properties.ParseOptions));
}
