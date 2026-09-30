//! A callback interface attribute is the object that was given.
//!
//! DOM 6.1: NodeIterator.filter and TreeWalker.filter return the NodeFilter
//! passed to createNodeIterator() / createTreeWalker() - the same object, not
//! a wrapper around it. A callback interface ARGUMENT reaches an impl as the
//! binding's `*runtime.CallbackWrapper`, borrowed for the call (the impl takes
//! its own value with engine.takeCallbackInterface); the attribute that gives
//! the object back is a value, `runtime.JSValue`.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

const attrs = [_]types.Attribute{
    .{ .name = "filter", .idlType = .{ .type = "NodeFilter", .nullable = true }, .readonly = true, .extAttrs = &.{} },
};

fn registry() !codegen.ir.TypeRegistry {
    var reg = codegen.ir.TypeRegistry.init(testing.allocator);
    errdefer reg.deinit();
    try reg.registerCallbackInterface("NodeFilter", "dom.idl");
    return reg;
}

test "a nullable callback interface attribute's getter returns ?runtime.JSValue" {
    var reg = try registry();
    defer reg.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "NodeIteratorImpl", &reg, &attrs, &.{}, &.{}, .{});
    const output = buffer.written();
    try testing.expect(std.mem.indexOf(u8, output, "pub fn get_filter(instance: *runtime.Instance) anyerror!?runtime.JSValue {") != null);
    try testing.expect(std.mem.indexOf(u8, output, "CallbackWrapper") == null);
}

test "a callback interface attribute's state field holds a value" {
    var reg = try registry();
    defer reg.deinit();
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeGeneratedState(&buffer.writer, &attrs, "NodeIteratorImpl", &reg);
    const output = buffer.written();
    try testing.expect(std.mem.indexOf(u8, output, "filter: ?runtime.JSValue") != null);
    try testing.expect(std.mem.indexOf(u8, output, "CallbackWrapper") == null);
}
