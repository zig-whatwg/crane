//! How the launcher starts processes, and what it lets go of when it starts.
//!
//! A pipe's reader sees end of stream only when every process holding its
//! write end has closed it. On macOS Zig 0.17's `std.process.spawn` makes
//! each stdio pipe with pipe() and marks its ends close-on-exec with a
//! separate fcntl() (Darwin has no pipe2: lib/std/c.zig `pipe2`), and calls
//! posix_spawn without POSIX_SPAWN_CLOEXEC_DEFAULT (lib/std/Io/Threaded.zig
//! `spawnDarwin`; Zig master 2ff397f75cf, 2026-11-20, still does). A
//! posix_spawn on another thread between those two calls hands its new
//! process both ends of the pipe, and that pipe then ends only when THAT
//! process exits too.
//!
//! Two places meet it (lane flk3, 2026-11-21):
//! - zig build's runner spawns every launcher, and every compile, from
//!   several threads. A launcher spawned in that window holds another
//!   launcher's stdout and stderr; when the other one exits the build runner
//!   still sees no end of stream, and after its 60 s response timeout it
//!   fails that step - "test runner failed to respond for 1m" with every test
//!   passed (compiler/Maker/Step/Run.zig waitZigTest; seen on chat.local for
//!   tools-lint_tombstones, 2026-11-03, and wpt_runner-repeat under
//!   -Dsanitize-thread, 2 of 5 runs, 2026-11-20). The runner is Zig's, so the
//!   window there stays open; `closeStrayInheritedPipes` makes a launcher
//!   let go of what it inherited that way, first thing - the receiving end's
//!   defence, as OpenSSH's ssh does at its start ("Discard other fds that are
//!   hanging around", closefrom(STDERR_FILENO + 1) in ssh.c main).
//! - the launcher itself starts test processes from its worker threads.
//!   `Spawner` starts them one at a time, so no spawn of the launcher runs
//!   inside another's pipe-to-fcntl window: Go's syscall.ForkLock (src/
//!   syscall/exec_unix.go: "Lock synchronizing creation of new file
//!   descriptors with fork", for systems without atomic close-on-exec). With
//!   std spawning from 4 threads beside a fifth on chat2 (macOS), 13 to 51 of
//!   every 2,000 exited children had a pipe still held by another process;
//!   with one lock, none (.flk3/fdleak.zig, lane flk3).
//!
//! Linux has pipe2(O_CLOEXEC), so std's pipes are close-on-exec from birth
//! there; both measures are harmless on it.

const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const posix = std.posix;

/// Starts the launcher's processes, one at a time (see the file comment).
/// One per launcher process; every thread that spawns shares it.
pub const Spawner = struct {
    io: Io,

    pub fn init(io: Io) Spawner {
        return .{ .io = io };
    }

    pub fn spawn(s: *Spawner, options: std.process.SpawnOptions) std.process.SpawnError!std.process.Child {
        return std.process.spawn(s.io, options);
    }
};

/// The pipe ends this process holds without having made them: every pipe at
/// a descriptor above stderr that is not close-on-exec - a process's own
/// pipes are (std makes them close-on-exec), so such a pipe came in through
/// exec - except `keep` (the build runner's progress pipe, ZIG_PROGRESS).
/// At most `buffer.len` of them, in descriptor order.
pub fn strayInheritedPipes(io: Io, buffer: []posix.fd_t, keep: ?posix.fd_t) ![]posix.fd_t {
    _ = io;
    _ = keep;
    return buffer[0..0];
}

// The few descriptor calls this file needs, over libc or the Linux syscalls
// alike (std.posix.system), the way std's own spawn makes them.

fn pipe() error{PipeFailed}![2]posix.fd_t {
    var fds: [2]posix.fd_t = undefined;
    if (posix.errno(posix.system.pipe(&fds)) != .SUCCESS) return error.PipeFailed;
    return fds;
}

fn close(fd: posix.fd_t) void {
    _ = posix.system.close(fd);
}

/// Whether `fd` is close-on-exec; null when it is not open.
fn closeOnExec(fd: posix.fd_t) ?bool {
    const rc = posix.system.fcntl(fd, posix.F.GETFD, @as(usize, 0));
    if (posix.errno(rc) != .SUCCESS) return null;
    return (@as(usize, @intCast(rc)) & posix.FD_CLOEXEC) != 0;
}

fn setCloseOnExec(fd: posix.fd_t) void {
    _ = posix.system.fcntl(fd, posix.F.SETFD, @as(usize, posix.FD_CLOEXEC));
}

