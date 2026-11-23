//! Files a HOST names by path (docs/platform-protocol.md 6.10.3, `userFile`,
//! and a directory's with `userDirectory`),
//! for the POSIX platforms' file_picker capability: a remote end's
//! DOM.setFileInputFiles, an automation's "set input files". Each answer is
//! the PickedFile a picker gives - a token, the file's name, size and
//! modification time - and the token is read with `read` and let go with
//! `release`, or at the Browser's end (`deinit`) when Crane never lets it go.
//!
//! What a token keeps is the path and the file's size and modification time
//! when it was chosen - Chromium's model for a file the user provided: Blink
//! keeps the path (File::CreateForUserProvidedFile) and reads the file when
//! script reads it, and a file changed since its snapshot fails the read
//! (FileReaderLoader: NotReadableError; storage/browser/blob's
//! FileStreamReader checks the modification time it expects). So `read`
//! opens the path each time and drops a read whose file is gone or no longer
//! the size and time it was.
//!
//! The type is not decided here: `mime_type` is empty, and Crane takes the
//! File's type from its name as Blink does (html/file_selection.zig).
//!
//! One table per Browser (each adapter's Extra), its own lock: the agents of
//! one Browser run on threads of their own.

const std = @import("std");
const platform = @import("platform");
const host = @import("host");

const Entry = struct {
    /// OWNED.
    path: []u8,
    size: u64,
    modified_ns: i64,
};

