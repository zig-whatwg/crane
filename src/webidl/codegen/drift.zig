//! The codegen drift check: compare a from-scratch regeneration with the
//! committed generated tree, file by file and byte for byte.

const std = @import("std");

/// The generated directories under src/webidl/ (impls_tmp/ is gitignored and
/// impls/ is hand-written, so neither is compared).
pub const generated_dirs = [_][]const u8{ "interfaces", "typedefs", "dictionaries", "callbacks", "mixins", "namespaces", "enums" };

pub const Kind = enum { differs, missing, extra };

pub const Entry = struct {
    kind: Kind,
    /// "<dir>/<file>", owned by the report.
    path: []const u8,
};

pub const Report = struct {
    entries: std.ArrayList(Entry) = .empty,
    files_compared: usize = 0,

    pub fn deinit(self: *Report, allocator: std.mem.Allocator) void {
        for (self.entries.items) |entry| allocator.free(entry.path);
        self.entries.deinit(allocator);
    }

    pub fn clean(self: *const Report) bool {
        return self.entries.items.len == 0;
    }
};

/// Compare `dirs` under `committed_root` (the tree in git) with the same
/// dirs under `generated_root` (a fresh regeneration). Every file in either
/// is accounted for: in both and byte-identical (counted in files_compared),
/// in both and different (`differs`, e.g. a hand edit), only generated
/// (`missing` from the commit) or only committed (`extra`: codegen no longer
/// writes it).
pub fn compareTrees(
    allocator: std.mem.Allocator,
    io: std.Io,
    committed_root: []const u8,
    generated_root: []const u8,
    dirs: []const []const u8,
) !Report {
    var report: Report = .{};
    errdefer report.deinit(allocator);

    for (dirs) |dir| {
        const committed_dir = try std.fs.path.join(allocator, &.{ committed_root, dir });
        defer allocator.free(committed_dir);
        const generated_dir = try std.fs.path.join(allocator, &.{ generated_root, dir });
        defer allocator.free(generated_dir);

        const committed_names = try listFiles(allocator, io, committed_dir);
        defer freeNames(allocator, committed_names);
        const generated_names = try listFiles(allocator, io, generated_dir);
        defer freeNames(allocator, generated_names);

        // Both lists are sorted: merge them.
        var c: usize = 0;
        var g: usize = 0;
        while (c < committed_names.len or g < generated_names.len) {
            const order: std.math.Order = if (c == committed_names.len)
                .gt
            else if (g == generated_names.len)
                .lt
            else
                std.mem.order(u8, committed_names[c], generated_names[g]);
            switch (order) {
                .lt => {
                    try addEntry(allocator, &report, .extra, dir, committed_names[c]);
                    c += 1;
                },
                .gt => {
                    try addEntry(allocator, &report, .missing, dir, generated_names[g]);
                    g += 1;
                },
                .eq => {
                    const name = committed_names[c];
                    if (!try sameContent(allocator, io, committed_dir, generated_dir, name)) {
                        try addEntry(allocator, &report, .differs, dir, name);
                    } else {
                        report.files_compared += 1;
                    }
                    c += 1;
                    g += 1;
                },
            }
        }
    }
    return report;
}

fn addEntry(allocator: std.mem.Allocator, report: *Report, kind: Kind, dir: []const u8, name: []const u8) !void {
    const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir, name });
    errdefer allocator.free(path);
    try report.entries.append(allocator, .{ .kind = kind, .path = path });
}

/// The sorted names of the regular files in `dir_path`; none if it does not exist.
fn listFiles(allocator: std.mem.Allocator, io: std.Io, dir_path: []const u8) ![][]const u8 {
    var names = std.ArrayList([]const u8).empty;
    errdefer {
        for (names.items) |name| allocator.free(name);
        names.deinit(allocator);
    }
    var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return names.toOwnedSlice(allocator),
        else => return err,
    };
    defer dir.close(io);
    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const name = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(name);
        try names.append(allocator, name);
    }
    std.mem.sort([]const u8, names.items, {}, lessThan);
    return names.toOwnedSlice(allocator);
}

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn freeNames(allocator: std.mem.Allocator, names: []const []const u8) void {
    for (names) |name| allocator.free(name);
    allocator.free(names);
}

const max_file_size = 16 * 1024 * 1024;

fn sameContent(allocator: std.mem.Allocator, io: std.Io, dir_a: []const u8, dir_b: []const u8, name: []const u8) !bool {
    const path_a = try std.fs.path.join(allocator, &.{ dir_a, name });
    defer allocator.free(path_a);
    const path_b = try std.fs.path.join(allocator, &.{ dir_b, name });
    defer allocator.free(path_b);
    const a = try std.Io.Dir.cwd().readFileAlloc(io, path_a, allocator, .limited(max_file_size));
    defer allocator.free(a);
    const b = try std.Io.Dir.cwd().readFileAlloc(io, path_b, allocator, .limited(max_file_size));
    defer allocator.free(b);
    return std.mem.eql(u8, a, b);
}

/// The drift check: regenerate `sources` from scratch into `scratch_root`
/// (emptied first, removed after), then compare it with the generated
/// directories under `committed_root`.
pub fn check(
    allocator: std.mem.Allocator,
    io: std.Io,
    sources: []const []const u8,
    committed_root: []const u8,
    scratch_root: []const u8,
) !Report {
    const pipeline = @import("pipeline.zig");
    const CodegenConfig = @import("config.zig").CodegenConfig;

    try std.Io.Dir.cwd().deleteTree(io, scratch_root);
    defer std.Io.Dir.cwd().deleteTree(io, scratch_root) catch {};

    var cfg = CodegenConfig{ .allocator = allocator, .dest_root = scratch_root };
    defer cfg.deinit();
    try pipeline.processSources(allocator, sources, &cfg);

    return compareTrees(allocator, io, committed_root, scratch_root, &generated_dirs);
}
