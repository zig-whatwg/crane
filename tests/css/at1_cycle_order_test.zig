//! attr-cycle.html cases 26 and 27: custom-property computation order must
//! not turn a raw attribute read into a cycle in another custom property.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Attributes = struct {
    foo: []const u8,
    bar: []const u8,

    fn get(context: *const anyopaque, name: []const u8) ?[]const u8 {
        const self: *const Attributes = @ptrCast(@alignCast(context));
        if (std.mem.eql(u8, name, "data-foo")) return self.foo;
        if (std.mem.eql(u8, name, "data-bar")) return self.bar;
        return null;
    }
};

fn checkOrder(comptime raw: []const u8, comptime typed: []const u8) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, raw ++ ":attr(data-foo);" ++ typed ++ ":attr(data-foo type(*))");
    defer block.deinit();
    const attributes: Attributes = .{
        .foo = "attr(data-bar, 11) var(" ++ raw ++ ", 3)",
        .bar = "var(" ++ raw ++ ")",
    };
    const style = try css.cascade.cascade(.{
        .allocator = testing.allocator,
        .parent = null,
        .is_root = true,
        .content_attributes = .{ .context = &attributes, .get = Attributes.get },
    }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const value = style.customValue(typed);
    try testing.expect(value != null);
    try testing.expectEqualStrings("\"var(" ++ raw ++ ")\" \"attr(data-bar, 11) var(" ++ raw ++ ", 3)\"", value.?.bytes);
    const raw_value = style.customValue(raw);
    try testing.expect(raw_value != null);
    try testing.expectEqualStrings("\"attr(data-bar, 11) var(" ++ raw ++ ", 3)\"", raw_value.?.bytes);
}

test "attr cycle order: the typed property sorts before its raw dependency" {
    try checkOrder("--y", "--x");
}

test "attr cycle order: the raw dependency sorts before the typed property" {
    try checkOrder("--x", "--y");
}
