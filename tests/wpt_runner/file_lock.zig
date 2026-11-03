//! A test file never runs twice at once against one server.
//!
//! That is wptrunner's invariant: each test file runs once per run, its
//! processes run different files, and `--repeat` runs again only after the
//! last run ended. Tests rely on it: a test may name its server-side state - a
//! stash key, a recorded header, a cookie - with a FIXED key, because no other
//! run of that file shares the server meanwhile. Twelve files of
//! fetch/metadata/ alone do (report, preload, style, worker, sharedworker,
//! object, embed, track, unload, text, audio-worklet and paint-worklet record
//! a header under `record-header.py?file=<fixed name>` and take it back with
//! stash.take). Crane's pool broke the invariant: every runner on a host
//! talks to the host's one `wpt serve` (wpt_server.zig adopts whatever
//! answers its port), both sides of an A/B run the same list at once, and
//! lanes' runs overlap. fetch/metadata/report.https.sub.html records its
//! three CSP reports under report-same-origin, -same-site and -cross-site and
//! reads them back a second later, so the run that read first took the
//! other's records too, and the other ended ERROR, "No header has been
//! recorded" x3 (lane flakes2, 2026-11-02: lane fixes1's A/B base side).
//!
//! So each run of a file holds an exclusive lock on the test file itself
//! (`<wpt root>/<path>`, the document the server serves), and a second runner
//! on the host waits until the first is done with it. The lock is flock(2),
//! through std's File.lock, as wpt_server's SpawnLock locks the WPT root: it
//! belongs to its descriptor, so a runner that dies releases it, and it is no
//! file of its own. Runners whose roots are one tree (every mirror on a pool
//! host shares the host's) lock the same inode.
//!
//! The wait is bounded: a run lasts at most its ceiling (config.Timeout) and a
//! margin, so a lock held longer is a runner that hangs, and the waiter gives
//! up with `error.HeldTooLong` - the caller journals the file as an error
//! naming the holder - never waits silently. The holder is named by a note
//! the holder writes into `Options.notes` (the host's temporary directory)
//! while it holds the lock: its pid and when it took the lock. The note is
//! only a name: the lock never depends on it, a note left by a runner that
//! died is overwritten by the next holder, and a stale one reads as a pid
//! that no longer runs.

const std = @import("std");
const clock = @import("clock");

pub const FileLock = struct {
    file: std.Io.File,
    /// How long `acquire` waited for another runner, in milliseconds.
    waited_ms: u64,
    /// The holder's note, in `notes`, when there is one.
    notes: ?std.Io.Dir = null,
    note_name: [note_name_max]u8 = undefined,
    note_len: usize = 0,

    pub const Options = struct {
        /// Give up after waiting this long (`error.HeldTooLong`).
        bound_ms: u64,
        /// Called every `poll_ms` while waiting: the runner's heartbeat and
        /// deadline - a wait is progress, not a stall.
        waiting: ?Waiting = null,
        /// Where holders write who they are; null: no notes.
        notes: ?std.Io.Dir = null,
    };

    pub const Waiting = struct {
        context: ?*anyopaque = null,
        beat: *const fn (context: ?*anyopaque, waited_ms: u64) void,
    };

    pub const Error = error{HeldTooLong} || std.Io.File.OpenError || std.Io.File.LockError || std.Io.File.StatError;

    pub const poll_ms: u64 = 50;

    /// Lock `sub_path` (a test file under `root`) exclusively, waiting while
    /// another runner holds it - at most `options.bound_ms`.
    pub fn acquire(io: std.Io, root: std.Io.Dir, sub_path: []const u8, options: Options) Error!FileLock {
        const file = try root.openFile(io, sub_path, .{});
        errdefer file.close(io);
        const start = clock.monotonicMillis();
        var waited: u64 = 0;
        while (!try file.tryLock(io, .exclusive)) {
            waited = elapsedSince(start);
            if (waited >= options.bound_ms) return error.HeldTooLong;
            if (options.waiting) |w| w.beat(w.context, waited);
            clock.sleep(poll_ms * std.time.ns_per_ms);
        }
        var lock: FileLock = .{ .file = file, .waited_ms = elapsedSince(start) };
        if (options.notes) |notes| lock.writeNote(io, notes) catch {};
        return lock;
    }

    /// The note goes first, while the lock still stands: once the lock is
    /// released the next holder may already have written its own. Closing the
    /// descriptor releases the lock.
    pub fn release(self: FileLock, io: std.Io) void {
        if (self.notes) |notes| notes.deleteFile(io, self.note_name[0..self.note_len]) catch {};
        self.file.close(io);
    }

    fn writeNote(self: *FileLock, io: std.Io, notes: std.Io.Dir) !void {
        const name = try noteName(io, self.file, &self.note_name);
        var buf: [64]u8 = undefined;
        const text = try std.fmt.bufPrint(&buf, "{d} {d}\n", .{ std.c.getpid(), clock.monotonicMillis() });
        try notes.writeFile(io, .{ .sub_path = name, .data = text });
        self.notes = notes;
        self.note_len = name.len;
    }
};

