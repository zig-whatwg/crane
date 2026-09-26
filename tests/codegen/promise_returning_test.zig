//! Which operations return promises.
//!
//! WebIDL 3.7.6: an operation whose return type is a promise runs its steps -
//! brand check, argument conversion, the operation - with an exception
//! handler, and an exception becomes a rejected promise. The binding learns
//! which operations those are from a `promise_returning` table codegen writes,
//! keyed by the Zig function it installs.

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

test "promise-returning operations are listed by the function the binding installs" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writePromiseReturning(&buffer.writer, &ops);
    const out = buffer.written();
    try testing.expect(std.mem.indexOf(u8, out, "pub const promise_returning = .{") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"call_json\",") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"call_static_any\",") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\"call_clone\"") == null);
}

test "an interface with no promise-returning operation gets no table" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writePromiseReturning(&buffer.writer, ops[1..2]);
    try testing.expectEqual(@as(usize, 0), buffer.written().len);
}
