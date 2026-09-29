//! A [SameObject] attribute whose value is an engine value is not cached by
//! the generated getter.
//!
//! The binding releases every value a getter returns (AGENTS.md "The engine
//! boundary", rule 3). A generated cache would hand it the cached handle, the
//! binding would release it, and the next read would return a freed handle:
//! generated code cannot take a hold of its own, because it never calls the
//! engine. So the impl keeps such a value and returns a hold of it - and a
//! [SameObject] platform object, which the wrapper cache owns, is still
//! cached here.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

var same_object = [_]types.ExtendedAttribute{.{ .name = "SameObject" }};

fn delegates(attrs: []const types.Attribute, reg: *const codegen.ir.TypeRegistry) ![]u8 {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    errdefer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CookieChangeEventImpl", reg, attrs, &.{}, &.{}, .{});
    return buffer.toOwnedSlice();
}

test "a [SameObject] FrozenArray getter delegates without a generated cache" {
    var reg = codegen.ir.TypeRegistry.init(testing.allocator);
    defer reg.deinit();
    const attrs = [_]types.Attribute{
        .{ .name = "changed", .idlType = .{ .type = "FrozenArray", .generic = "CookieListItem" }, .readonly = true, .extAttrs = &same_object },
    };
    const output = try delegates(&attrs, &reg);
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "pub fn get_changed(instance: *runtime.Instance) anyerror!runtime.JSValue {") != null);
    try testing.expect(std.mem.indexOf(u8, output, "return try CookieChangeEventImpl.get_changed(instance);") != null);
    try testing.expect(std.mem.indexOf(u8, output, "cached_changed") == null);
}

test "a [SameObject] platform object getter is still cached" {
    var reg = codegen.ir.TypeRegistry.init(testing.allocator);
    defer reg.deinit();
    try reg.registerInterface("DOMTokenList", "dom.idl", null);
    const attrs = [_]types.Attribute{
        .{ .name = "classList", .idlType = .{ .type = "DOMTokenList" }, .readonly = true, .extAttrs = &same_object },
    };
    const output = try delegates(&attrs, &reg);
    defer testing.allocator.free(output);
    try testing.expect(std.mem.indexOf(u8, output, "state.own.cached_classList") != null);
}