const note_name_max = 32;

/// The note's name: the test file's inode, which every root on the host that
/// is one tree shares.
fn noteName(io: std.Io, file: std.Io.File, buf: *[note_name_max]u8) ![]const u8 {
    const stat = try file.stat(io);
    return std.fmt.bufPrint(buf, "ino-{d}", .{stat.inode});
}

fn elapsedSince(start_ms: i64) u64 {
    return @intCast(@max(0, clock.monotonicMillis() - start_ms));
}

/// Who holds `sub_path`'s lock, by the holder's note: "pid N (running|gone),
/// holding it for S s", or "a runner that left no note".
pub fn describeHolder(io: std.Io, root: std.Io.Dir, sub_path: []const u8, notes: ?std.Io.Dir, out: []u8) []const u8 {
    const unknown = "a runner that left no note";
    const dir = notes orelse return unknown;
    const file = root.openFile(io, sub_path, .{}) catch return unknown;
    defer file.close(io);
    var name_buf: [note_name_max]u8 = undefined;
    const name = noteName(io, file, &name_buf) catch return unknown;
    var text_buf: [64]u8 = undefined;
    const text = dir.readFile(io, name, &text_buf) catch return unknown;
    var fields = std.mem.tokenizeAny(u8, text, " \n");
    const pid = std.fmt.parseInt(std.c.pid_t, fields.next() orelse return unknown, 10) catch return unknown;
    const since = std.fmt.parseInt(i64, fields.next() orelse return unknown, 10) catch return unknown;
    const running = std.c.kill(pid, @fromBackingInt(@intCast(0))) == 0;
    return std.fmt.bufPrint(out, "pid {d} ({s}), holding it for {d} s", .{
        pid, if (running) "running" else "gone", @divTrunc(elapsedSince(since), 1000),
    }) catch unknown;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn makeFile(dir: std.Io.Dir, path: []const u8) !void {
    try dir.writeFile(testing.io, .{ .sub_path = path, .data = "<!doctype html>\n" });
}

const no_bound: u64 = 60_000;

test "a file nobody runs is locked at once" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try makeFile(tmp.dir, "a.html");
    const lock = try FileLock.acquire(testing.io, tmp.dir, "a.html", .{ .bound_ms = no_bound });
    defer lock.release(testing.io);
    try testing.expectEqual(@as(u64, 0), lock.waited_ms);
}

test "while one run holds a file, another descriptor cannot take it; it can once the first releases" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try makeFile(tmp.dir, "report.https.sub.html");
    const first = try FileLock.acquire(testing.io, tmp.dir, "report.https.sub.html", .{ .bound_ms = no_bound });
    const other = try tmp.dir.openFile(testing.io, "report.https.sub.html", .{});
    defer other.close(testing.io);
    try testing.expect(!try other.tryLock(testing.io, .exclusive));
    first.release(testing.io);
    try testing.expect(try other.tryLock(testing.io, .exclusive));
    other.unlock(testing.io);
}

