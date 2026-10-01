//! The codegen command line (tools/codegen_main.zig), parsed here so that
//! tests/codegen can pin it.

const std = @import("std");

/// The sources one invocation reads when none is named: the pinned webref
/// snapshot and Crane's supplementary IDL, resolved as ONE model.
pub const default_sources = [_][]const u8{ "specs/idl", "specs/supplementary" };

pub const Options = struct {
    /// Borrowed from the arguments (or `default_sources`); the slice itself is owned.
    sources: []const []const u8,
    dest_root: ?[]const u8 = null,
    force: bool = false,
    help: bool = false,
    /// Regenerate into `scratch` and compare with the generated directories
    /// under `dest_root` instead of writing there.
    check: bool = false,
    scratch: ?[]const u8 = null,

    pub fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        allocator.free(self.sources);
    }
};

/// Parse the codegen arguments (without the program name).
///
///   codegen [<source-dir>...] --dest-root <path> [--force]
///   codegen [<source-dir>...] --dest-root <path> --check [--scratch <dir>]
///
/// Every source is read into ONE model. With no source, `default_sources`.
/// An argument starting with `-` that is not a known flag is an error, never
/// a source.
pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    var sources = std.ArrayList([]const u8).empty;
    errdefer sources.deinit(allocator);
    var options: Options = .{ .sources = &.{} };

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--dest-root")) {
            i += 1;
            if (i >= args.len) return error.MissingDestRoot;
            options.dest_root = args[i];
        } else if (std.mem.eql(u8, arg, "--scratch")) {
            i += 1;
            if (i >= args.len) return error.MissingScratch;
            options.scratch = args[i];
        } else if (std.mem.eql(u8, arg, "--check")) {
            options.check = true;
        } else if (std.mem.eql(u8, arg, "--force")) {
            options.force = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            options.help = true;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            return error.UnknownArgument;
        } else {
            try sources.append(allocator, arg);
        }
    }

    if (sources.items.len == 0) try sources.appendSlice(allocator, &default_sources);
    if (options.dest_root == null and !options.help) return error.MissingDestRoot;
    options.sources = try sources.toOwnedSlice(allocator);
    return options;
}
