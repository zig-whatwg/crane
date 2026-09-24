//! Static attributes are named and bound as static.
//!
//! WebIDL §3.7.6 puts a static attribute on the interface object, not the
//! interface prototype object. The generated names are the map an impl is
//! found by, so a static attribute's are `get_static_<name>` and
//! `set_static_<name>` - as a static operation's is `call_static_<op>` - and
//! it is bound through `Meta.static_properties`, never `Meta.properties`.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

const attrs = [_]types.Attribute{
    .{ .name = "permission", .idlType = .{ .type = "DOMString" }, .readonly = true, .static = true, .extAttrs = &.{} },
    .{ .name = "limit", .idlType = .{ .type = "unsigned long" }, .readonly = false, .static = true, .extAttrs = &.{} },
    .{ .name = "title", .idlType = .{ .type = "DOMString" }, .readonly = true, .extAttrs = &.{} },
};

/// The text of `pub const <name> = .{ ... };` in `output`.
fn table(output: []const u8, name: []const u8) ![]const u8 {
    var header_buf: [128]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buf, "pub const {s} = .{{", .{name});
    const start = std.mem.indexOf(u8, output, header) orelse return error.TableMissing;
    const end = std.mem.indexOfPos(u8, output, start, "};") orelse return error.TableUnterminated;
    return output[start..end];
}

fn metadata(buffer: *std.Io.Writer.Allocating) !void {
    try writer.writeMetadata(&buffer.writer, "Notification", null, null, true, &.{}, &.{}, &attrs, &.{}, &.{}, &.{}, true, false, false, null, &attrs, null, &.{});
}

test "a static attribute is bound through static_properties with get_static_ and set_static_" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try metadata(&buffer);
    const statics = try table(buffer.written(), "static_properties");
    try testing.expect(std.mem.indexOf(u8, statics, ".{ \"permission\", \"get_static_permission\", null }") != null);
    try testing.expect(std.mem.indexOf(u8, statics, ".{ \"limit\", \"get_static_limit\", \"set_static_limit\" }") != null);
    try testing.expect(std.mem.indexOf(u8, statics, "\"title\"") == null);
}

test "a static attribute is not an instance property" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try metadata(&buffer);
    const output = buffer.written();
    for ([_][]const u8{ "properties", "eager_properties", "lazy_properties" }) |name| {
        const instance_table = table(output, name) catch continue;
        try testing.expect(std.mem.indexOf(u8, instance_table, "\"permission\"") == null);
        try testing.expect(std.mem.indexOf(u8, instance_table, "\"limit\"") == null);
    }
    const properties = try table(output, "properties");
    try testing.expect(std.mem.indexOf(u8, properties, ".{ \"title\", \"get_title\", null }") != null);
}

test "a static attribute's delegates are get_static_ and set_static_" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "NotificationImpl", null, &attrs, &.{}, &.{}, .{});
    const output = buffer.written();
    try testing.expect(std.mem.indexOf(u8, output, "pub fn get_static_permission(instance: *runtime.Instance)") != null);
    try testing.expect(std.mem.indexOf(u8, output, "NotificationImpl.get_static_permission(instance)") != null);
    try testing.expect(std.mem.indexOf(u8, output, "pub fn set_static_limit(instance: *runtime.Instance") != null);
    try testing.expect(std.mem.indexOf(u8, output, "NotificationImpl.set_static_limit(instance") != null);
    try testing.expect(std.mem.indexOf(u8, output, "pub fn get_permission(") == null);
    try testing.expect(std.mem.indexOf(u8, output, "pub fn get_title(instance: *runtime.Instance)") != null);
}

test "a static attribute has no vtable entry" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeVTable(&buffer.writer, &.{}, &.{}, &attrs, &.{}, "Notification");
    const output = buffer.written();
    try testing.expect(std.mem.indexOf(u8, output, "permission") == null);
    try testing.expect(std.mem.indexOf(u8, output, "limit") == null);
    try testing.expect(std.mem.indexOf(u8, output, ".get_title = &get_title") != null);
}
