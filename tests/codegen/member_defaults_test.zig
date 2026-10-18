//! A dictionary lists its optional members' IDL default values
//! (`member_defaults`), so converting the dictionary to an ECMAScript value
//! can write a member the value leaves unset with its default (WebIDL 2.7: a
//! default is "the value used by default when author code or specification
//! text does not provide a value"; 3.2.18 writes every member that exists).
//! Codegen types every optional member `?T = null` and keeps no default, so
//! Sanitizer.get()'s `namespace: null` (`DOMString? _namespace = null`) and an
//! unset `bubbles` (`= false`) were written as nothing.
//!
//! And it lists its inline union members typed runtime.JSValue whose union is
//! not nullable (`jsvalue_union_members`): a present null is a value of the
//! union for the impl to convert (to its dictionary arm, say), never "not
//! present" - SetHTMLOptions `{sanitizer: null}` took the default preset.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

var sanitizer_arms = [_]types.IDLType{
    .{ .type = "Sanitizer" },
    .{ .type = "SanitizerConfig" },
    .{ .type = "SanitizerPresets" },
};
var nullable_arms = [_]types.IDLType{
    .{ .type = "Element" },
    .{ .type = "Document" },
};

const members = [_]types.DictionaryMember{
    .{ .name = "bubbles", .idlType = .{ .type = "boolean" }, .default = .{ .boolean = false } },
    .{ .name = "namespace", .idlType = .{ .type = "DOMString", .nullable = true }, .default = .null },
    .{ .name = "fill", .idlType = .{ .type = "FillMode" }, .default = .{ .string = "\"auto\"" } },
    .{ .name = "iterations", .idlType = .{ .type = "unrestricted double" }, .default = .{ .float = 1.5 } },
    .{ .name = "delay", .idlType = .{ .type = "double" }, .default = .{ .integer = 0 } },
    .{ .name = "end", .idlType = .{ .type = "unrestricted double" }, .default = .{ .infinity = .positive } },
    .{ .name = "start", .idlType = .{ .type = "unrestricted double" }, .default = .{ .infinity = .negative } },
    .{ .name = "odd", .idlType = .{ .type = "unrestricted double" }, .default = .nan },
    .{ .name = "offsets", .idlType = .{ .type = "sequence", .generic = "double" }, .default = .emptySequence },
    .{ .name = "init", .idlType = .{ .type = "EventInit" }, .default = .emptyDictionary },
    .{ .name = "plain", .idlType = .{ .type = "DOMString" } },
    .{ .name = "must", .idlType = .{ .type = "DOMString" }, .required = true },
    .{ .name = "sanitizer", .idlType = .{ .type = "union", .unionTypes = &sanitizer_arms }, .default = .{ .string = "\"default\"" } },
    .{ .name = "root", .idlType = .{ .type = "union", .unionTypes = &nullable_arms, .nullable = true }, .default = .null },
};

fn written(comptime write: anytype, list: []const types.DictionaryMember) ![]u8 {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    errdefer buffer.deinit();
    try write(&buffer.writer, list, null);
    return buffer.toOwnedSlice();
}

test "every optional member with a default is listed with it, in one tag literal per kind" {
    const out = try written(writer.writeMemberDefaults, &members);
    defer testing.allocator.free(out);
    const expected =
        \\
        \\    /// Optional members' IDL default values: a member the value leaves
        \\    /// unset is written with its default when converted to script.
        \\    pub const member_defaults = .{
        \\        .{ "bubbles", .{ .boolean = false } },
        \\        .{ "namespace", .null },
        \\        .{ "fill", .{ .string = "auto" } },
        \\        .{ "iterations", .{ .number = 1.5 } },
        \\        .{ "delay", .{ .number = 0 } },
        \\        .{ "end", .positive_infinity },
        \\        .{ "start", .negative_infinity },
        \\        .{ "odd", .nan },
        \\        .{ "offsets", .empty_sequence },
        \\        .{ "init", .empty_dictionary },
        \\        .{ "sanitizer", .{ .string = "default" } },
        \\        .{ "root", .null },
        \\    };
        \\
    ;
    try testing.expectEqualStrings(expected, out);
}

test "no member with a default, no table" {
    const out = try written(writer.writeMemberDefaults, members[10..12]);
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("", out);
}

test "a string default is its token's text, as a Zig string literal" {
    // The parser keeps a string token's quotes; WebIDL strings have no
    // escapes, but a backslash is text and must be escaped in Zig.
    const quoted = [_]types.DictionaryMember{
        .{ .name = "text", .idlType = .{ .type = "DOMString" }, .default = .{ .string = "\"a\\b\"" } },
    };
    const out = try written(writer.writeMemberDefaults, &quoted);
    defer testing.allocator.free(out);
    try testing.expect(std.mem.indexOf(u8, out, ".{ \"text\", .{ .string = \"a\\\\b\" } },") != null);
}

test "only a non-nullable inline union member is a JSValue union member" {
    const out = try written(writer.writeJsvalueUnionMembers, &members);
    defer testing.allocator.free(out);
    try testing.expect(std.mem.indexOf(u8, out, "pub const jsvalue_union_members = .{ \"sanitizer\" };") != null);
    const none = try written(writer.writeJsvalueUnionMembers, members[0..12]);
    defer testing.allocator.free(none);
    try testing.expectEqualStrings("", none);
}

test "the parser keeps `{}` and `[]` apart from null, and a generated dictionary lists them" {
    // WebIDL 2.5.4 (DefaultValue): `{}` and `[]` are default values of their
    // own - an empty dictionary and an empty sequence - not null:
    // SetHTMLUnsafeOptions' `sanitizer = {}` is its SanitizerConfig arm with
    // no member set.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const file = try codegen.idl_parser.Parser.parse(arena.allocator(),
        \\dictionary Options {
        \\  (DOMString or Config) sanitizer = {};
        \\  sequence<double> offsets = [];
        \\  DOMString? _namespace = null;
        \\  DOMString fill = "auto";
        \\};
    );
    const parsed = file.dictionaries[0].members;
    try testing.expect(parsed[0].default.? == .emptyDictionary);
    try testing.expect(parsed[1].default.? == .emptySequence);
    try testing.expect(parsed[2].default.? == .null);

    var model = try codegen.ir.IR.init(arena.allocator());
    for (file.dictionaries) |d| try model.addDictionary(d, "test.idl");
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try codegen.generator.writeDictionary(arena.allocator(), &buffer.writer, file.dictionaries[0], &model);
    const out = buffer.written();
    try testing.expect(std.mem.indexOf(u8, out, ".{ \"sanitizer\", .empty_dictionary },") != null);
    try testing.expect(std.mem.indexOf(u8, out, ".{ \"offsets\", .empty_sequence },") != null);
    try testing.expect(std.mem.indexOf(u8, out, ".{ \"namespace\", .null },") != null);
    // A string default is its text, without the IDL token's quotes.
    try testing.expect(std.mem.indexOf(u8, out, ".{ \"fill\", .{ .string = \"auto\" } },") != null);
    try testing.expect(std.mem.indexOf(u8, out, "pub const jsvalue_union_members = .{\"sanitizer\"};") != null or
        std.mem.indexOf(u8, out, "pub const jsvalue_union_members = .{ \"sanitizer\" };") != null);
}
