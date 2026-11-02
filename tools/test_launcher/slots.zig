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
    /// The directory's path, for messages (the caller keeps it alive).
    path: []const u8,

    /// Opens (creating it) the slot directory `path` with `count` slots.
    pub fn open(io: Io, path: []const u8, count: u32) !Slots {
        try Io.Dir.cwd().createDirPath(io, path);
        const dir = try Io.Dir.cwd().openDir(io, path, .{});
        return .{ .io = io, .dir = dir, .count = @max(count, 1), .path = path };
    }

    pub fn close(s: *Slots) void {
        s.dir.close(s.io);
    }

    /// One held slot: the open, locked file.
    pub const Slot = struct {
        file: Io.File,
    };

    /// A free slot now, or null when all are held. On an error, `failed`
    /// (when given) is the slot whose file could not be opened.
    pub fn tryAcquire(s: *Slots, failed: ?*u32) !?Slot {
        var name_buf: [32]u8 = undefined;
        for (0..s.count) |i| {
            const name = std.fmt.bufPrint(&name_buf, "slot-{d}", .{i}) catch unreachable;
            const file = openOrCreate(s.io, s.dir, name) catch |err| {
                if (failed) |f| f.* = @intCast(i);
                return err;
            };
            if (file.tryLock(s.io, .exclusive) catch false) return .{ .file = file };
            file.close(s.io);
        }
        return null;
    }

    /// Waits for a free slot (polling every 20 ms: a slot frees when a test
    /// process ends, and a test process lives far longer than that).
    pub fn acquire(s: *Slots, failed: ?*u32) !Slot {
        while (true) {
            if (try s.tryAcquire(failed)) |slot| return slot;
            try s.io.sleep(.fromMilliseconds(20), .awake);
        }
    }

    pub fn release(s: *Slots, slot: Slot) void {
        slot.file.unlock(s.io);
        slot.file.close(s.io);
    }
};

/// How many times `openOrCreate` meets a creation race on one name before
/// it gives up: each lost race means another creator has just made the
/// file, so the next O_CREAT open finds it.
const max_create_races = 64;

/// Opens the file `name` in `dir`, creating it if it is not there.
///
/// One O_CREAT open is not enough. On macOS, openat(O_CREAT) that races
/// another creator of the same name can fail with ENOENT although the
/// directory is there: in the cold-build test below, 7 of every 8 launchers
/// that met an empty slot directory at the same moment got FileNotFound
/// (macOS 27, chat.local), and the files created beforehand, none. A cold
/// `zig build test` meets exactly that - an empty slot directory and every
/// worker of the first launchers taking a slot at once - and the failed
/// slot was reported as "could not start the test process: FileNotFound"
/// against the batch's tests (lane tlfix1, 2026-11-01).
///
/// std.Build.Cache meets the same race opening its manifests and resolves
/// it the same way (lib/std/Build/Cache.zig, Manifest.hit: "we have
/// observed on macOS two processes racing to do openat() with O_CREAT
/// manifest in ENOENT"): after ENOENT, an O_EXCL create tells the two
/// apart - EEXIST says it was the race (the file exists now, so open it
/// again), ENOENT says the directory itself is gone, a real error.
fn openOrCreate(io: Io, dir: Io.Dir, name: []const u8) !Io.File {
    var races: u32 = 0;
    while (true) {
        if (dir.createFile(io, name, .{ .truncate = false })) |file| return file else |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        }
        if (dir.createFile(io, name, .{ .truncate = false, .exclusive = true })) |file| return file else |err| switch (err) {
            error.PathAlreadyExists => {
                races += 1;
                if (races == max_create_races) return error.FileNotFound;
            },
            else => return err,
        }
    }
}

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

    const first = (try a.tryAcquire(null)).?;
    const second = (try b.tryAcquire(null)).?;
    try testing.expectEqual(@as(?Slots.Slot, null), try a.tryAcquire(null));
    try testing.expectEqual(@as(?Slots.Slot, null), try b.tryAcquire(null));
    a.release(first);
    const third = (try b.tryAcquire(null)).?;
    b.release(second);
    b.release(third);
    // All free again.
    const again = try a.acquire(null);
    a.release(again);
}

