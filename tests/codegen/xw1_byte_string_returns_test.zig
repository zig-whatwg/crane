//! ByteString return conversion must be selected by IDL metadata, not []const u8.
const std = @import("std");
const codegen = @import("codegen");
const testing = std.testing;
const types = codegen.types;

fn returns(idl: []const u8, out: *std.Io.Writer.Allocating) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const file = try codegen.idl_parser.Parser.parse(a, idl);
    var model = try codegen.ir.IR.init(a);
    for (file.typedefs) |t| try model.addTypedef(t, "test.idl");
    for (file.interfaces) |i| try model.addInterface(i, "test.idl");
    try model.finish();
    var attrs: std.ArrayList(types.Attribute) = .empty;
    var ops: std.ArrayList(types.Operation) = .empty;
    for (file.interfaces[0].members) |m| {
        if (m.attribute) |v| try attrs.append(a, v);
        if (m.operation) |v| try ops.append(a, v);
    }
    try codegen.writer.writeDelegateFunctions(&out.writer, "WireImpl", null, attrs.items, ops.items, ops.items, .{ .model = &model });
}

test "xw1 ByteString results identify getters, statics, aliases and nullable overloads" {
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try returns(
        \\typedef ByteString Octets;
        \\interface Wire {
        \\  readonly attribute ByteString value;
        \\  static readonly attribute Octets? optionalValue;
        \\  ByteString? read();
        \\  Octets read(long index);
        \\  static Octets stat();
        \\  USVString text();
        \\};
    , &out);
    const start = std.mem.indexOf(u8, out.written(), "pub const byte_string_returns = .{") orelse return error.ResultMetadataMissing;
    const end = std.mem.indexOfPos(u8, out.written(), start, "};").?;
    const table = out.written()[start..end];
    for ([_][]const u8{ "\"get_value\"", "\"get_static_optionalValue\"", "\"call_read\"", "\"call_read__1\"", "\"call_static_stat\"" }) |name| {
        try testing.expect(std.mem.indexOf(u8, table, name) != null);
    }
    try testing.expect(std.mem.indexOf(u8, table, "call_text") == null);
}

test "xw1 other return types do not acquire ByteString conversion by default" {
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try returns("interface Text { readonly attribute USVString value; DOMString text(); long count(); };", &out);
    try testing.expect(std.mem.indexOf(u8, out.written(), "byte_string_returns") == null);
}

test "xw1 anonymous special getters retain their ByteString return metadata" {
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try returns("interface Wire { getter ByteString (unsigned long index); getter ByteString? (DOMString name); };", &out);
    const start = std.mem.indexOf(u8, out.written(), "pub const byte_string_returns = .{") orelse return error.ResultMetadataMissing;
    const end = std.mem.indexOfPos(u8, out.written(), start, "};").?;
    const table = out.written()[start..end];
    try testing.expect(std.mem.indexOf(u8, table, "\"call_getter\"") != null);
    try testing.expect(std.mem.indexOf(u8, table, "\"call_getter__1\"") != null);
}
