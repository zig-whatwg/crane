//! A generated enum carries its exact IDL values.
//!
//! An enumeration value is any string; the Zig variant is a mangled
//! identifier (`"back_forward"` and `"back-forward"` would both be
//! `_back_forward_`). The binding used to recover the string from the
//! variant name, turning every `_` into `-`, so script read
//! PerformanceNavigationTiming.type as "back-forward", and accepted
//! "back-forward" for a value that is spelled "back_forward". Codegen now
//! writes `idl_values`, variant i's IDL string at index i, and the binding
//! reads it in both directions.

const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "an enum's value table holds each value exactly as the IDL spells it" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const file = try codegen.idl_parser.Parser.parse(a,
        \\enum NavigationTimingType { "navigate", "reload", "back_forward" };
        \\enum Odd { "", "same-origin", "image/svg+xml" };
    );

    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    for (file.enums) |e| try codegen.generator.writeEnum(&buffer.writer, e);
    const out = buffer.written();

    // The variants are unchanged: impls name them.
    try testing.expect(contains(out, "    _back_forward_,\n"));
    try testing.expect(contains(out, "    __,\n"));
    try testing.expect(contains(out, "    _image_svg_xml_,\n"));
    // Index i is variant i's value.
    try testing.expect(contains(out, "pub const idl_values = [_][]const u8{ \"navigate\", \"reload\", \"back_forward\" };"));
    try testing.expect(contains(out, "pub const idl_values = [_][]const u8{ \"\", \"same-origin\", \"image/svg+xml\" };"));
}
