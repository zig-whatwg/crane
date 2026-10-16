//! A dictionary lists its optional members whose IDL type is nullable, so
//! the converter can tell a present null that is the value null (`AbortSignal?
//! signal`) from one that converts by its type (`LockMode mode`: null is not
//! a LockMode - a TypeError). WebIDL 3.2.18: only undefined is "not
//! present"; every optional member is `?T = null` in Zig either way.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

var union_arms = [_]types.IDLType{
    .{ .type = "DOMString" },
    .{ .type = "Blob", .nullable = true },
};

const members = [_]types.DictionaryMember{
    .{ .name = "mode", .idlType = .{ .type = "LockMode" } },
    .{ .name = "signal", .idlType = .{ .type = "AbortSignal", .nullable = true } },
    .{ .name = "text", .idlType = .{ .type = "DOMString" } },
    .{ .name = "either", .idlType = .{ .type = "union", .unionTypes = &union_arms } },
    .{ .name = "must", .idlType = .{ .type = "DOMString", .nullable = true }, .required = true },
};

test "the nullable optional members are listed, the others not" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeNullableMembers(&buffer.writer, &members, null);
    const out = buffer.written();
    try testing.expect(contains(out, "pub const nullable_members = .{ \"signal\", \"either\" };"));
}

test "a union that includes a nullable type is nullable; a required member is never listed" {
    try testing.expect(writer.isNullableMember(members[3], null));
    try testing.expect(!writer.isNullableMember(members[4], null));
    try testing.expect(!writer.isNullableMember(members[0], null));
}

test "no nullable optional member, no table" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeNullableMembers(&buffer.writer, members[0..1], null);
    try testing.expectEqualStrings("", buffer.written());
}