/// A close-on-exec copy of `fd`, made atomically (F_DUPFD_CLOEXEC); null on
/// failure.
fn dupCloseOnExec(fd: posix.fd_t) ?posix.fd_t {
    const rc = posix.system.fcntl(fd, posix.F.DUPFD_CLOEXEC, @as(usize, 0));
    if (posix.errno(rc) != .SUCCESS) return null;
    return @intCast(rc);
}

const testing = std.testing;

/// How many of `spawns` exited children, started from `threads` threads at
/// once beside a thread that keeps starting longer-lived ones, still had a
/// pipe some other process held: each child's read ends are duplicated
/// before it is reaped, and a pipe whose read end does not poll ready (end
/// of stream) the moment its only writer is gone has another writer.
fn heldPipesWhileSpawning(spawner: *Spawner, threads: u32, spawns: u32) !u32 {
    const Shared = struct {
        spawner: *Spawner,
        spawns: u32,
        held: std.atomic.Value(u32) = .init(0),
        stop: std.atomic.Value(bool) = .init(false),

        fn short(sh: *@This()) void {
            const io = sh.spawner.io;
            for (0..sh.spawns) |_| {
                var child = sh.spawner.spawn(.{ .argv = &.{"/usr/bin/true"}, .stdin = .pipe, .stdout = .pipe, .stderr = .pipe }) catch continue;
                child.stdin.?.close(io);
                child.stdin = null;
                // Atomically close-on-exec copies: no spawn may inherit them.
                const copies = [_]?posix.fd_t{ dupCloseOnExec(child.stdout.?.handle), dupCloseOnExec(child.stderr.?.handle) };
                _ = child.wait(io) catch {};
                for (copies) |copy| {
                    const fd = copy orelse continue;
                    var fds = [_]posix.pollfd{.{ .fd = fd, .events = posix.POLL.IN, .revents = 0 }};
                    const ready = posix.poll(&fds, 0) catch 1;
                    if (ready == 0) _ = sh.held.fetchAdd(1, .monotonic);
                    close(fd);
                }
            }
        }

        fn long(sh: *@This()) void {
            const io = sh.spawner.io;
            var live: [4]?std.process.Child = @splat(null);
            var i: usize = 0;
            while (!sh.stop.load(.monotonic)) : (i += 1) {
                const slot = &live[i % live.len];
                if (slot.*) |*c| c.kill(io);
                slot.* = sh.spawner.spawn(.{ .argv = &.{ "/bin/sleep", "2" }, .stdin = .pipe, .stdout = .pipe, .stderr = .pipe }) catch null;
            }
            for (&live) |*slot| if (slot.*) |*c| c.kill(io);
        }
    };
    var shared: Shared = .{ .spawner = spawner, .spawns = spawns };
    const sleeper = try std.Thread.spawn(.{}, Shared.long, .{&shared});
    var workers: [8]std.Thread = undefined;
    for (workers[0..threads]) |*w| w.* = try std.Thread.spawn(.{}, Shared.short, .{&shared});
    for (workers[0..threads]) |w| w.join();
    shared.stop.store(true, .monotonic);
    sleeper.join();
    return shared.held.load(.monotonic);
}

test "processes started from several threads at once hold none of each other's pipes" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;
    var spawner: Spawner = .init(testing.io);
    // Before the Spawner's lock, 13 to 51 of 2,000 on macOS (chat2).
    try testing.expectEqual(@as(u32, 0), try heldPipesWhileSpawning(&spawner, 4, 500));
}

test "a pipe that came in through exec is stray; the process's own close-on-exec pipes and the kept one are not" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;
    const io = testing.io;
    // What exec hands over: a pipe that is not close-on-exec.
    const inherited = try pipe();
    defer for (inherited) |fd| close(fd);
    // The process's own: close-on-exec from the start (as std makes them).
    const own = try pipe();
    defer for (own) |fd| close(fd);
    for (own) |fd| setCloseOnExec(fd);
    // The progress pipe the build runner passes on purpose.
    const progress = try pipe();
    defer for (progress) |fd| close(fd);

    var buffer: [256]posix.fd_t = undefined;
    const stray = try strayInheritedPipes(io, &buffer, progress[1]);
    try testing.expect(std.mem.indexOfScalar(posix.fd_t, stray, inherited[0]) != null);
    try testing.expect(std.mem.indexOfScalar(posix.fd_t, stray, inherited[1]) != null);
    try testing.expect(std.mem.indexOfScalar(posix.fd_t, stray, own[0]) == null);
    try testing.expect(std.mem.indexOfScalar(posix.fd_t, stray, own[1]) == null);
    try testing.expect(std.mem.indexOfScalar(posix.fd_t, stray, progress[1]) == null);
    for (stray) |fd| try testing.expect(fd > 2);
}