const ErrorInt = @TypeOf(@intFromError(@as(anyerror, error.Unset)));

/// One launcher of a cold build: opens the shared slot directory and takes
/// a slot at the same moment as every other.
const ColdLauncher = struct {
    path: []const u8,
    count: u32,
    ready: *std.atomic.Value(u32),
    failures: *std.atomic.Value(u32),
    first_error: *std.atomic.Value(ErrorInt),

    fn run(l: ColdLauncher) void {
        var s = Slots.open(testing.io, l.path, l.count) catch |err| {
            _ = l.ready.fetchAdd(1, .acq_rel);
            return l.fail(err);
        };
        defer s.close();
        // Start together: every launcher meets the not-yet-created slot
        // files at once, as on a cold build.
        _ = l.ready.fetchAdd(1, .acq_rel);
        while (l.ready.load(.acquire) < l.count) std.atomic.spinLoopHint();
        // `count` launchers, `count` slots: every one gets one.
        const slot = (s.tryAcquire(null) catch |err| return l.fail(err)) orelse return l.fail(error.NoSlot);
        s.release(slot);
    }

    fn fail(l: ColdLauncher, err: anyerror) void {
        _ = l.failures.fetchAdd(1, .monotonic);
        _ = l.first_error.cmpxchgStrong(0, @intFromError(err), .monotonic, .monotonic);
    }
};

test "slots: launchers that create the slot files at the same moment all get a slot (a cold build)" {
    // A cold `zig build test` starts launchers - and each launcher its
    // workers - at once into an empty slot directory, each creating slot-0,
    // slot-1, ... (`openOrCreate`). Before the fix, on macOS: 2,087 of these
    // 2,400 failed with FileNotFound; with the slot files made beforehand,
    // none (lane tlfix1).
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const launchers = 8;
    const rounds = 300;
    var failures: std.atomic.Value(u32) = .init(0);
    var first_error: std.atomic.Value(ErrorInt) = .init(0);
    for (0..rounds) |round| {
        const path = try std.fmt.allocPrint(testing.allocator, ".zig-cache/tmp/{s}/round-{d}", .{ tmp.sub_path, round });
        defer testing.allocator.free(path);
        var ready: std.atomic.Value(u32) = .init(0);
        var threads: [launchers]std.Thread = undefined;
        for (&threads) |*t| t.* = try std.Thread.spawn(.{}, ColdLauncher.run, .{ColdLauncher{
            .path = path,
            .count = launchers,
            .ready = &ready,
            .failures = &failures,
            .first_error = &first_error,
        }});
        for (threads) |t| t.join();
    }
    errdefer std.debug.print("{d} of {d} launchers failed to take a slot; first error: {t}\n", .{
        failures.load(.monotonic),
        launchers * rounds,
        @as(anyerror, @errorFromInt(first_error.load(.monotonic))),
    });
    try testing.expectEqual(@as(u32, 0), failures.load(.monotonic));
}

test "slots: a slot directory removed under the launcher is an error that names the slot, not a race to retry forever" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(testing.allocator, ".zig-cache/tmp/{s}/slots", .{tmp.sub_path});
    defer testing.allocator.free(path);
    var s = try Slots.open(testing.io, path, 2);
    defer s.close();
    // Something deletes the directory after the launcher opened it.
    try tmp.dir.deleteTree(testing.io, "slots");
    var failed: u32 = 99;
    try testing.expectError(error.FileNotFound, s.tryAcquire(&failed));
    try testing.expectEqual(@as(u32, 0), failed);
    try testing.expectEqualStrings(path, s.path);
}
