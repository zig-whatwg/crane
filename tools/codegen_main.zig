//! WebIDL Code Generator CLI
//!
//! Usage:
//!   webidl-codegen <source> --dest-root <path> [--force]
//!
//! Where:
//!   <source> is either a .idl file or directory of .idl files
//!   --dest-root <path> is the root directory for organized output
//!
//! Implementation stubs are always generated to impls_tmp/ (gitignored).
//! These stubs are for REFERENCE ONLY and must be manually migrated to impls/.

const std = @import("std");
const codegen = @import("codegen");
const CodegenConfig = codegen.config.CodegenConfig;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.next();

    // Parse arguments
    var source_path: ?[]const u8 = null;
    var dest_root: ?[]const u8 = null;
    var force_clean: bool = false;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--dest-root")) {
            dest_root = args.next() orelse {
                try printUsage();
                return error.MissingDestRoot;
            };
        } else if (std.mem.eql(u8, arg, "--force")) {
            force_clean = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printUsage();
            return;
        } else {
            // First positional argument is source path
            if (source_path == null) {
                source_path = arg;
            } else {
                std.debug.print("Unknown argument: {s}\n", .{arg});
                try printUsage();
                return error.UnknownArgument;
            }
        }
    }

    // Validate required arguments
    if (source_path == null) {
        std.debug.print("Error: Missing source path\n\n", .{});
        try printUsage();
        return error.MissingSourcePath;
    }

    if (dest_root == null) {
        std.debug.print("Error: --dest-root must be specified\n\n", .{});
        try printUsage();
        return error.MissingDestRoot;
    }

    // Determine if source is a file or directory
    const source = source_path.?;

    // Try to open as directory first, then fall back to file
    var is_directory = false;
    if (std.fs.cwd().openDir(source, .{})) |dir_result| {
        var dir = dir_result;
        dir.close();
        is_directory = true;
    } else |_| {
        // Not a directory, verify it's a valid file
        const stat = std.fs.cwd().statFile(source) catch |err| {
            std.debug.print("Error: Cannot access source path '{s}': {}\n", .{ source, err });
            return err;
        };
        is_directory = stat.kind == .directory;
    }

    // If --force is specified, delete generated directories (but NEVER impls/)
    if (force_clean) {
        std.debug.print("Force clean: removing generated directories (preserving impls/)\n", .{});
        const generated_dirs = [_][]const u8{
            "interfaces",
            "typedefs",
            "dictionaries",
            "enums",
            "callbacks",
            "namespaces",
            "mixins",
            "impls_tmp", // Only delete the tmp stubs, never impls/
        };
        for (generated_dirs) |dir| {
            const path = try std.fs.path.join(allocator, &.{ dest_root.?, dir });
            defer allocator.free(path);
            std.fs.cwd().deleteTree(path) catch |err| {
                if (err != error.FileNotFound) {
                    std.debug.print("Warning: Could not remove {s}: {}\n", .{ path, err });
                }
            };
        }
    }

    // Print configuration
    std.debug.print("WebIDL Code Generator\n", .{});
    std.debug.print("=====================\n", .{});
    std.debug.print("Source:      {s} ({s})\n", .{ source, if (is_directory) "directory" else "file" });
    std.debug.print("Dest Root:   {s}\n", .{dest_root.?});
    std.debug.print("  - interfaces/\n", .{});
    std.debug.print("  - typedefs/\n", .{});
    std.debug.print("  - dictionaries/\n", .{});
    std.debug.print("  - enums/\n", .{});
    std.debug.print("  - callbacks/\n", .{});
    std.debug.print("  - namespaces/\n", .{});
    std.debug.print("  - impls_tmp/ (reference stubs - NOT compiled)\n", .{});
    std.debug.print("\n", .{});

    // Create configuration
    var config = CodegenConfig{
        .allocator = allocator,
        .dest_root = dest_root,
    };
    defer config.deinit();

    // Process based on source type
    if (is_directory) {
        // Process all .idl files in directory (pipeline mode)
        try codegen.processDirectory(allocator, source, &config);
    } else {
        // Process single .idl file
        try codegen.generateFromFile(allocator, source, &config);
    }

    std.debug.print("\n✅ Code generation complete!\n", .{});
}

fn printUsage() !void {
    var buffer: [4096]u8 = undefined;
    const stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("WebIDL-to-Zig Code Generator\n\n", .{});
    try stdout.print("Usage:\n", .{});
    try stdout.print("  webidl-codegen <source> --dest-root <path> [--force]\n\n", .{});

    try stdout.print("Arguments:\n", .{});
    try stdout.print("  <source>              Path to .idl file or directory of .idl files\n\n", .{});

    try stdout.print("Options:\n", .{});
    try stdout.print("  --dest-root <path>    Root directory for organized output\n", .{});
    try stdout.print("                        Creates: interfaces/, typedefs/, dictionaries/,\n", .{});
    try stdout.print("                        enums/, callbacks/, namespaces/, impls_tmp/\n", .{});
    try stdout.print("  --force               Delete entire dest-root directory before generating\n", .{});
    try stdout.print("                        Use this to ensure clean regeneration of all files\n", .{});
    try stdout.print("  --help, -h            Show this help message\n\n", .{});

    try stdout.print("Behavior:\n", .{});
    try stdout.print("  - If source is a file: generates code for that single .idl file\n", .{});
    try stdout.print("  - If source is a directory: processes all .idl files (pipeline mode)\n", .{});
    try stdout.print("    - Merges partial interfaces and mixins\n", .{});
    try stdout.print("    - Resolves cross-file dependencies\n", .{});
    try stdout.print("  - Creates organized directory structure under dest-root\n", .{});
    try stdout.print("  - With --force, everything is regenerated fresh\n\n", .{});

    try stdout.print("Implementation Stubs (impls_tmp/):\n", .{});
    try stdout.print("  - Always generated to impls_tmp/ directory (gitignored)\n", .{});
    try stdout.print("  - These are REFERENCE ONLY - DO NOT COMPILE\n", .{});
    try stdout.print("  - Manually migrate stubs to impls/ for actual implementations\n", .{});
    try stdout.print("  - The impls/ directory contains canonical implementations\n\n", .{});

    try stdout.print("Examples:\n", .{});
    try stdout.print("  # Generate organized directory structure\n", .{});
    try stdout.print("  webidl-codegen /path/to/webref/ed/idl --dest-root ./generated\n\n", .{});

    try stdout.print("  # Force clean regeneration\n", .{});
    try stdout.print("  webidl-codegen /path/to/webref/ed/idl --dest-root ./generated --force\n\n", .{});

    try stdout.print("  # Generate from a single file\n", .{});
    try stdout.print("  webidl-codegen dom.idl --dest-root ./generated\n", .{});

    try stdout.flush();
}
