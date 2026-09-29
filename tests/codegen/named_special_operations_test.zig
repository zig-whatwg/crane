//! A special operation declared with an identifier is also a regular one.
//!
//! WebIDL 2.5.3 (Special operations): "If an operation has an identifier,
//! then it is a regular operation" as well as a special one - `getter
//! DOMString? getItem(DOMString key)` is both Storage's named property getter
//! and `Storage.prototype.getItem`. The method tables took named getters and
//! setters but not deleters, so Storage's `deleter undefined
//! removeItem(DOMString key)` (html.idl) never became a method, and
//! `localStorage.removeItem` was undefined.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

var no_args = [_]types.Argument{};
var key_arg = [_]types.Argument{.{ .name = "key", .idlType = .{ .type = "DOMString" } }};
var index_arg = [_]types.Argument{.{ .name = "index", .idlType = .{ .type = "unsigned long" } }};
var key_value_args = [_]types.Argument{
    .{ .name = "key", .idlType = .{ .type = "DOMString" } },
    .{ .name = "value", .idlType = .{ .type = "DOMString" } },
};

/// Storage, as html.idl declares it, plus an unnamed getter, which is special
/// only.
const ops = [_]types.Operation{
    .{ .name = "key", .idlType = .{ .type = "DOMString", .nullable = true }, .arguments = &index_arg },
    .{ .name = "getItem", .idlType = .{ .type = "DOMString", .nullable = true }, .arguments = &key_arg, .special = .getter },
    .{ .name = "setItem", .idlType = .{ .type = "undefined" }, .arguments = &key_value_args, .special = .setter },
    .{ .name = "removeItem", .idlType = .{ .type = "undefined" }, .arguments = &key_arg, .special = .deleter },
    .{ .name = "clear", .idlType = .{ .type = "undefined" }, .arguments = &no_args },
    .{ .name = null, .idlType = .{ .type = "DOMString", .nullable = true }, .arguments = &index_arg, .special = .getter },
};

/// The text of `pub const <name> = .{ ... };` in `output`.
fn table(output: []const u8, name: []const u8) ![]const u8 {
    var header_buf: [128]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buf, "pub const {s} = .{{", .{name});
    const start = std.mem.indexOf(u8, output, header) orelse return error.TableMissing;
    const end = std.mem.indexOfPos(u8, output, start, "};") orelse return error.TableUnterminated;
    return output[start..end];
}

test "a named deleter is a method, like a named getter and setter" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeMetadata(&buffer.writer, "Storage", null, null, true, &.{}, &.{}, &.{}, &ops, &ops, &.{}, false, false, false, null, &.{}, null, &ops);
    const output = buffer.written();

    const methods = try table(output, "methods");
    try testing.expect(std.mem.indexOf(u8, methods, ".{ \"getItem\", \"call_getItem\", 1 }") != null);
    try testing.expect(std.mem.indexOf(u8, methods, ".{ \"setItem\", \"call_setItem\", 2 }") != null);
    try testing.expect(std.mem.indexOf(u8, methods, ".{ \"removeItem\", \"call_removeItem\", 1 }") != null);
    try testing.expect(std.mem.indexOf(u8, methods, ".{ \"clear\", \"call_clear\", 0 }") != null);

    const own = try table(output, "own_methods");
    try testing.expect(std.mem.indexOf(u8, own, "\"removeItem\"") != null);
}

test "a named deleter a parent declares is inherited, not own" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    // The child declares only `clear`; the parent's operations come in `all_operations`.
    try writer.writeMetadata(&buffer.writer, "Child", null, "Storage", true, &.{}, &.{}, &.{}, &ops, ops[4..5], &.{}, false, false, false, null, &.{}, null, ops[4..5]);
    const output = buffer.written();
    const inherited = try table(output, "inherited_methods");
    try testing.expect(std.mem.indexOf(u8, inherited, "\"removeItem\"") != null);
    try testing.expect(std.mem.indexOf(u8, try table(output, "methods"), "removeItem") == null);
}
