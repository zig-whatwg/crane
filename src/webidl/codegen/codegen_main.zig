//! # webidl-codegen - Command-line code generator for WebIDL
//!
//! This is the main entry point for the `webidl-codegen` executable, which scans
//! Zig source files for `webidl.interface()` and `webidl.mixin()` declarations and
//! generates enhanced code with inheritance, properties, and method wrappers.
//!
//! ## Usage
//!
//! ```bash
//! webidl-codegen --source-dir src --output-dir .zig-cache/zoop-generated
//! ```
//!
//! ## Command-Line Interface
//!
//! ### Required Arguments
//!
//! - `--source-dir <dir>` - Directory to scan for `.zig` files containing `webidl.interface()` and `webidl.mixin()`
//! - `--output-dir <dir>` - Directory where generated code will be written
//!
//! ### Optional Arguments
//!
//! - `--getter-prefix <str>` - Prefix for property getters (default: "get_")
//! - `--setter-prefix <str>` - Prefix for property setters (default: "set_")
//! - `-h, --help` - Show help message
//!
//! Note: Inherited methods are copied directly without prefixes.
//!
//! ## Security
//!
//! This tool includes path traversal protection:
//!
//! - **Blocks** paths containing `..` (error)
//! - **Warns** about absolute paths (allows but warns)
//! - Only processes files within specified directories
//!
//! This prevents malicious source files from causing the generator to read/write
//! outside intended directories.
//!
//! ## Integration
//!
//! Typically called from build.zig:
//!
//! ```zig
//! const codegen_exe = zoop_dep.artifact("webidl-codegen");
//! const gen_cmd = b.addRunArtifact(codegen_exe);
//! gen_cmd.addArgs(&.{
//!     "--source-dir", "src",
//!     "--output-dir", ".zig-cache/zoop-generated",
//! });
//! exe.step.dependOn(&gen_cmd.step);
//! ```
//!
//! See CONSUMER_USAGE.md for complete integration examples.

const std = @import("std");
const codegen = @import("codegen.zig");

/// Main entry point for webidl-codegen executable.
///
/// Parses command-line arguments, validates paths for security, and invokes
/// the code generation engine.
///
/// ## Process
///
/// 1. Parse command-line arguments
/// 2. Validate required arguments present
/// 3. Security check: validate paths for traversal attempts
/// 4. Invoke codegen.generateAllClasses()
/// 5. Report success or error
///
/// ## Exit Codes
///
/// - 0: Success
/// - Non-zero: Error (missing args, invalid paths, generation failure, etc.)
///
/// ## Errors
///
/// Returns error if:
/// - Missing required arguments (--source-dir, --output-dir)
/// - Unknown arguments provided
/// - Path traversal detected (`..` in paths)
/// - Code generation fails (invalid syntax, I/O errors, etc.)
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("ERROR: Memory leak detected in webidl-codegen!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.next();

    // Initialize configuration with defaults
    var config = codegen.ClassConfig{};
    var source_dir: ?[]const u8 = null;
    var output_dir: ?[]const u8 = null;

    // Parse command-line arguments
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--source-dir")) {
            source_dir = args.next() orelse {
                std.debug.print("Error: --source-dir requires a value\n", .{});
                return error.MissingValue;
            };
        } else if (std.mem.eql(u8, arg, "--output-dir")) {
            output_dir = args.next() orelse {
                std.debug.print("Error: --output-dir requires a value\n", .{});
                return error.MissingValue;
            };
        } else if (std.mem.eql(u8, arg, "--method-prefix")) {
            // Deprecated: method_prefix is no longer used
            _ = args.next() orelse {
                std.debug.print("Error: --method-prefix requires a value\n", .{});
                return error.MissingValue;
            };
            std.debug.print("Warning: --method-prefix is deprecated and no longer used. Methods are copied directly without prefixes.\n", .{});
        } else if (std.mem.eql(u8, arg, "--getter-prefix")) {
            config.getter_prefix = args.next() orelse {
                std.debug.print("Error: --getter-prefix requires a value\n", .{});
                return error.MissingValue;
            };
        } else if (std.mem.eql(u8, arg, "--setter-prefix")) {
            config.setter_prefix = args.next() orelse {
                std.debug.print("Error: --setter-prefix requires a value\n", .{});
                return error.MissingValue;
            };
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            return;
        } else {
            std.debug.print("Unknown argument: {s}\n", .{arg});
            printHelp();
            return error.UnknownArgument;
        }
    }

    // Validate required arguments
    if (source_dir == null or output_dir == null) {
        std.debug.print("Error: --source-dir and --output-dir are required\n\n", .{});
        printHelp();
        return error.MissingArguments;
    }

    // Security: Validate paths for path traversal attempts
    const src = source_dir.?;
    const out = output_dir.?;

    // Block parent directory references (path traversal attacks)
    if (std.mem.indexOf(u8, src, "..") != null) {
        std.debug.print("Error: Source directory contains '..' - path traversal not allowed: {s}\n", .{src});
        std.debug.print("For security reasons, paths with '..' are not permitted.\n", .{});
        std.debug.print("Use absolute paths or paths without '..' instead.\n", .{});
        return error.UnsafePath;
    }

    if (std.mem.indexOf(u8, out, "..") != null) {
        std.debug.print("Error: Output directory contains '..' - path traversal not allowed: {s}\n", .{out});
        std.debug.print("For security reasons, paths with '..' are not permitted.\n", .{});
        std.debug.print("Use absolute paths or paths without '..' instead.\n", .{});
        return error.UnsafePath;
    }

    // Warn about absolute paths (allowed but potentially surprising)
    if ((src.len > 0 and src[0] == '/') or (src.len >= 2 and src[1] == ':')) {
        std.debug.print("Warning: Using absolute path for source directory: {s}\n", .{src});
    }

    if ((out.len > 0 and out[0] == '/') or (out.len >= 2 and out[1] == ':')) {
        std.debug.print("Warning: Using absolute path for output directory: {s}\n", .{out});
    }

    std.debug.print("[webidl-codegen] Scanning {s} for class definitions...\n", .{source_dir.?});

    codegen.generateAllClasses(
        allocator,
        source_dir.?,
        output_dir.?,
        config,
    ) catch |err| {
        std.debug.print("ERROR: Code generation failed: {}\n", .{err});
        std.debug.print("Please check the error messages above for details.\n", .{});
        return err;
    };

    std.debug.print("[webidl-codegen] ✓ Generated classes in {s}\n", .{output_dir.?});
}

