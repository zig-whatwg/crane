//! [CEReactions] brackets name the object whose relevant agent they push onto.
//!
//! HTML 4.13.6 [CEReactions]: "1. Push a new element queue onto this object's
//! relevant agent's custom element reactions stack. ... 3. Let queue be the
//! result of popping from this object's relevant agent's custom element
//! reactions stack." So the generated bracket passes the member's `instance`
//! - `runtime.CEReactions.begin(instance)` / `end(instance)` - and a static
//! member, which has no "this object", passes null (the reactions side then
//! resolves the agent through the current realm).
//!
//! Operations, special operations (a named setter or deleter), regular and
//! [PutForwards] attribute setters, and a mixin's members (which an includer
//! inherits from the mixin's module) all carry it.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

const ce_reactions = [_]types.ExtendedAttribute{.{ .name = "CEReactions" }};

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

/// The body of `pub fn <name>(` in `out`, up to the next `pub fn`.
fn body(out: []const u8, name: []const u8) ![]const u8 {
    var header_buf: [128]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buf, "pub fn {s}(", .{name});
    const start = std.mem.indexOf(u8, out, header) orelse return error.FunctionMissing;
    const after = start + header.len;
    const end = std.mem.indexOfPos(u8, out, after, "pub fn ") orelse out.len;
    return out[start..end];
}

fn expectInstanceBracket(fn_body: []const u8) !void {
    try testing.expect(contains(fn_body, "runtime.CEReactions.begin(instance);"));
    try testing.expect(contains(fn_body, "defer runtime.CEReactions.end(instance);"));
}

fn expectNullBracket(fn_body: []const u8) !void {
    try testing.expect(contains(fn_body, "runtime.CEReactions.begin(null);"));
    try testing.expect(contains(fn_body, "defer runtime.CEReactions.end(null);"));
}

test "a [CEReactions] operation and attribute setter bracket on their instance" {
    const attrs = [_]types.Attribute{
        .{ .name = "slot", .idlType = .{ .type = "DOMString" }, .extAttrs = @constCast(&ce_reactions) },
    };
    const ops = [_]types.Operation{
        .{ .name = "toggleAttribute", .idlType = .{ .type = "boolean" }, .extAttrs = @constCast(&ce_reactions) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CellImpl", null, &attrs, &ops, &ops, .{});
    const out = buffer.written();

    try expectInstanceBracket(try body(out, "call_toggleAttribute"));
    try expectInstanceBracket(try body(out, "set_slot"));
    // The getter runs no reactions: [CEReactions] wraps an attribute's setter steps.
    try testing.expect(!contains(try body(out, "get_slot"), "CEReactions.begin"));
    // No bracket keeps the old no-argument shape.
    try testing.expect(!contains(out, "CEReactions.begin()"));
    try testing.expect(!contains(out, "CEReactions.end()"));
}

test "a [CEReactions] named setter and deleter bracket on their instance" {
    var setter_args = [_]types.Argument{
        .{ .name = "name", .idlType = .{ .type = "DOMString" } },
        .{ .name = "value", .idlType = .{ .type = "DOMString" } },
    };
    var deleter_args = [_]types.Argument{.{ .name = "name", .idlType = .{ .type = "DOMString" } }};
    const ops = [_]types.Operation{
        .{ .idlType = .{ .type = "undefined" }, .special = .setter, .arguments = &setter_args, .extAttrs = @constCast(&ce_reactions) },
        .{ .idlType = .{ .type = "undefined" }, .special = .deleter, .arguments = &deleter_args, .extAttrs = @constCast(&ce_reactions) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "MapImpl", null, &.{}, &ops, &ops, .{});
    const out = buffer.written();

    try expectInstanceBracket(try body(out, "call_setter"));
    try expectInstanceBracket(try body(out, "call_deleter"));
}

test "a [CEReactions] [PutForwards] setter brackets on its instance" {
    const put_forwards = [_]types.ExtendedAttribute{
        .{ .name = "CEReactions" },
        .{ .name = "PutForwards", .rhs = .{ .identifier = "value" } },
    };
    const attrs = [_]types.Attribute{
        .{ .name = "classList", .idlType = .{ .type = "DOMTokenList" }, .readonly = true, .extAttrs = @constCast(&put_forwards) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CellImpl", null, &attrs, &.{}, &.{}, .{});

    try expectInstanceBracket(try body(buffer.written(), "set_classList"));
}

test "a static [CEReactions] member has no instance and brackets on null" {
    const attrs = [_]types.Attribute{
        .{ .name = "limit", .idlType = .{ .type = "unsigned long" }, .static = true, .extAttrs = @constCast(&ce_reactions) },
    };
    const ops = [_]types.Operation{
        .{ .name = "make", .idlType = .{ .type = "undefined" }, .static = true, .extAttrs = @constCast(&ce_reactions) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CellImpl", null, &attrs, &ops, &ops, .{});
    const out = buffer.written();

    try expectNullBracket(try body(out, "call_static_make"));
    try expectNullBracket(try body(out, "set_static_limit"));
}

test "a mixin's [CEReactions] member brackets in the mixin module its includers inherit" {
    const attrs = [_]types.Attribute{
        .{ .name = "pace", .idlType = .{ .type = "double" }, .extAttrs = @constCast(&ce_reactions) },
    };
    const ops = [_]types.Operation{
        .{ .name = "walk", .idlType = .{ .type = "undefined" }, .extAttrs = @constCast(&ce_reactions) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "WalkableImpl", null, &attrs, &ops, &ops, .{ .same_object_cache = false });
    const out = buffer.written();

    try expectInstanceBracket(try body(out, "call_walk"));
    try expectInstanceBracket(try body(out, "set_pace"));
}

test "a non-inherited mixin's [CEReactions] member brackets in its includer's delegate" {
    const attrs = [_]types.Attribute{
        .{ .name = "ariaLabel", .idlType = .{ .type = "DOMString", .nullable = true }, .mixin = "ARIAMixin", .extAttrs = @constCast(&ce_reactions) },
    };
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "DogImpl", null, &attrs, &.{}, &.{}, .{});

    try expectInstanceBracket(try body(buffer.written(), "set_ariaLabel"));
}
