//! IDL Scanner CLI
//!
//! Usage: idl-scanner <idl-dir> [--output <path>]

const std = @import("std");
const codegen = @import("codegen");
const scanner = codegen.idl_scanner;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.next();

    // Parse arguments
    var idl_dir: ?[]const u8 = null;
    var output_path: []const u8 = ".beads/idl_metadata.json";

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--output")) {
            output_path = args.next() orelse {
                std.debug.print("Error: --output requires a path\n", .{});
                return error.MissingOutputPath;
            };
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printUsage();
            return;
        } else {
            if (idl_dir == null) {
                idl_dir = arg;
            } else {
                std.debug.print("Unknown argument: {s}\n", .{arg});
                printUsage();
                return error.UnknownArgument;
            }
        }
    }

    // Validate required arguments
    if (idl_dir == null) {
        std.debug.print("Error: Missing IDL directory\n\n", .{});
        printUsage();
        return error.MissingIDLDirectory;
    }

    std.debug.print("IDL Scanner\n", .{});
    std.debug.print("===========\n", .{});
    std.debug.print("IDL Directory: {s}\n", .{idl_dir.?});
    std.debug.print("Output:        {s}\n\n", .{output_path});

    // Scan the directory and save metadata
    try scanner.scanAndSave(allocator, idl_dir.?, output_path);

    std.debug.print("\n✓ IDL scanning complete!\n", .{});
}

fn printUsage() void {
    std.debug.print(
        \\IDL Scanner - Parse all IDL files and extract metadata
        \\
        \\Usage: idl-scanner <idl-dir> [options]
        \\
        \\Arguments:
        \\  <idl-dir>           Directory containing .idl files
        \\
        \\Options:
        \\  --output <path>     Output JSON file (default: .beads/idl_metadata.json)
        \\  -h, --help          Show this help message
        \\
    , .{});
}
