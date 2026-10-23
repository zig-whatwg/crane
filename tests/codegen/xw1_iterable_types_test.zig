//! Pair metadata follows the IDL's key, value order, including async pairs.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;

fn check(idl: []const u8, key: ?[]const u8, value: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(), idl);
    const iface = file.interfaces[0];
    const member = iface.members[0];
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try codegen.writer.writeMetadata(&out.writer, "Items", null, null, true, &.{}, &.{}, &.{}, &.{}, &.{}, &.{}, false, false, false, member.iterable, &.{}, member.async_iterable, &.{}, null, null);
    const expected_value = try std.fmt.allocPrint(testing.allocator, ".value_type = \"{s}\"", .{value});
    defer testing.allocator.free(expected_value);
    try testing.expect(std.mem.indexOf(u8, out.written(), expected_value) != null);
    const expected_key = if (key) |k| try std.fmt.allocPrint(testing.allocator, ".key_type = \"{s}\"", .{k}) else try testing.allocator.dupe(u8, ".key_type = null");
    defer testing.allocator.free(expected_key);
    try testing.expect(std.mem.indexOf(u8, out.written(), expected_key) != null);
}

test "xw1 pair iterable key and value types are not exchanged" {
    try check("interface Items { iterable<ByteString, USVString>; };", "runtime.ByteString", "runtime.USVString");
    try check("interface Items { iterable<USVString, ByteString>; };", "runtime.USVString", "runtime.ByteString");
}

test "xw1 single iterable has a value and no key type" {
    try check("interface Items { iterable<ByteString>; };", null, "runtime.ByteString");
}

test "xw1 async pair iterable key and value types are not exchanged" {
    try check("interface Items { async iterable<ByteString, USVString>; };", "runtime.ByteString", "runtime.USVString");
    try check("interface Items { async iterable<USVString, ByteString>; };", "runtime.USVString", "runtime.ByteString");
}

test "xw1 single async iterable has a value and no key type" {
    try check("interface Items { async iterable<ByteString>; };", null, "runtime.ByteString");
}
