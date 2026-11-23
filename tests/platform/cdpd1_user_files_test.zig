//! Lane cdpd1 (D9, main's ruling 2026-11-23): files a host names by path,
//! through the platform protocol (docs/platform-protocol.md 6.10.3 userFile,
//! userDirectory, readPickedFile, releasePickedFile) on the bound built-in
//! platform - darwin, linux or testing, each kit/posix/user_files per
//! Browser. The Browser here is made with std.testing.allocator, so a token
//! the platform kept past destroyBrowserPlatform fails the test as a leak
//! (and `leaks --atExit` over this file names any C-side one).

const std = @import("std");
const platform = @import("platform");
const testing = std.testing;

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

/// What one reply gave, copied ("Crane copies what it keeps").
const Got = struct {
    delivered: bool = false,
    dropped: bool = false,
    files: [8]File = undefined,
    count: usize = 0,
    bytes: [64]u8 = undefined,
    bytes_len: usize = 0,

    const File = struct {
        token: platform.FileToken,
        name: [64]u8 = undefined,
        name_len: usize = 0,
        relative: [96]u8 = undefined,
        relative_len: usize = 0,
        size: u64,
        modified_ns: i64,

        fn name_(self: *const File) []const u8 {
            return self.name[0..self.name_len];
        }

        fn relative_(self: *const File) []const u8 {
            return self.relative[0..self.relative_len];
        }
    };

    fn keep(self: *Got, picked: *const platform.PickedFile) void {
        var kept: File = .{ .token = picked.token, .size = picked.size, .modified_ns = picked.last_modified.ns_since_epoch };
        const name = picked.name.slice();
        @memcpy(kept.name[0..name.len], name);
        kept.name_len = name.len;
        const relative = picked.relative_path.slice();
        @memcpy(kept.relative[0..relative.len], relative);
        kept.relative_len = relative.len;
        self.files[self.count] = kept;
        self.count += 1;
    }

    fn file(self: *Got) platform.Reply(platform.PickedFile) {
        return .{ .context = self, .deliver = &deliverFile, .drop = &drop };
    }

    fn directory(self: *Got) platform.Reply(platform.PickedFiles) {
        return .{ .context = self, .deliver = &deliverFiles, .drop = &drop };
    }

    fn data(self: *Got) platform.Reply(platform.Bytes) {
        return .{ .context = self, .deliver = &deliverBytes, .drop = &drop };
    }

    fn deliverFile(context: *anyopaque, value: *const platform.PickedFile) callconv(.c) void {
        const self: *Got = @ptrCast(@alignCast(context));
        self.delivered = true;
        self.keep(value);
    }

    fn deliverFiles(context: *anyopaque, value: *const platform.PickedFiles) callconv(.c) void {
        const self: *Got = @ptrCast(@alignCast(context));
        self.delivered = true;
        for (value.ptr[0..value.len]) |*picked| self.keep(picked);
    }

    fn deliverBytes(context: *anyopaque, value: *const platform.Bytes) callconv(.c) void {
        const self: *Got = @ptrCast(@alignCast(context));
        self.delivered = true;
        const bytes = value.slice();
        @memcpy(self.bytes[0..bytes.len], bytes);
        self.bytes_len = bytes.len;
    }

    fn drop(context: *anyopaque) callconv(.c) void {
        const self: *Got = @ptrCast(@alignCast(context));
        self.dropped = true;
    }
};

/// The absolute path of `sub_path` in `tmp` (OWNED).
fn pathIn(tmp: *testing.TmpDir, sub_path: []const u8) ![]u8 {
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const len = try tmp.dir.realPathFile(testing.io, ".", &buffer);
    if (sub_path.len == 0) return testing.allocator.dupe(u8, buffer[0..len]);
    return std.fs.path.join(testing.allocator, &.{ buffer[0..len], sub_path });
}

