//! Every attribute is a real accessor on the interface prototype.
//!
//! WebIDL 3.7.6: an attribute is an accessor property on the interface
//! prototype object. `Meta.lazy_properties` was served instead by a named
//! property interceptor on the prototype template, which V8 does not treat as
//! an accessor: it calls a named SETTER interceptor only when the interceptor's
//! holder is the receiver (objects.cc, Object::SetPropertyInternal,
//! LookupIterator::INTERCEPTOR). For an instance the holder is its prototype,
//! so `div.lang = "x"` asked the getter whether `lang` existed and then stored
//! an own data property on the element - the setter never ran, the content
//! attribute never changed, and every later read returned the stored value.
//! `Object.getOwnPropertyDescriptor(HTMLElement.prototype, "offsetWidth")` ran
//! the getter on the prototype itself and threw. So nothing is lazy.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

const attrs = [_]types.Attribute{
    .{ .name = "lang", .idlType = .{ .type = "DOMString" } },
    .{ .name = "tabIndex", .idlType = .{ .type = "long" } },
    .{ .name = "offsetWidth", .idlType = .{ .type = "long" }, .readonly = true },
    .{ .name = "dataset", .idlType = .{ .type = "DOMStringMap" }, .readonly = true },
    .{ .name = "title", .idlType = .{ .type = "DOMString" } },
};

/// The text of `pub const <name> = .{ ... };` in `output`.
fn table(output: []const u8, name: []const u8) ![]const u8 {
    var header_buf: [128]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buf, "pub const {s} = .{{", .{name});
    const start = std.mem.indexOf(u8, output, header) orelse return error.TableMissing;
    const end = std.mem.indexOfPos(u8, output, start, "};") orelse return error.TableUnterminated;
    return output[start..end];
}

test "writable and read-only attributes alike are eager; nothing is lazy" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeMetadata(&buffer.writer, "HTMLElement", null, null, true, &.{}, &.{}, &attrs, &.{}, &.{}, &.{}, true, false, false, null, &attrs, null, &.{});
    const output = buffer.written();

    const eager = try table(output, "eager_properties");
    try testing.expect(std.mem.indexOf(u8, eager, ".{ \"lang\", \"get_lang\", \"set_lang\" }") != null);
    try testing.expect(std.mem.indexOf(u8, eager, ".{ \"tabIndex\", \"get_tabIndex\", \"set_tabIndex\" }") != null);
    try testing.expect(std.mem.indexOf(u8, eager, ".{ \"offsetWidth\", \"get_offsetWidth\", null }") != null);
    try testing.expect(std.mem.indexOf(u8, eager, ".{ \"dataset\", \"get_dataset\", null }") != null);
    try testing.expect(std.mem.indexOf(u8, eager, ".{ \"title\", \"get_title\", \"set_title\" }") != null);

    const lazy = try table(output, "lazy_properties");
    try testing.expect(std.mem.indexOf(u8, lazy, "get_") == null);
}
