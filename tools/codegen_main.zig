//! WebIDL Code Generator CLI
//!
//! Usage:
//!   codegen [<source-dir>...] --dest-root <path> [--force]
//!   codegen [<source-dir>...] --dest-root <path> --check [--scratch <dir>]
//!
//! Every source directory is read into ONE model, so a name in one resolves
//! against the definitions of all of them. With no source, the default sources
//! (specs/idl and specs/supplementary) - which is how the committed tree is made:
//!
//!   zig build codegen -- --dest-root src/webidl/
//!
//! --check regenerates from scratch into --scratch (default tmp/codegen-check)
//! and compares it byte for byte with the generated directories under
//! --dest-root; any difference fails. `zig build codegen-check` runs it.
//!
//! Implementation stubs are always generated to impls_tmp/ (gitignored).
//! These stubs are for REFERENCE ONLY and must be manually migrated to impls/.

const std = @import("std");
const codegen = @import("codegen");
const CodegenConfig = codegen.config.CodegenConfig;

// Zig 0.16 removed std.process.argsWithAllocator and moved the filesystem onto
// std.Io. Both arrive through std.process.Init, which also supplies the gpa, so
// taking Init replaces the hand-rolled allocator setup as well.
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var arg_list = std.ArrayList([]const u8).empty;
    defer arg_list.deinit(allocator);
    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // program name
    while (args.next()) |arg| try arg_list.append(allocator, arg);

    var options = codegen.cli.parseArgs(allocator, arg_list.items) catch |err| {
        std.debug.print("Error: {s}\n\n", .{@errorName(err)});
        try printUsage(io);
        return err;
    };
    defer options.deinit(allocator);

    if (options.help) {
        try printUsage(io);
        return;
    }
    const dest_root = options.dest_root.?;

    for (options.sources) |source| {
        var dir = std.Io.Dir.cwd().openDir(io, source, .{}) catch |err| {
            std.debug.print("Error: source '{s}' is not a readable directory: {}\n", .{ source, err });
            return err;
        };
        dir.close(io);
    }

    if (options.check) return check(allocator, io, options.sources, dest_root, options.scratch orelse "tmp/codegen-check");

    // If --force is specified, delete generated directories (but NEVER impls/)
    if (options.force) {
        std.debug.print("Force clean: removing generated directories (preserving impls/)\n", .{});
        for (codegen.drift.generated_dirs ++ [_][]const u8{"impls_tmp"}) |dir| {
            const path = try std.fs.path.join(allocator, &.{ dest_root, dir });
            defer allocator.free(path);
            std.Io.Dir.cwd().deleteTree(io, path) catch |err| {
                if (err != error.FileNotFound) {
                    std.debug.print("Warning: Could not remove {s}: {}\n", .{ path, err });
                }
            };
        }
    }

    std.debug.print("WebIDL Code Generator\n", .{});
    std.debug.print("=====================\n", .{});
    for (options.sources) |source| std.debug.print("Source:      {s}\n", .{source});
    std.debug.print("Dest Root:   {s}\n\n", .{dest_root});

    var config = CodegenConfig{
        .allocator = allocator,
        .dest_root = dest_root,
    };
    defer config.deinit();

    try codegen.processSources(allocator, options.sources, &config);

    std.debug.print("\n✅ Code generation complete!\n", .{});
}

fn check(allocator: std.mem.Allocator, io: std.Io, sources: []const []const u8, committed_root: []const u8, scratch: []const u8) !void {
    var report = try codegen.drift.check(allocator, io, sources, committed_root, scratch);
    defer report.deinit(allocator);

    if (report.clean()) {
        std.debug.print("\ncodegen-check: the committed generated tree matches a from-scratch regeneration ({d} files)\n", .{report.files_compared});
        return;
    }

    std.debug.print("\ncodegen-check: the committed generated tree under {s} does not match a from-scratch regeneration ({d} files differ):\n", .{ committed_root, report.entries.items.len });
    const shown = @min(report.entries.items.len, 40);
    for (report.entries.items[0..shown]) |entry| {
        const what = switch (entry.kind) {
            .differs => "differs from codegen's output",
            .missing => "is generated but not committed",
            .extra => "is committed but codegen no longer writes it",
        };
        std.debug.print("  {s} {s}\n", .{ entry.path, what });
    }
    if (shown < report.entries.items.len) std.debug.print("  ... and {d} more\n", .{report.entries.items.len - shown});
    std.debug.print(
        \\
        \\Generated files are never edited by hand. Fix src/webidl/codegen/ or the IDL
        \\(specs/idl, specs/supplementary), then regenerate and commit the result:
        \\  zig build codegen -- --dest-root src/webidl/
        \\
    , .{});
    std.process.exit(1);
}

fn printUsage(io: std.Io) !void {
    var buffer: [4096]u8 = undefined;
    const stdout_file = std.Io.File.stdout();
    var stdout_writer = stdout_file.writer(io, &buffer);
    const stdout = &stdout_writer.interface;

    try stdout.writeAll(
        \\WebIDL-to-Zig Code Generator
        \\
        \\Usage:
        \\  codegen [<source-dir>...] --dest-root <path> [--force]
        \\  codegen [<source-dir>...] --dest-root <path> --check [--scratch <dir>]
        \\
        \\Arguments:
        \\  <source-dir>...       Directories of .idl files, read together as ONE model:
        \\                        a name in any of them resolves against all of them.
        \\                        Default: specs/idl specs/supplementary
        \\
        \\Options:
        \\  --dest-root <path>    Root of the generated tree: interfaces/, typedefs/,
        \\                        dictionaries/, enums/, callbacks/, namespaces/, mixins/,
        \\                        and impls_tmp/ (reference stubs, gitignored, never built)
        \\  --force               Delete the generated directories first (never impls/)
        \\  --check               Regenerate from scratch into --scratch and compare it
        \\                        byte for byte with the generated directories under
        \\                        --dest-root; exit 1 on any difference
        \\  --scratch <dir>       Where --check regenerates (default tmp/codegen-check);
        \\                        emptied before and removed after
        \\  --help, -h            Show this help message
        \\
        \\Output is zig fmt-clean, so it diffs cleanly against the committed tree.
        \\
        \\Examples:
        \\  # Regenerate the committed tree (both sources, one model)
        \\  zig build codegen -- --dest-root src/webidl/
        \\
        \\  # Check the committed tree against a from-scratch regeneration
        \\  zig build codegen-check
        \\
    );
    try stdout.flush();
}
