const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const serializer = @import("serializer.zig");
const host = @import("host");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        try printUsage();
        return error.InvalidArguments;
    }

    const input_path = args[1];
    const output_path = args[2];

    const input_stat = host.cwd().statFile(host.io(), input_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Error: Input path '{s}' not found\n", .{input_path});
            return err;
        }
        return err;
    };

    if (input_stat.kind == .directory) {
        try processDirectory(allocator, input_path, output_path);
    } else {
        try processFile(allocator, input_path, output_path);
    }
}

fn processFile(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8) !void {
    std.debug.print("Parsing {s}...\n", .{input_path});

    const source = try host.cwd().readFileAlloc(host.io(), input_path, allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(source);

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer, input_path);

    var ast = parser.parse() catch |err| {
        std.debug.print("Failed to parse {s}: {}\n", .{ input_path, err });
        return err;
    };
    defer ast.deinit();

    try serializer.writeToFile(ast, output_path);
    std.debug.print("  -> {s}\n", .{output_path});
}

fn processDirectory(allocator: std.mem.Allocator, input_dir: []const u8, output_dir: []const u8) !void {
    std.debug.print("Processing directory {s}...\n", .{input_dir});

    const io = host.io();
    host.cwd().createDir(io, output_dir, .default_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    var dir = try host.cwd().openDir(io, input_dir, .{ .iterate = true });
    defer dir.close(io);

    var iter = dir.iterate();
    var processed: usize = 0;
    var failed: usize = 0;

    while (try iter.next(io)) |entry| {
        if (entry.kind != .file) continue;

        if (!std.mem.endsWith(u8, entry.name, ".idl")) continue;

        const input_path = try std.fs.path.join(allocator, &.{ input_dir, entry.name });
        defer allocator.free(input_path);

        const base_name = entry.name[0 .. entry.name.len - 4];
        const output_name = try std.mem.concat(allocator, u8, &.{ base_name, ".json" });
        defer allocator.free(output_name);

        const output_path = try std.fs.path.join(allocator, &.{ output_dir, output_name });
        defer allocator.free(output_path);

        processFile(allocator, input_path, output_path) catch |err| {
            std.debug.print("Error processing {s}: {}\n", .{ entry.name, err });
            failed += 1;
            continue;
        };
        processed += 1;
    }

    std.debug.print("\nProcessed {d} files successfully, {d} failed\n", .{ processed, failed });
}

fn printUsage() !void {
    std.debug.print(
        \\Usage: webidl-parser <input> <output>
        \\
        \\  <input>   Input .idl file or directory containing .idl files
        \\  <output>  Output .json file or directory for JSON output
        \\
        \\Examples:
        \\  # Parse a single file
        \\  webidl-parser dom.idl dom.json
        \\
        \\  # Parse all .idl files in a directory
        \\  webidl-parser ./idl/ ./output/
        \\
        \\Output Format:
        \\  The parser generates JSON files (.json) containing the complete AST
        \\  representation of the WebIDL definitions.
        \\
        \\
    , .{});
}
