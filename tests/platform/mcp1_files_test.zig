//! Lane mcp1, batch 3: the platform's file operations the MCP server's path
//! policy stands on (chrome-devtools-mcp-v1.13.0 src/McpContext.ts
//! validatePath and #writeFile, src/utils/files.ts resolveCanonicalPath;
//! Node's os.tmpdir):
//! - realPath: a path's canonical form, every symlink resolved; a missing
//!   one is NotFound (the policy then resolves its nearest existing parent);
//! - tempDirectory: the OS temp directory as Node's os.tmpdir() reads it;
//! - writeFilePrivate: created or truncated in place, owner read/write only,
//!   and never through a symbolic link planted at the target (O_NOFOLLOW) -
//!   the security contract (main, 2026-11-24).

const std = @import("std");
const platform = @import("platform");
const testing = std.testing;

/// A fresh directory under tmp/ for one test, removed by the caller.
fn scratch(allocator: std.mem.Allocator) ![]u8 {
    var nonce: [8]u8 = undefined;
    platform.fillRandom(&nonce);
    const root = try std.fmt.allocPrint(allocator, "tmp/mcp1-files-{x}", .{std.mem.readInt(u64, &nonce, .little)});
    try platform.makeDirectoryPath(platform.Str.from(root));
    return root;
}

fn symlink(allocator: std.mem.Allocator, target: []const u8, link: []const u8) !void {
    const target_z = try allocator.dupeZ(u8, target);
    defer allocator.free(target_z);
    const link_z = try allocator.dupeZ(u8, link);
    defer allocator.free(link_z);
    if (std.c.symlink(target_z, link_z) != 0) return error.SymlinkFailed;
}

fn modeOf(allocator: std.mem.Allocator, path: []const u8) !u32 {
    const z = try allocator.dupeZ(u8, path);
    defer allocator.free(z);
    var st: std.c.Stat = undefined;
    if (std.c.stat(z, &st) != 0) return error.StatFailed;
    return @as(u32, @intCast(st.mode)) & 0o777;
}

test "writeFilePrivate: a new file is the owner's alone, an existing one truncated in place" {
    const allocator = testing.allocator;
    const root = try scratch(allocator);
    defer allocator.free(root);
    defer platform.deleteTree(platform.Str.from(root)) catch {};
    const file = try std.fmt.allocPrint(allocator, "{s}/out.txt", .{root});
    defer allocator.free(file);

    try platform.writeFilePrivate(platform.Str.from(file), platform.Bytes.from("a longer first body"));
    try testing.expectEqual(@as(u32, 0o600), try modeOf(allocator, file));
    try platform.writeFilePrivate(platform.Str.from(file), platform.Bytes.from("short"));
    const bytes = try platform.readFile(allocator, platform.Str.from(file), 1024);
    defer allocator.free(bytes);
    try testing.expectEqualStrings("short", bytes);
}

test "writeFilePrivate: a symbolic link planted at the target is refused and its target untouched" {
    const allocator = testing.allocator;
    const root = try scratch(allocator);
    defer allocator.free(root);
    defer platform.deleteTree(platform.Str.from(root)) catch {};
    const victim = try std.fmt.allocPrint(allocator, "{s}/victim.txt", .{root});
    defer allocator.free(victim);
    const link = try std.fmt.allocPrint(allocator, "{s}/link.txt", .{root});
    defer allocator.free(link);
    try platform.writeFileAtomic(platform.Str.from(victim), platform.Bytes.from("keep"));
    try symlink(allocator, "victim.txt", link);

    try testing.expectError(error.AccessDenied, platform.writeFilePrivate(platform.Str.from(link), platform.Bytes.from("evil")));
    const bytes = try platform.readFile(allocator, platform.Str.from(victim), 1024);
    defer allocator.free(bytes);
    try testing.expectEqualStrings("keep", bytes);
}

test "realPath: symbolic links resolved to an absolute path; a missing path is NotFound" {
    const allocator = testing.allocator;
    const root = try scratch(allocator);
    defer allocator.free(root);
    defer platform.deleteTree(platform.Str.from(root)) catch {};
    const real_dir = try std.fmt.allocPrint(allocator, "{s}/real", .{root});
    defer allocator.free(real_dir);
    try platform.makeDirectoryPath(platform.Str.from(real_dir));
    const linked = try std.fmt.allocPrint(allocator, "{s}/linked", .{root});
    defer allocator.free(linked);
    try symlink(allocator, "real", linked);

    const via_link = try platform.realPath(allocator, platform.Str.from(linked));
    defer allocator.free(via_link);
    const direct = try platform.realPath(allocator, platform.Str.from(real_dir));
    defer allocator.free(direct);
    try testing.expect(std.mem.startsWith(u8, direct, "/"));
    try testing.expect(std.mem.endsWith(u8, direct, "/real"));
    try testing.expectEqualStrings(direct, via_link);

    const missing = try std.fmt.allocPrint(allocator, "{s}/nope/deeper", .{root});
    defer allocator.free(missing);
    try testing.expectError(error.NotFound, platform.realPath(allocator, platform.Str.from(missing)));
}

test "realPath: a path through a file is not 'missing' (ENOTDIR), so the policy stops there" {
    // resolveCanonicalPath walks up past ENOENT only; Node's realpath of
    // "<file>/x" fails ENOTDIR, which ends the walk ("Cannot resolve base
    // path").
    const allocator = testing.allocator;
    const root = try scratch(allocator);
    defer allocator.free(root);
    defer platform.deleteTree(platform.Str.from(root)) catch {};
    const file = try std.fmt.allocPrint(allocator, "{s}/plain.txt", .{root});
    defer allocator.free(file);
    try platform.writeFileAtomic(platform.Str.from(file), platform.Bytes.from("x"));
    const through = try std.fmt.allocPrint(allocator, "{s}/plain.txt/x", .{root});
    defer allocator.free(through);
    try testing.expectError(error.Io, platform.realPath(allocator, platform.Str.from(through)));
}

test "tempDirectory: Node's os.tmpdir() - TMPDIR, TMP or TEMP, else /tmp, without a trailing slash" {
    const allocator = testing.allocator;
    const dir = try platform.tempDirectory(allocator);
    defer allocator.free(dir);
    try testing.expect(dir.len > 0);
    try testing.expect(dir.len == 1 or !std.mem.endsWith(u8, dir, "/"));
    const want: []const u8 = blk: {
        for ([_][*:0]const u8{ "TMPDIR", "TMP", "TEMP" }) |name| {
            if (std.c.getenv(name)) |value| {
                const v = std.mem.span(value);
                if (v.len > 0) break :blk v;
            }
        }
        break :blk "/tmp";
    };
    const trimmed = if (want.len > 1 and std.mem.endsWith(u8, want, "/")) want[0 .. want.len - 1] else want;
    try testing.expectEqualStrings(trimmed, dir);
}