/// Print command-line help message.
///
/// Displays usage instructions, argument descriptions, and examples.
fn printHelp() void {
    std.debug.print(
        \\webidl-codegen - Automatic OOP code generator for Zig
        \\
        \\Scans Zig source files for webidl.interface() and webidl.mixin() declarations and 
        \\generates enhanced code with inheritance, properties, and zero-cost method wrappers.
        \\
        \\USAGE:
        \\    webidl-codegen --source-dir <dir> --output-dir <dir> [OPTIONS]
        \\
        \\REQUIRED ARGUMENTS:
        \\    --source-dir <dir>      Directory to scan for class and mixin definitions
        \\                            Must contain .zig files with webidl.interface() or webidl.mixin() calls
        \\
        \\    --output-dir <dir>      Directory to write generated code
        \\                            Creates same directory structure as source
        \\
        \\OPTIONAL ARGUMENTS:
        \\    --getter-prefix <str>   Prefix for property getters (default: "get_")
        \\                            Example: user.get_email()
        \\
        \\    --setter-prefix <str>   Prefix for property setters (default: "set_")
        \\                            Example: user.set_email("new@...")
        \\
        \\    -h, --help              Show this help message
        \\
        \\NOTES:
        \\    - Inherited methods are copied directly without prefixes
        \\    - Only property accessors use configurable prefixes
        \\
        \\EXAMPLES:
        \\    # Standard usage with default property prefixes
        \\    webidl-codegen --source-dir src --output-dir .zig-cache/zoop-generated
        \\
        \\    # Custom property prefixes
        \\    webidl-codegen --source-dir src --output-dir generated \
        \\        --getter-prefix "read_" \
        \\        --setter-prefix "write_"
        \\
        \\    # No property prefixes
        \\    webidl-codegen --source-dir src --output-dir generated \
        \\        --getter-prefix "" \
        \\        --setter-prefix ""
        \\
        \\    # Manual generation workflow (review before merging)
        \\    webidl-codegen --source-dir .codegen-input --output-dir src-generated
        \\    diff -r src/ src-generated/  # Review changes
        \\    # Manually merge updates, then:
        \\    rm -rf src-generated/
        \\
        \\SECURITY:
        \\    - Paths containing '..' are blocked (path traversal protection)
        \\    - Absolute paths are allowed but generate warnings
        \\    - Only processes files within specified directories
        \\
        \\SEE ALSO:
        \\    README.md         - Overview and quick start
        \\    CONSUMER_USAGE.md - Integration patterns and workflows
        \\    API_REFERENCE.md  - Complete API documentation
        \\
    , .{});
}
