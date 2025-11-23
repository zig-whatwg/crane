//! IDL Scanner - Parse all IDL files and extract metadata
//!
//! Scans the idl/ directory, parses each .idl file, and saves metadata to JSON

const std = @import("std");
const parser = @import("parser.zig");
const types = @import("types.zig");

/// Scan all IDL files in a directory and save metadata to JSON
pub fn scanAndSave(
    allocator: std.mem.Allocator,
    idl_dir: []const u8,
    output_path: []const u8,
) !void {
    std.debug.print("Scanning IDL directory: {s}\n", .{idl_dir});

    var dir = try std.fs.cwd().openDir(idl_dir, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    var file_count: usize = 0;
    var total_interfaces: usize = 0;
    var total_dictionaries: usize = 0;
    var total_enums: usize = 0;
    var total_typedefs: usize = 0;
    var total_callbacks: usize = 0;
    var total_namespaces: usize = 0;

    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".idl")) continue;

        const file_path = try std.fs.path.join(allocator, &.{ idl_dir, entry.name });
        defer allocator.free(file_path);

        // Parse the file
        const parsed_idl = parser.parseIDLFile(allocator, file_path) catch |err| {
            std.debug.print("  ⚠️  Failed to parse {s}: {}\n", .{ entry.name, err });
            continue;
        };
        defer parsed_idl.deinit();

        const idl_file = parsed_idl.value;

        total_interfaces += idl_file.interfaces.len;
        total_dictionaries += idl_file.dictionaries.len;
        total_enums += idl_file.enums.len;
        total_typedefs += idl_file.typedefs.len;
        total_callbacks += idl_file.callbacks.len;
        total_namespaces += idl_file.namespaces.len;

        file_count += 1;
    }

    // Build JSON string
    const json = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "file_count": {d},
        \\  "total_interfaces": {d},
        \\  "total_dictionaries": {d},
        \\  "total_enums": {d},
        \\  "total_typedefs": {d},
        \\  "total_callbacks": {d},
        \\  "total_namespaces": {d}
        \\}}
        \\
    , .{ file_count, total_interfaces, total_dictionaries, total_enums, total_typedefs, total_callbacks, total_namespaces });
    defer allocator.free(json);

    // Write to file
    try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = json });

    std.debug.print("✓ Scanned {d} IDL files\n", .{file_count});
    std.debug.print("  - {d} interfaces\n", .{total_interfaces});
    std.debug.print("  - {d} dictionaries\n", .{total_dictionaries});
    std.debug.print("  - {d} enums\n", .{total_enums});
    std.debug.print("  - {d} typedefs\n", .{total_typedefs});
    std.debug.print("  - {d} callbacks\n", .{total_callbacks});
    std.debug.print("  - {d} namespaces\n", .{total_namespaces});
    std.debug.print("✓ Metadata saved to {s}\n", .{output_path});
}
