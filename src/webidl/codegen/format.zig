//! Format generated files the way `zig fmt` does, so that what codegen writes
//! is byte for byte what is committed (the committed tree is zig fmt-clean;
//! the writers' raw output is not - see
//! docs/lessons/codegen-raw-codegen-output-is-not-zig-fmt-clean-so.md).

const std = @import("std");

/// Render every `.zig` file directly in `dir_path` through the Zig formatter,
/// rewriting the ones that change. A file that does not parse is an error:
/// codegen wrote invalid Zig.
pub fn formatDir(allocator: std.mem.Allocator, io: std.Io, dir_path: []const u8) !void {
    var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer dir.close(io);

    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;
        const source = try dir.readFileAllocOptions(io, entry.name, allocator, .limited(64 * 1024 * 1024), .of(u8), 0);
        defer allocator.free(source);

        const formatted = formatSource(allocator, source) catch |err| {
            std.debug.print("  error: generated {s}/{s} is not valid Zig\n", .{ dir_path, entry.name });
            return err;
        };
        defer allocator.free(formatted);

        if (!std.mem.eql(u8, source, formatted)) {
            try dir.writeFile(io, .{ .sub_path = entry.name, .data = formatted });
        }
    }
}

/// What `zig fmt` makes of `source`.
pub fn formatSource(allocator: std.mem.Allocator, source: [:0]const u8) ![]u8 {
    var tree = try std.zig.Ast.parse(allocator, source, .zig);
    defer tree.deinit(allocator);
    if (tree.errors.len != 0) return error.InvalidGeneratedZig;
    return tree.renderAlloc(allocator);
}
