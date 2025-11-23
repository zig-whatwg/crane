//! WebIDL JSON Format Adapter
//!
//! This module adapts different WebIDL JSON formats to our internal types.
//! Currently supports the format from whatwg/webidl repository.

const std = @import("std");
const types = @import("types.zig");

/// Parse a WHATWG WebIDL JSON file format
///
/// This handles the format with "definitions" at the root level.
pub fn parseWHATWGFormat(
    allocator: std.mem.Allocator,
    file_path: []const u8,
) !std.json.Parsed(types.IDLFile) {
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024);
    defer allocator.free(content);

    // Parse as generic JSON first
    const parsed_json = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        content,
        .{ .allocate = .alloc_always },
    );
    defer parsed_json.deinit();

    const root = parsed_json.value.object;

    // Extract interfaces from definitions
    var interfaces = std.ArrayList(types.Interface).empty;
    defer {
        for (interfaces.items) |iface| {
            if (iface.members.len > 0) allocator.free(iface.members);
            if (iface.extAttrs.len > 0) allocator.free(iface.extAttrs);
            if (iface.includes.len > 0) allocator.free(iface.includes);
        }
        interfaces.deinit(allocator);
    }

    if (root.get("definitions")) |defs_value| {
        const definitions = defs_value.array.items;

        for (definitions) |def| {
            const def_obj = def.object;

            // Check if this definition contains an interface
            if (def_obj.get("interface")) |iface_value| {
                const iface_obj = iface_value.object;

                const name = iface_obj.get("name").?.string;
                const inherits = if (iface_obj.get("inherits")) |inh|
                    if (inh == .string) inh.string else null
                else
                    null;

                const interface: types.Interface = .{
                    .name = try allocator.dupe(u8, name),
                    .inheritance = if (inherits) |inh| try allocator.dupe(u8, inh) else null,
                    .members = &.{},
                    .extAttrs = &.{},
                    .partial = false,
                    .mixin = false,
                    .includes = &.{},
                };

                try interfaces.append(allocator, interface);
            }
        }
    }

    // Create IDLFile with owned data
    const result = types.IDLFile{
        .interfaces = try interfaces.toOwnedSlice(allocator),
    };

    // Wrap in Parsed struct
    var parsed_result: std.json.Parsed(types.IDLFile) = undefined;
    parsed_result.arena = try allocator.create(std.heap.ArenaAllocator);
    parsed_result.arena.* = std.heap.ArenaAllocator.init(allocator);
    parsed_result.value = result;

    return parsed_result;
}