test "two different files never wait for each other" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try makeFile(tmp.dir, "a.html");
    try makeFile(tmp.dir, "b.html");
    const a = try FileLock.acquire(testing.io, tmp.dir, "a.html", .{ .bound_ms = no_bound });
    defer a.release(testing.io);
    const b = try FileLock.acquire(testing.io, tmp.dir, "b.html", .{ .bound_ms = 0 });
    defer b.release(testing.io);
    try testing.expectEqual(@as(u64, 0), b.waited_ms);
}

const Beats = struct {
    count: u32 = 0,
    fn beat(context: ?*anyopaque, waited_ms: u64) void {
        _ = waited_ms;
        const self: *Beats = @ptrCast(@alignCast(context.?));
        self.count += 1;
    }
};

/// A second PROCESS holding `path` (under `dir_path`) until it is killed: it
/// locks the file, then says so on a pipe, then sleeps. Only async-signal-safe
/// calls after the fork.
const Holder = struct {
    pid: std.c.pid_t,

    fn start(path: [*:0]const u8) !Holder {
        var fds: [2]std.c.fd_t = undefined;
        if (std.c.pipe(&fds) != 0) return error.PipeFailed;
        const pid = std.c.fork();
        if (pid < 0) return error.ForkFailed;
        if (pid == 0) {
            const fd = std.c.open(path, .{ .ACCMODE = .RDONLY });
            if (fd < 0 or std.c.flock(fd, std.c.LOCK.EX) != 0) std.c._exit(2);
            _ = std.c.write(fds[1], "L", 1);
            const second: std.c.timespec = .{ .sec = 1, .nsec = 0 };
            while (true) _ = std.c.nanosleep(&second, null);
        }
        _ = std.c.close(fds[1]);
        defer _ = std.c.close(fds[0]);
        var byte: [1]u8 = undefined;
        if (std.c.read(fds[0], &byte, 1) != 1) return error.HolderDidNotLock;
        return .{ .pid = pid };
    }

    /// Dies without releasing anything itself.
    fn kill(self: Holder) void {
        _ = std.c.kill(self.pid, .KILL);
        var status: c_int = 0;
        _ = std.c.waitpid(self.pid, &status, 0);
    }
};

fn absolutePath(dir: std.Io.Dir, name: []const u8, buf: []u8) ![:0]const u8 {
    const root = try dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    return std.mem.printSentinel(buf, "{s}/{s}", .{ root, name }, 0);
}

test "two processes: a second runner waits while another process holds the file, beating, and gives up at its bound" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try makeFile(tmp.dir, "report.https.sub.html");
    var path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const holder = try Holder.start(try absolutePath(tmp.dir, "report.https.sub.html", &path_buf));
    defer holder.kill();
    var beats: Beats = .{};
    const bound_ms: u64 = 300;
    const start = clock.monotonicMillis();
    try testing.expectError(error.HeldTooLong, FileLock.acquire(testing.io, tmp.dir, "report.https.sub.html", .{
        .bound_ms = bound_ms,
        .waiting = .{ .context = &beats, .beat = Beats.beat },
    }));
    // It waited its bound, not less, and said so while it waited.
    try testing.expect(elapsedSince(start) >= bound_ms);
    try testing.expect(beats.count >= 2);
}

test "two processes: the lock is released when its holder dies" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try makeFile(tmp.dir, "report.https.sub.html");
    var path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const holder = try Holder.start(try absolutePath(tmp.dir, "report.https.sub.html", &path_buf));
    // Held: refused at once.
    try testing.expectError(error.HeldTooLong, FileLock.acquire(testing.io, tmp.dir, "report.https.sub.html", .{ .bound_ms = 0 }));
    holder.kill();
    // Its death released the lock: taken at once.
    const lock = try FileLock.acquire(testing.io, tmp.dir, "report.https.sub.html", .{ .bound_ms = 0 });
    defer lock.release(testing.io);
    try testing.expectEqual(@as(u64, 0), lock.waited_ms);
}

