//! WebIDL Parser
//!
//! This module provides functions for parsing WebIDL (.idl) files.

const std = @import("std");
const types = @import("types.zig");
const idl_parser = @import("idl_parser.zig");

/// Wrapper type for parsed IDL
pub const ParsedIDL = struct {
    value: types.IDLFile,
    allocator: std.mem.Allocator,
    /// Arena allocator for IDL-parsed data
    /// When parsing fails, the arena is destroyed automatically, preventing leaks
    arena: *std.heap.ArenaAllocator,

    pub fn deinit(self: ParsedIDL) void {
        // For IDL-parsed data, just destroy the arena
        // This automatically frees all allocations made during parsing
        self.arena.deinit();
        self.allocator.destroy(self.arena);
    }
};

/// Parse a WebIDL (.idl) file and return the parsed structure
///
/// The caller owns the returned ParsedIDL and must call deinit() when done.
///
/// Example:
/// ```zig
/// const parsed = try parseIDLFile(allocator, "dom.idl");
/// defer parsed.deinit();
///
/// for (parsed.value.interfaces) |interface| {
///     std.debug.print("Interface: {s}\n", .{interface.name});
/// }
/// ```
pub fn parseIDLFile(allocator: std.mem.Allocator, file_path: []const u8) !ParsedIDL {
    // Only support .idl files
    if (!std.mem.endsWith(u8, file_path, ".idl")) {
        return error.UnsupportedFileType;
    }

    const file_contents = try std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024);
    defer allocator.free(file_contents);

    // Use arena allocator for parsing - automatically cleans up on error
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);

    arena.* = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    const arena_allocator = arena.allocator();
    const idl_file = try idl_parser.Parser.parse(arena_allocator, file_contents);

    return ParsedIDL{
        .value = idl_file,
        .allocator = allocator,
        .arena = arena, // Keep arena alive for IDL data
    };
}

/// Process a WebIDL file and call a callback for each interface
///
/// This is a convenience function that parses the file and iterates over interfaces.
///
/// Example:
/// ```zig
/// fn processInterface(ctx: void, interface: types.Interface) !void {
///     std.debug.print("Processing: {s}\n", .{interface.name});
/// }
///
/// try forEachInterface(allocator, "dom.idl", {}, processInterface);
/// ```
pub fn forEachInterface(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    context: anytype,
    callback: fn (@TypeOf(context), types.Interface) anyerror!void,
) !void {
    const parsed = try parseIDLFile(allocator, file_path);
    defer parsed.deinit();

    for (parsed.value.interfaces) |interface| {
        try callback(context, interface);
    }
}

// Unit tests
const testing = std.testing;

test "parseIDLFile parses valid IDL" {
    const allocator = testing.allocator;

    // Create a temporary file with valid WebIDL
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const idl_content =
        \\interface EventTarget {
        \\    void addEventListener();
        \\};
    ;

    try tmp_dir.dir.writeFile(.{ .sub_path = "test.idl", .data = idl_content });

    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, "test.idl");
    defer allocator.free(tmp_path);

    const parsed = try parseIDLFile(allocator, tmp_path);
    defer parsed.deinit();

    try testing.expect(parsed.value.interfaces.len == 1);
    try testing.expectEqualStrings("EventTarget", parsed.value.interfaces[0].name);
}

test "parseIDLFile rejects non-IDL files" {
    const allocator = testing.allocator;

    const result = parseIDLFile(allocator, "test.json");
    try testing.expectError(error.UnsupportedFileType, result);
}
