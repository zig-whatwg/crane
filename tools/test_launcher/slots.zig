//! A cap on test processes shared by every launcher of one build.
//!
//! `zig build test` runs one launcher per test executable, several at once
//! (the build runner's -j), and each starts up to `--jobs` children. Without
//! a shared cap, two launchers on a 14-core host run 28 test processes, and a
//! per-test timeout measures the oversubscription instead of the test. So each
//! child process holds a slot: one of N lock files in a directory every
//! launcher of the build shares (the build's cache directory). A slot is an
//! exclusive `flock` on its file, so the kernel releases it when its holder
//! exits, however it exits - no stale token after a crash or a kill.
//! Chromium's launcher runs one job per core; this makes that hold for the
//! whole build rather than for each launcher.

const std = @import("std");
const Io = std.Io;

pub const Slots = struct {
    io: Io,
    dir: Io.Dir,
    count: u32,

    /// Opens (creating it) the slot directory `path` with `count` slots.
    pub fn open(io: Io, path: []const u8, count: u32) !Slots {
        try Io.Dir.cwd().createDirPath(io, path);
        const dir = try Io.Dir.cwd().openDir(io, path, .{});
        return .{ .io = io, .dir = dir, .count = @max(count, 1) };
    }

    pub fn close(s: *Slots) void {
        s.dir.close(s.io);
    }

    /// One held slot: the open, locked file.
    pub const Slot = struct {
        file: Io.File,
    };

    /// A free slot now, or null when all are held.
    pub fn tryAcquire(s: *Slots) !?Slot {
        var name_buf: [32]u8 = undefined;
        for (0..s.count) |i| {
            const name = std.fmt.bufPrint(&name_buf, "slot-{d}", .{i}) catch unreachable;
            const file = try s.dir.createFile(s.io, name, .{ .truncate = false });
            if (file.tryLock(s.io, .exclusive) catch false) return .{ .file = file };
            file.close(s.io);
        }
        return null;
    }

    /// Waits for a free slot (polling every 20 ms: a slot frees when a test
    /// process ends, and a test process lives far longer than that).
    pub fn acquire(s: *Slots) !Slot {
        while (true) {
            if (try s.tryAcquire()) |slot| return slot;
            try s.io.sleep(.fromMilliseconds(20), .awake);
        }
    }

    pub fn release(s: *Slots, slot: Slot) void {
        slot.file.unlock(s.io);
        slot.file.close(s.io);
    }
};

const testing = std.testing;

test "slots: at most N held at once, across separate opens of the directory" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(testing.allocator, ".zig-cache/tmp/{s}/slots", .{tmp.sub_path});
    defer testing.allocator.free(path);

    // Two launchers of one build: two opens of the same directory.
    var a = try Slots.open(testing.io, path, 2);
    defer a.close();
    var b = try Slots.open(testing.io, path, 2);
    defer b.close();

    const first = (try a.tryAcquire()).?;
    const second = (try b.tryAcquire()).?;
    try testing.expectEqual(@as(?Slots.Slot, null), try a.tryAcquire());
    try testing.expectEqual(@as(?Slots.Slot, null), try b.tryAcquire());
    a.release(first);
    const third = (try b.tryAcquire()).?;
    b.release(second);
    b.release(third);
    // All free again.
    const again = try a.acquire();
    a.release(again);
}
