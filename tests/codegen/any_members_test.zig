//! Which dictionary members keep a present null.
//!
//! WebIDL 3.2.18: a dictionary member is present unless its value is
//! undefined, so `{ error: null }` has an `error` member whose value is null.
//! A member typed `any` is a `?runtime.JSValue`, whose Zig null means "not
//! present" - so `new ErrorEvent("x", { error: null }).error` read undefined.
//! The dictionary converter needs to know which members are `any`: codegen
//! lists them, as it lists restricted floats.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

const members = [_]types.DictionaryMember{
    .{ .name = "error", .idlType = .{ .type = "any" } },
    .{ .name = "message", .idlType = .{ .type = "DOMString" } },
    .{ .name = "detail", .idlType = .{ .type = "any" } },
    .{ .name = "root", .idlType = .{ .type = "Element", .nullable = true } },
    .{ .name = "data", .idlType = .{ .type = "object", .nullable = true } },
    .{ .name = "reason", .idlType = .{ .type = "any" }, .required = true },
};

test "a dictionary's optional any members are listed" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeAnyMembers(&buffer.writer, &members);
    const out = buffer.written();
    try testing.expect(std.mem.indexOf(u8, out, "pub const any_members = .{ \"error\", \"detail\" };") != null);
}

test "a dictionary with no any member gets no table" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeAnyMembers(&buffer.writer, members[1..2]);
    try testing.expectEqual(@as(usize, 0), buffer.written().len);
}