pub const Table = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    /// By token id. An array map: it deletes by swapping, with no tombstone.
    entries: std.AutoArrayHashMapUnmanaged(u64, Entry) = .empty,
    next_id: u64 = 1,

    pub fn init(allocator: std.mem.Allocator) Table {
        return .{ .allocator = allocator };
    }

    /// The Browser's end: every token still held is let go.
    pub fn deinit(self: *Table) void {
        for (self.entries.values()) |entry| self.allocator.free(entry.path);
        self.entries.deinit(self.allocator);
    }

    /// The tokens held now (tests).
    pub fn count(self: *Table) usize {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.entries.count();
    }

    /// `userFile`: a token for the regular file at `path`, answered inside
    /// the call; dropped when there is none or it cannot be read.
    pub fn open(self: *Table, path: platform.Str, reply: platform.Reply(platform.PickedFile)) void {
        const text = path.slice();
        const stat = std.Io.Dir.cwd().statFile(host.io(), text, .{}) catch return reply.drop(reply.context);
        if (stat.kind != .file) return reply.drop(reply.context);
        const modified_ns: i64 = @intCast(stat.mtime.nanoseconds);
        const id = self.add(text, stat.size, modified_ns) catch return reply.drop(reply.context);
        const picked: platform.PickedFile = .{
            .token = .{ .id = id },
            .name = platform.Str.from(std.fs.path.basename(text)),
            .size = stat.size,
            .last_modified = .{ .ns_since_epoch = modified_ns },
        };
        reply.deliver(reply.context, &picked);
    }

    /// `userDirectory`: a token for every regular file under the directory
    /// at `path`, at any depth (a symbolic link counts as what it names),
    /// with its relative path - the directory's own name, then the path under
    /// it, '/'-separated (Blink's FileInputType::CreateFileList: the chosen
    /// directory's parent is the root the relative paths start from). Sorted
    /// by relative path; Chrome lists them in the order the file system
    /// gives (FileSelectHelper's net::DirectoryLister, NO_SORT_RECURSIVE), so
    /// the order is the one thing a page could see differ. Dropped when
    /// `path` is no directory that can be listed.
    pub fn openDirectory(self: *Table, path: platform.Str, reply: platform.Reply(platform.PickedFiles)) void {
        var arena_state = std.heap.ArenaAllocator.init(self.allocator);
        defer arena_state.deinit();
        const files = self.listDirectory(arena_state.allocator(), path.slice()) catch return reply.drop(reply.context);
        reply.deliver(reply.context, &platform.PickedFiles{ .ptr = files.ptr, .len = files.len });
    }

    const Found = struct { relative: []const u8, full: []const u8, size: u64, modified_ns: i64 };

    fn listDirectory(self: *Table, arena: std.mem.Allocator, path: []const u8) ![]platform.PickedFile {
        const io = host.io();
        var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
        defer dir.close(io);
        const trimmed = std.mem.trimEnd(u8, path, "/");
        const base_name = std.fs.path.basename(if (trimmed.len == 0) path else trimmed);
        var found: std.ArrayList(Found) = .empty;
        var walker = try dir.walk(arena);
        defer walker.deinit();
        while (try walker.next(io)) |entry| {
            if (entry.kind != .file and entry.kind != .sym_link) continue;
            const stat = entry.dir.statFile(io, entry.basename, .{}) catch continue;
            if (stat.kind != .file) continue;
            try found.append(arena, .{
                .relative = try std.fmt.allocPrint(arena, "{s}/{s}", .{ base_name, entry.path }),
                .full = try std.fs.path.join(arena, &.{ path, entry.path }),
                .size = stat.size,
                .modified_ns = @intCast(stat.mtime.nanoseconds),
            });
        }
        std.mem.sort(Found, found.items, {}, struct {
            fn less(_: void, a: Found, b: Found) bool {
                return std.mem.lessThan(u8, a.relative, b.relative);
            }
        }.less);
        const out = try arena.alloc(platform.PickedFile, found.items.len);
        var added: usize = 0;
        errdefer for (out[0..added]) |picked| self.release(picked.token);
        for (found.items, out) |item, *picked| {
            const id = try self.add(item.full, item.size, item.modified_ns);
            added += 1;
            picked.* = .{
                .token = .{ .id = id },
                .name = platform.Str.from(std.fs.path.basename(item.full)),
                .size = item.size,
                .last_modified = .{ .ns_since_epoch = item.modified_ns },
                .relative_path = platform.Str.from(item.relative),
            };
        }
        return out;
    }

    fn add(self: *Table, path: []const u8, size: u64, modified_ns: i64) error{OutOfMemory}!u64 {
        const copy = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(copy);
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const id = self.next_id;
        try self.entries.put(self.allocator, id, .{ .path = copy, .size = size, .modified_ns = modified_ns });
        self.next_id += 1;
        return id;
    }

    /// `readPickedFile`: up to `length` bytes at `offset`, fewer at the end
    /// of the file. Dropped for a token this table does not hold, a file gone
    /// or changed since it was chosen, or a failed read.
    pub fn read(self: *Table, file: platform.FileToken, offset: u64, length: u32, reply: platform.Reply(platform.Bytes)) void {
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        var expected: Entry = undefined;
        {
            std.Io.Threaded.mutexLockUncancelable(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            const entry = self.entries.get(file.id) orelse return reply.drop(reply.context);
            if (entry.path.len > path_buffer.len) return reply.drop(reply.context);
            @memcpy(path_buffer[0..entry.path.len], entry.path);
            expected = .{ .path = path_buffer[0..entry.path.len], .size = entry.size, .modified_ns = entry.modified_ns };
        }
        const io = host.io();
        const handle = std.Io.Dir.cwd().openFile(io, expected.path, .{}) catch return reply.drop(reply.context);
        defer handle.close(io);
        const stat = handle.stat(io) catch return reply.drop(reply.context);
        // The snapshot check: the file the user chose, unchanged.
        if (stat.kind != .file or stat.size != expected.size or @as(i64, @intCast(stat.mtime.nanoseconds)) != expected.modified_ns) return reply.drop(reply.context);
        const available = if (offset >= stat.size) 0 else stat.size - offset;
        const wanted: usize = @intCast(@min(available, length));
        const buffer = self.allocator.alloc(u8, wanted) catch return reply.drop(reply.context);
        defer self.allocator.free(buffer);
        const got = handle.readPositionalAll(io, buffer, offset) catch return reply.drop(reply.context);
        reply.deliver(reply.context, &platform.Bytes.from(buffer[0..got]));
    }

    /// `releasePickedFile`: a token let go; one not held is ignored.
    pub fn release(self: *Table, file: platform.FileToken) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const removed = self.entries.fetchSwapRemove(file.id) orelse return;
        self.allocator.free(removed.value.path);
    }
};
