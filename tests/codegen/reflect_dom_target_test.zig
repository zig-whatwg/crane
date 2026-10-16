//! A generated reflection default calls the DOM algorithm, not an impl helper.
//! The impl may still override each accessor independently.
const std = @import("std");
const codegen = @import("codegen");

test "reflection default reaches the DOM module and keeps independent impl overrides" {
    const allocator = std.testing.allocator;
    var extended_attributes = [_]codegen.types.ExtendedAttribute{
        .{ .name = "CEReactions" },
        .{ .name = "Reflect" },
    };
    const attributes = [_]codegen.types.Attribute{.{
        .name = "title",
        .idlType = .{ .type = "DOMString" },
        .extAttrs = &extended_attributes,
    }};
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    try codegen.writer.writeDelegateFunctions(&output.writer, "ElementImpl", null, &attributes, &.{}, &.{}, .{
        .reflect_on_element = true,
    });

    const text = output.written();
    try std.testing.expect(std.mem.indexOf(u8, text, "const reflection = @import(\"dom\").reflection;") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "@import(\"impls\").reflection") == null);
    try std.testing.expect(std.mem.indexOf(u8, text, "if (comptime @hasDecl(ElementImpl, \"get_title\")) return try ElementImpl.get_title(instance);") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "if (comptime @hasDecl(ElementImpl, \"set_title\")) return try ElementImpl.set_title(instance, value);") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "runtime.CEReactions.begin(instance);") != null);
}
