//! ByteString values are marked for the binding.
//!
//! WebIDL 3.2.11: converting to ByteString is ToString, then a TypeError when
//! any code unit is above 0xFF. Codegen maps ByteString, USVString and
//! DOMString's bytes all to `[]const u8`, so the binding cannot tell a
//! ByteString argument from a USVString one by its Zig type; codegen tells it,
//! in the shape of `restricted_floats`: per interface, `byte_string_arguments`
//! (the Zig function, bit i for argument i, bit 0 for an attribute setter's
//! value); per dictionary, `byte_string_members` (the member names). A
//! typedef of ByteString and a sequence of one are listed; a union is not -
//! its conversion picks the member type itself (HeadersInit's converter
//! converts its ByteStrings as such).

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

const Parsed = struct {
    arena: std.heap.ArenaAllocator,
    model: codegen.ir.IR,
    file: types.IDLFile,

    fn deinit(self: *Parsed) void {
        self.arena.deinit();
    }
};

fn parse(idl: []const u8) !Parsed {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    errdefer arena.deinit();
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(), idl);
    var model = try codegen.ir.IR.init(arena.allocator());
    for (file.typedefs) |t| try model.addTypedef(t, "test.idl");
    for (file.interfaces) |iface| try model.addInterface(iface, "test.idl");
    return .{ .arena = arena, .model = model, .file = file };
}

/// The delegate functions codegen writes for `idl`'s first interface.
fn delegatesOf(p: *Parsed, buffer: *std.Io.Writer.Allocating, name: []const u8) ![]const u8 {
    var attrs: std.ArrayList(types.Attribute) = .empty;
    var ops: std.ArrayList(types.Operation) = .empty;
    for (p.file.interfaces[0].members) |m| {
        if (m.asAttribute()) |a| try attrs.append(p.arena.allocator(), a);
        if (m.asOperation()) |o| try ops.append(p.arena.allocator(), o);
    }
    try writer.writeDelegateFunctions(&buffer.writer, name, null, attrs.items, ops.items, ops.items, .{ .model = &p.model });
    return buffer.written();
}

test "ByteString operation arguments and setters are listed; other strings are not" {
    var p = try parse(
        \\typedef ByteString HeaderName;
        \\interface Wire {
        \\  attribute ByteString token;
        \\  readonly attribute ByteString statusText;
        \\  attribute USVString url;
        \\  attribute ByteString? optionalToken;
        \\  undefined append(ByteString name, ByteString value);
        \\  undefined open(ByteString method, USVString url);
        \\  undefined open(ByteString method, USVString url, boolean async, optional USVString? username = null);
        \\  ByteString? get(HeaderName name);
        \\  undefined plain(DOMString a, USVString b);
        \\  undefined names(sequence<ByteString> names);
        \\  undefined either((ByteString or long) value);
        \\};
    );
    defer p.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    const out = try delegatesOf(&p, &buffer, "WireImpl");

    try testing.expect(contains(out, "pub const byte_string_arguments = .{"));
    try testing.expect(contains(out, ".{ \"set_token\", 0b1 },"));
    try testing.expect(contains(out, ".{ \"set_optionalToken\", 0b1 },"));
    try testing.expect(!contains(out, "\"set_statusText\", 0b"));
    try testing.expect(!contains(out, "\"set_url\", 0b"));
    try testing.expect(contains(out, ".{ \"call_append\", 0b11 },"));
    // Each overload by its own function: method is argument 0 in both.
    try testing.expect(contains(out, ".{ \"call_open\", 0b1 },"));
    try testing.expect(contains(out, ".{ \"call_open__1\", 0b1 },"));
    // Through the typedef, and a sequence of ByteString.
    try testing.expect(contains(out, ".{ \"call_get\", 0b1 },"));
    try testing.expect(contains(out, ".{ \"call_names\", 0b1 },"));
    try testing.expect(!contains(out, "\"call_plain\", 0b"));
    // A union picks its member type itself.
    try testing.expect(!contains(out, "\"call_either\", 0b"));
}

test "no table when nothing is a ByteString" {
    var p = try parse(
        \\interface Text { attribute USVString value; undefined write(DOMString data, optional USVString url); };
    );
    defer p.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try testing.expect(!contains(try delegatesOf(&p, &buffer, "TextImpl"), "byte_string_arguments"));
}

test "ByteString dictionary members are listed by name" {
    var p = try parse(
        \\typedef ByteString HeaderName;
        \\dictionary RequestInit {
        \\  ByteString method;
        \\  USVString referrer;
        \\  HeaderName header;
        \\  ByteString? optionalMethod;
        \\  sequence<ByteString> names;
        \\  (ByteString or long) either;
        \\};
    );
    defer p.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeByteStringMembers(&buffer.writer, p.file.dictionaries[0].members, &p.model);
    try testing.expect(contains(buffer.written(), "pub const byte_string_members = .{ \"method\", \"header\", \"optionalMethod\", \"names\" };"));

    var none: std.Io.Writer.Allocating = .init(testing.allocator);
    defer none.deinit();
    try writer.writeByteStringMembers(&none.writer, p.file.dictionaries[0].members[1..2], &p.model);
    try testing.expectEqualStrings("", none.written());
}
