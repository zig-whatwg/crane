//! WebIDL 3.7.12 query/mutation members use the ordinary generated binding map.
//! Set iterators need an engine protocol operation; iterable<T> would give
//! index keys and ArrayIterator semantics, and is not a substitute.
const std = @import("std");
const types = @import("types.zig");

pub fn appendMembers(list_allocator: std.mem.Allocator, arena: std.mem.Allocator, name: []const u8, set: types.Setlike, members: *std.ArrayList(types.Member)) !void {
    if (!hasMember(members.items, "size")) try members.append(list_allocator, .{
        .type = .attribute,
        .attribute = .{ .name = "size", .idlType = .{ .type = "unsigned long" }, .readonly = true },
    });
    try appendOperation(list_allocator, arena, members, "has", "boolean", &.{.{ .name = "value", .idlType = set.value_type }});
    try appendOperation(list_allocator, arena, members, "forEach", "undefined", &.{
        .{ .name = "callback", .idlType = .{ .type = "any" } },
        .{ .name = "thisArg", .idlType = .{ .type = "any" }, .optional = true },
    });
    if (!set.readonly) {
        try appendOperation(list_allocator, arena, members, "add", name, &.{.{ .name = "value", .idlType = set.value_type }});
        try appendOperation(list_allocator, arena, members, "delete", "boolean", &.{.{ .name = "value", .idlType = set.value_type }});
        try appendOperation(list_allocator, arena, members, "clear", "undefined", &.{});
    }
}

fn hasMember(members: []const types.Member, name: []const u8) bool {
    for (members) |member| {
        if (member.attribute) |attribute| if (std.mem.eql(u8, name, attribute.name)) return true;
        if (member.operation) |operation| if (operation.name) |identifier| if (std.mem.eql(u8, name, identifier)) return true;
    }
    return false;
}

fn appendOperation(list_allocator: std.mem.Allocator, arena: std.mem.Allocator, members: *std.ArrayList(types.Member), name: []const u8, result: []const u8, args: []const types.Argument) !void {
    // Explicit add/delete/clear operations override the setlike defaults.
    if (hasMember(members.items, name)) return;
    try members.append(list_allocator, .{ .type = .operation, .operation = .{
        .name = name,
        .idlType = .{ .type = result },
        .arguments = try arena.dupe(types.Argument, args),
    } });
}