test "the built-in platforms answer files a host names (file_picker emulated: no picker UI)" {
    try testing.expectEqual(platform.Support.emulated, platform.capabilities.file_picker);
}

test "userFile answers the file's name, size and time; reads are positional; a file changed since it was chosen drops; release lets the token go" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "note.txt", .data = "hello file" });
    const path = try pathIn(&tmp, "note.txt");
    defer testing.allocator.free(path);

    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    var got: Got = .{};
    platform.userFile(browser, platform.Str.from(path), got.file());
    try testing.expect(got.delivered);
    const picked = got.files[0];
    try testing.expectEqualStrings("note.txt", picked.name_());
    try testing.expectEqualStrings("", picked.relative_());
    try testing.expectEqual(@as(u64, 10), picked.size);

    var part: Got = .{};
    platform.readPickedFile(browser, picked.token, 6, 32, part.data());
    try testing.expectEqualStrings("file", part.bytes[0..part.bytes_len]);

    // Blink's snapshot rule: a file modified since it was chosen fails the read.
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "note.txt", .data = "a longer replacement" });
    var changed: Got = .{};
    platform.readPickedFile(browser, picked.token, 0, 32, changed.data());
    try testing.expect(changed.dropped);

    platform.releasePickedFile(browser, picked.token);
    var gone: Got = .{};
    platform.readPickedFile(browser, picked.token, 0, 4, gone.data());
    try testing.expect(gone.dropped);
}

test "a path naming no regular file drops, and tokens never read nor released are let go at the Browser's end" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "a.bin", .data = "abc" });
    const directory = try pathIn(&tmp, "");
    defer testing.allocator.free(directory);
    const file = try pathIn(&tmp, "a.bin");
    defer testing.allocator.free(file);
    const missing = try pathIn(&tmp, "missing");
    defer testing.allocator.free(missing);

    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    var not_a_file: Got = .{};
    platform.userFile(browser, platform.Str.from(directory), not_a_file.file());
    try testing.expect(not_a_file.dropped);
    var absent: Got = .{};
    platform.userFile(browser, platform.Str.from(missing), absent.file());
    try testing.expect(absent.dropped);
    // Two tokens taken and never read nor released: the Browser's end lets
    // them go (std.testing.allocator reports what it did not).
    var first: Got = .{};
    platform.userFile(browser, platform.Str.from(file), first.file());
    var second: Got = .{};
    platform.userFile(browser, platform.Str.from(file), second.file());
    try testing.expect(first.files[0].token.id != second.files[0].token.id);
    platform.destroyBrowserPlatform(browser);
}

test "userDirectory answers every regular file under it with its relative path, the directory's name first, sorted" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "photos/2026");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "photos/b.txt", .data = "bb" });
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "photos/2026/a.jpg", .data = "aaa" });
    const photos = try pathIn(&tmp, "photos");
    defer testing.allocator.free(photos);
    const file = try pathIn(&tmp, "photos/b.txt");
    defer testing.allocator.free(file);

    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    var got: Got = .{};
    platform.userDirectory(browser, platform.Str.from(photos), got.directory());
    try testing.expect(got.delivered);
    try testing.expectEqual(@as(usize, 2), got.count);
    try testing.expectEqualStrings("photos/2026/a.jpg", got.files[0].relative_());
    try testing.expectEqualStrings("a.jpg", got.files[0].name_());
    try testing.expectEqual(@as(u64, 3), got.files[0].size);
    try testing.expectEqualStrings("photos/b.txt", got.files[1].relative_());
    var bytes: Got = .{};
    platform.readPickedFile(browser, got.files[1].token, 0, 8, bytes.data());
    try testing.expectEqualStrings("bb", bytes.bytes[0..bytes.bytes_len]);

    // A file is no directory to list.
    var not_a_directory: Got = .{};
    platform.userDirectory(browser, platform.Str.from(file), not_a_directory.directory());
    try testing.expect(not_a_directory.dropped);
}
