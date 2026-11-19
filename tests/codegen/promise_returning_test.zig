//! Which operations and attribute getters return promises.
//!
//! WebIDL 3.7.6: an operation whose return type is a promise runs its steps -
//! brand check, argument conversion, the operation - with an exception
//! handler, and an exception becomes a rejected promise; so does the getter of
//! an attribute whose type is a promise ("attribute getter": "If attribute's
//! type is a promise type, then return ! Call(%Promise.reject%, %Promise%,
//! «E»)"). The binding learns which functions those are from a
//! `promise_returning` table codegen writes, keyed by the Zig function it
//! installs.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

var no_args = [_]types.Argument{};

const ops = [_]types.Operation{
    .{ .name = "json", .idlType = .{ .type = "Promise", .generic = "any" }, .arguments = &no_args },
    .{ .name = "clone", .idlType = .{ .type = "Response" }, .arguments = &no_args },
    .{ .name = "any", .idlType = .{ .type = "Promise", .generic = "undefined" }, .arguments = &no_args, .static = true },
};

const attributes = [_]types.Attribute{
    .{ .name = "closed", .idlType = .{ .type = "Promise", .generic = "undefined" }, .readonly = true },
    .{ .name = "desiredSize", .idlType = .{ .type = "double", .nullable = true }, .readonly = true },
    .{ .name = "ready", .idlType = .{ .type = "Promise", .generic = "any" }, .readonly = true, .static = true },
};

test "promise-returning operations are listed by the function the binding installs" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writePromiseReturning(&buffer.writer, &.{}, &ops);
    const out = buffer.written();
    try testing.expect(std.mem.indexOf(u8, out, "pub const promise_returning = .{") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"call_json\",") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"call_static_any\",") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"call_clone\"") == null);
}

test "promise-typed attributes are listed by the getter the binding installs" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writePromiseReturning(&buffer.writer, &attributes, &.{});
    const out = buffer.written();
    try testing.expect(std.mem.indexOf(u8, out, "pub const promise_returning = .{") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"get_closed\",") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"get_static_ready\",") != null);
    try testing.expect(std.mem.indexOf(u8, out, "desiredSize") == null);
}

test "an interface with no promise-returning operation or attribute gets no table" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writePromiseReturning(&buffer.writer, attributes[1..2], ops[1..2]);
    try testing.expectEqual(@as(usize, 0), buffer.written().len);
}
