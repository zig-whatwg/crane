//! The codegen drift check fails on drift and on hand-edited generated files.

const std = @import("std");
const codegen = @import("codegen");
const drift = codegen.drift;
const testing = std.testing;

const Trees = struct {
    tmp: testing.TmpDir,
    committed: [:0]u8,
    generated: [:0]u8,

    fn init() !Trees {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        for ([_][]const u8{ "committed/typedefs", "committed/enums", "generated/typedefs", "generated/enums" }) |dir| {
            try tmp.dir.createDirPath(testing.io, dir);
        }
        const committed = try tmp.dir.realPathFileAlloc(testing.io, "committed", testing.allocator);
        errdefer testing.allocator.free(committed);
        const generated = try tmp.dir.realPathFileAlloc(testing.io, "generated", testing.allocator);
        return .{ .tmp = tmp, .committed = committed, .generated = generated };
    }

    fn deinit(self: *Trees) void {
        testing.allocator.free(self.committed);
        testing.allocator.free(self.generated);
        self.tmp.cleanup();
    }

    fn write(self: *Trees, sub_path: []const u8, data: []const u8) !void {
        try self.tmp.dir.writeFile(testing.io, .{ .sub_path = sub_path, .data = data });
    }

    /// The same two files in both trees.
    fn writeBoth(self: *Trees) !void {
        for ([_][]const u8{ "committed", "generated" }) |side| {
            const a = try std.fmt.allocPrint(testing.allocator, "{s}/typedefs/A.zig", .{side});
            defer testing.allocator.free(a);
            try self.write(a, "pub const A = u32;\n");
            const b = try std.fmt.allocPrint(testing.allocator, "{s}/enums/B.zig", .{side});
            defer testing.allocator.free(b);
            try self.write(b, "pub const B = enum { x };\n");
        }
    }

    fn compare(self: *Trees) !drift.Report {
        return drift.compareTrees(testing.allocator, testing.io, self.committed, self.generated, &.{ "typedefs", "enums" });
    }
};

fn expectOnly(report: drift.Report, kind: drift.Kind, path: []const u8) !void {
    try testing.expectEqual(@as(usize, 1), report.entries.items.len);
    try testing.expectEqual(kind, report.entries.items[0].kind);
    try testing.expectEqualStrings(path, report.entries.items[0].path);
}

test "identical trees are clean" {
    var t = try Trees.init();
    defer t.deinit();
    try t.writeBoth();
    var report = try t.compare();
    defer report.deinit(testing.allocator);
    try testing.expect(report.clean());
    try testing.expectEqual(@as(usize, 2), report.files_compared);
}

test "a hand-edited generated file is reported" {
    var t = try Trees.init();
    defer t.deinit();
    try t.writeBoth();
    try t.write("committed/typedefs/A.zig", "pub const A = u64; // hand edit\n");
    var report = try t.compare();
    defer report.deinit(testing.allocator);
    try testing.expect(!report.clean());
    try expectOnly(report, .differs, "typedefs/A.zig");
}

test "a file codegen no longer writes is reported" {
    var t = try Trees.init();
    defer t.deinit();
    try t.writeBoth();
    try t.write("committed/enums/Stale.zig", "pub const Stale = enum { y };\n");
    var report = try t.compare();
    defer report.deinit(testing.allocator);
    try expectOnly(report, .extra, "enums/Stale.zig");
}

test "a generated file that is not committed is reported" {
    var t = try Trees.init();
    defer t.deinit();
    try t.writeBoth();
    try t.write("generated/typedefs/New.zig", "pub const New = bool;\n");
    var report = try t.compare();
    defer report.deinit(testing.allocator);
    try expectOnly(report, .missing, "typedefs/New.zig");
}

const fixture_sources = [_][]const u8{ "tests/codegen/fixtures/two_sources/idl", "tests/codegen/fixtures/two_sources/supplementary" };

test "check: a tree regenerated from the same sources is clean, and a hand edit to it fails the check" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const committed = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(committed);
    const scratch = try std.fs.path.join(testing.allocator, &.{ committed, "scratch" });
    defer testing.allocator.free(scratch);

    // "Commit" a regeneration.
    var cfg = codegen.config.CodegenConfig{ .allocator = testing.allocator, .dest_root = committed };
    defer cfg.deinit();
    try codegen.processSources(testing.allocator, &fixture_sources, &cfg);

    {
        var report = try drift.check(testing.allocator, testing.io, &fixture_sources, committed, scratch);
        defer report.deinit(testing.allocator);
        try testing.expect(report.clean());
        try testing.expect(report.files_compared > 0);
    }
    // The scratch tree is removed after the check.
    try testing.expectError(error.FileNotFound, tmp.dir.access(testing.io, "scratch", .{}));

    try tmp.dir.writeFile(testing.io, .{ .sub_path = "typedefs/WindowProxy.zig", .data = "pub const WindowProxy = u8; // hand edit\n" });
    var report = try drift.check(testing.allocator, testing.io, &fixture_sources, committed, scratch);
    defer report.deinit(testing.allocator);
    try expectOnly(report, .differs, "typedefs/WindowProxy.zig");
}