fn holdThenRelease(lock: FileLock, hold_ms: u64) void {
    clock.sleep(hold_ms * std.time.ns_per_ms);
    lock.release(testing.io);
}

test "a waiting run takes the file as soon as the holder releases it, within its bound" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try makeFile(tmp.dir, "report.https.sub.html");
    const first = try FileLock.acquire(testing.io, tmp.dir, "report.https.sub.html", .{ .bound_ms = no_bound });
    const hold_ms: u64 = 200;
    const holder = try std.Thread.spawn(.{}, holdThenRelease, .{ first, hold_ms });
    const second = try FileLock.acquire(testing.io, tmp.dir, "report.https.sub.html", .{ .bound_ms = no_bound });
    holder.join();
    defer second.release(testing.io);
    try testing.expect(second.waited_ms >= hold_ms / 2);
    try testing.expect(second.waited_ms < no_bound);
}

test "the holder is named by its note; the note goes with the lock" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try makeFile(tmp.dir, "report.https.sub.html");
    try tmp.dir.createDirPath(testing.io, "notes");
    const notes = try tmp.dir.openDir(testing.io, "notes", .{ .iterate = true });
    defer notes.close(testing.io);
    var out: [128]u8 = undefined;
    try testing.expectEqualStrings("a runner that left no note", describeHolder(testing.io, tmp.dir, "report.https.sub.html", notes, &out));

    const lock = try FileLock.acquire(testing.io, tmp.dir, "report.https.sub.html", .{ .bound_ms = no_bound, .notes = notes });
    var expected: [64]u8 = undefined;
    const pid_text = try std.fmt.bufPrint(&expected, "pid {d} (running), holding it for 0 s", .{std.c.getpid()});
    try testing.expectEqualStrings(pid_text, describeHolder(testing.io, tmp.dir, "report.https.sub.html", notes, &out));

    lock.release(testing.io);
    try testing.expectEqualStrings("a runner that left no note", describeHolder(testing.io, tmp.dir, "report.https.sub.html", notes, &out));
    var it = notes.iterate();
    try testing.expect(try it.next(testing.io) == null);
}

test "a note left by a runner that died names a pid that is gone" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try makeFile(tmp.dir, "a.html");
    try tmp.dir.createDirPath(testing.io, "notes");
    const notes = try tmp.dir.openDir(testing.io, "notes", .{});
    defer notes.close(testing.io);
    // A pid that has exited: a child we reaped.
    var path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const dead = try Holder.start(try absolutePath(tmp.dir, "a.html", &path_buf));
    dead.kill();
    const file = try tmp.dir.openFile(testing.io, "a.html", .{});
    var name_buf: [note_name_max]u8 = undefined;
    const name = try noteName(testing.io, file, &name_buf);
    file.close(testing.io);
    var text: [64]u8 = undefined;
    try notes.writeFile(testing.io, .{ .sub_path = name, .data = try std.fmt.bufPrint(&text, "{d} {d}\n", .{ dead.pid, clock.monotonicMillis() }) });
    var out: [128]u8 = undefined;
    const said = describeHolder(testing.io, tmp.dir, "a.html", notes, &out);
    try testing.expect(std.mem.indexOf(u8, said, "(gone)") != null);
    // The next holder overwrites it, and its release removes it.
    const lock = try FileLock.acquire(testing.io, tmp.dir, "a.html", .{ .bound_ms = 0, .notes = notes });
    try testing.expect(std.mem.indexOf(u8, describeHolder(testing.io, tmp.dir, "a.html", notes, &out), "(running)") != null);
    lock.release(testing.io);
}

test "a file that does not exist is an error, not a wait" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try testing.expectError(error.FileNotFound, FileLock.acquire(testing.io, tmp.dir, "missing.html", .{ .bound_ms = no_bound }));
}
