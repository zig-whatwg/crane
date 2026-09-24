//! An interface mixin's members are inherited by every interface that
//! includes it.
//!
//! WebIDL `includes` makes a mixin's members the including interface's own:
//! they are on its prototype, its brand check guards them, and the mixin has
//! no object of its own. So the includer's generated interface lists them in
//! its own tables and inherits their functions from the mixin's generated
//! module - `pub const call_walk = mixins.Walkable.call_walk;` - which is the
//! one place they reach the mixin's impl. The includer's impl never implements
//! them, and nothing calls the mixin on its own.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

/// Walkable stands in for any mixin on the inherited list.
const options: writer.DelegateOptions = .{ .inherited_mixins = &.{"Walkable"} };

const same_object = [_]types.ExtendedAttribute{.{ .name = "SameObject" }};

fn render(attrs: []const types.Attribute, ops: []const types.Operation, overload_ops: []const types.Operation) !std.Io.Writer.Allocating {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    errdefer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "DogImpl", null, attrs, ops, overload_ops, options);
    return buffer;
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "an includer inherits a mixin's attributes and operations; its own members still delegate" {
    const attrs = [_]types.Attribute{
        .{ .name = "steps", .idlType = .{ .type = "unsigned long" }, .readonly = true, .mixin = "Walkable" },
        .{ .name = "pace", .idlType = .{ .type = "double" }, .mixin = "Walkable" },
        .{ .name = "name", .idlType = .{ .type = "DOMString" }, .readonly = true },
    };
    const ops = [_]types.Operation{
        .{ .name = "walk", .idlType = .{ .type = "undefined" }, .mixin = "Walkable" },
        .{ .name = "bark", .idlType = .{ .type = "undefined" } },
    };
    var buffer = try render(&attrs, &ops, &ops);
    defer buffer.deinit();
    const out = buffer.written();

    try testing.expect(contains(out, "pub const get_steps = mixins.Walkable.get_steps;"));
    try testing.expect(contains(out, "pub const get_pace = mixins.Walkable.get_pace;"));
    try testing.expect(contains(out, "pub const set_pace = mixins.Walkable.set_pace;"));
    try testing.expect(contains(out, "pub const call_walk = mixins.Walkable.call_walk;"));
    // Readonly: no setter is inherited because the mixin module has none.
    try testing.expect(!contains(out, "set_steps"));
    // Nothing of the mixin's reaches the includer's impl.
    try testing.expect(!contains(out, "DogImpl.get_steps"));
    try testing.expect(!contains(out, "DogImpl.call_walk"));
    // The includer's own members are its impl's.
    try testing.expect(contains(out, "return try DogImpl.get_name(instance);"));
    try testing.expect(contains(out, "DogImpl.call_bark(instance"));
}

test "a mixin's further overloads are inherited, and the overload table asks the mixin's impl" {
    const walk_args = [_]types.Argument{.{ .name = "steps", .idlType = .{ .type = "unsigned long" } }};
    const ops = [_]types.Operation{
        .{ .name = "walk", .idlType = .{ .type = "undefined" }, .mixin = "Walkable" },
        .{ .name = "walk", .idlType = .{ .type = "undefined" }, .arguments = @constCast(&walk_args), .mixin = "Walkable" },
    };
    var buffer = try render(&.{}, ops[0..1], &ops);
    defer buffer.deinit();
    const out = buffer.written();

    try testing.expect(contains(out, "pub const call_walk = mixins.Walkable.call_walk;"));
    try testing.expect(contains(out, "pub const call_walk__1 = mixins.Walkable.call_walk__1;"));
    try testing.expect(contains(out, ".implemented = @hasDecl(mixins.Walkable.impl, \"call_walk__1\")"));
    try testing.expect(!contains(out, "@hasDecl(DogImpl, \"call_walk__1\")"));
}

test "a [SameObject] mixin attribute caches in the includer's state around the inherited getter" {
    const attrs = [_]types.Attribute{
        .{ .name = "leash", .idlType = .{ .type = "Leash" }, .readonly = true, .extAttrs = @constCast(&same_object), .mixin = "Walkable" },
    };
    var buffer = try render(&attrs, &.{}, &.{});
    defer buffer.deinit();
    const out = buffer.written();

    // The mixin has no state; the includer's own State holds the cache.
    try testing.expect(contains(out, "if (state.own.cached_leash) |cached| {"));
    try testing.expect(contains(out, "const value = try mixins.Walkable.get_leash(instance);"));
    try testing.expect(!contains(out, "pub const get_leash ="));
}

test "a mixin not yet on the inherited list keeps its includer delegates" {
    const attrs = [_]types.Attribute{
        .{ .name = "role", .idlType = .{ .type = "DOMString" }, .mixin = "ARIAMixin" },
    };
    var buffer = try render(&attrs, &.{}, &.{});
    defer buffer.deinit();
    const out = buffer.written();

    try testing.expect(contains(out, "return try DogImpl.get_role(instance);"));
    try testing.expect(contains(out, "try DogImpl.set_role(instance, value);"));
    try testing.expect(!contains(out, "mixins.ARIAMixin"));
}

test "the default inherited list is the codegen's transitional list" {
    const default: writer.DelegateOptions = .{};
    try testing.expectEqual(codegen.inherited_mixins.names.len, default.inherited_mixins.len);
    for (codegen.inherited_mixins.names, default.inherited_mixins) |a, b| try testing.expectEqualStrings(a, b);
}

test "a mixin module delegates its members to the mixin's impl and keeps no state" {
    const ce_reactions = [_]types.ExtendedAttribute{.{ .name = "CEReactions" }};
    const attrs = [_]types.Attribute{
        .{ .name = "steps", .idlType = .{ .type = "unsigned long" }, .readonly = true },
        .{ .name = "leash", .idlType = .{ .type = "Leash" }, .readonly = true, .extAttrs = @constCast(&same_object) },
        .{ .name = "pace", .idlType = .{ .type = "double" }, .extAttrs = @constCast(&ce_reactions) },
    };
    const ops = [_]types.Operation{.{ .name = "walk", .idlType = .{ .type = "undefined" } }};
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "WalkableImpl", null, &attrs, &ops, &ops, .{ .same_object_cache = false });
    const out = buffer.written();

    try testing.expect(contains(out, "return try WalkableImpl.get_steps(instance);"));
    try testing.expect(contains(out, "return try WalkableImpl.get_leash(instance);"));
    try testing.expect(contains(out, "WalkableImpl.call_walk(instance"));
    // [CEReactions] wraps the mixin's delegate, which is what an includer inherits.
    try testing.expect(contains(out, "runtime.CEReactions.begin();"));
    // A mixin has no instances and so no State of its own.
    try testing.expect(!contains(out, "getState(State)"));
}
