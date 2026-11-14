//! A project's own test server, run in place of the harness's static
//! server for a suite whose manifest names one (jQuery 4.0.0: its
//! `npm run test:server`, `jtr serve -m test/middleware-mockserver.cjs`, the
//! jquery-test-runner server its own CI's runner serves the pages and the 29
//! mock actions with). The user, 2026-11-11 17:43 ET: "we can run node for the
//! purposes of these tests" - the framework matrix only; Crane is still driven
//! as a user drives it (tools/repl.zig), never from Node.
//!
//! The harness picks a free port and substitutes it for each "{port}" in the
//! command; runs the command in the suite's tree in a process group of its
//! own, its stdout and stderr to a log file and its pid to a pid file (so a
//! person, or a wrapper whose harness died, can stop it by that exact pid);
//! and waits for it to answer an HTTP GET of the ready path (any status) on
//! 127.0.0.1. The command exiting first, or the deadline passing, fails the
//! start, with the process group ended and the log kept. `stop` sends SIGTERM
//! to the group, then SIGKILL after five seconds, reaps the process and
//! removes the pid file: no process of it outlives the run.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const manifest = @import("manifest.zig");

pub const Options = struct {
    /// The command as the manifest gives it ("{port}" not yet substituted).
    /// A first argument that is a relative path is below `cwd`.
    argv: []const []const u8,
    /// The suite's tree, absolute.
    cwd: []const u8,
    environ: ?*const std.process.Environ.Map = null,
    ready_path: []const u8 = "/",
    ready_ms: u64,
    /// 0: a free one is picked.
    port: u16 = 0,
    log_path: []const u8,
    pid_path: ?[]const u8 = null,
};

/// A child process's end, watched by a thread of its own (the harness
/// polls `done`; std's Child has no wait with a timeout).
pub const Waiter = struct {
    child: std.process.Child,
    io: Io,
    term: ?std.process.Child.Term = null,
    done: std.atomic.Value(bool) = .init(false),

    pub fn wait(self: *Waiter) void {
        self.term = self.child.wait(self.io) catch null;
        self.done.store(true, .release);
    }

    /// Returns at the child's end or after `ms`, whichever comes first.
    pub fn waitFor(self: *Waiter, ms: u64) void {
        var waited: u64 = 0;
        while (!self.done.load(.acquire) and waited < ms) : (waited += 50) Io.sleep(self.io, .fromMilliseconds(50), .awake) catch {};
    }
};

/// `sig` to the process group led by `pid` (a child spawned with pgid 0)
/// and to `pid` itself; for a process not yet reaped.
pub fn signalGroup(pid: i32, sig: std.posix.SIG) void {
    std.posix.kill(-pid, sig) catch {};
    std.posix.kill(pid, sig) catch {};
}

/// No process is left in the group `pid` led.
fn groupGone(pid: i32) bool {
    std.posix.kill(-pid, @fromBackingInt(@intCast(0))) catch |err| return err == error.ProcessNotFound;
    return false;
}

pub const External = struct {
    gpa: Allocator,
    io: Io,
    waiter: Waiter,
    thread: std.Thread,
    pid: i32,
    port_number: u16,
    pid_path: ?[]const u8,

    pub fn port(self: *const External) u16 {
        return self.port_number;
    }

    /// Spawn the command and wait until it answers.
    pub fn start(gpa: Allocator, io: Io, options: Options) !*External {
        var arena_state: std.heap.ArenaAllocator = .init(gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();

        const port_number = if (options.port != 0) options.port else try freePort(io);
        var argv = try substitute(arena, options.argv, port_number);
        if (argv.len == 0) return error.BadServer;
        if (argv[0].len > 0 and argv[0][0] != '/' and std.mem.indexOfScalar(u8, argv[0], '/') != null) {
            argv[0] = try std.fmt.allocPrint(arena, "{s}/{s}", .{ options.cwd, argv[0] });
        }

        const log = try Io.Dir.cwd().createFile(io, options.log_path, .{});
        defer log.close(io);
        // Owned here until `self` takes it (then `end` frees it).
        var pid_path: ?[]const u8 = if (options.pid_path) |p| try gpa.dupe(u8, p) else null;
        errdefer if (pid_path) |p| gpa.free(p);
        const self = try gpa.create(External);
        errdefer gpa.destroy(self);
        self.* = .{
            .gpa = gpa,
            .io = io,
            .waiter = .{ .io = io, .child = try std.process.spawn(io, .{
                .argv = argv,
                .cwd = .{ .path = options.cwd },
                .environ_map = options.environ,
                .stdin = .ignore,
                .stdout = .{ .file = log },
                .stderr = .{ .file = log },
                .pgid = 0,
            }) },
            .thread = undefined,
            .pid = undefined,
            .port_number = port_number,
            .pid_path = null,
        };
        // The pid before the waiter owns the Child (run.zig's runConsole).
        self.pid = self.waiter.child.id.?;
        self.thread = std.Thread.spawn(.{}, Waiter.wait, .{&self.waiter}) catch |err| {
            signalGroup(self.pid, .KILL);
            _ = self.waiter.child.wait(io) catch {};
            return err;
        };
        errdefer self.end();
        if (pid_path) |p| {
            var buf: [16]u8 = undefined;
            try Io.Dir.cwd().writeFile(io, .{ .sub_path = p, .data = try std.fmt.bufPrint(&buf, "{d}\n", .{self.pid}) });
            // From here `end` removes the file and frees the path.
            self.pid_path = p;
            pid_path = null;
        }

        var waited: u64 = 0;
        while (true) : (waited += 100) {
            if (self.waiter.done.load(.acquire)) {
                std.debug.print("fw_matrix: the server `{s}` ended before it answered ({s}); its output: {s}\n", .{ argv[0], if (self.waiter.term) |t| try std.fmt.allocPrint(arena, "{f}", .{t}) else "unknown", options.log_path });
                return error.ServerExited;
            }
            if (answers(io, port_number, options.ready_path)) break;
            if (waited >= options.ready_ms) {
                std.debug.print("fw_matrix: the server `{s}` did not answer GET {s} on port {d} within {d} ms; its output: {s}\n", .{ argv[0], options.ready_path, port_number, options.ready_ms, options.log_path });
                return error.ServerNotReady;
            }
            Io.sleep(io, .fromMilliseconds(100), .awake) catch {};
        }
        return self;
    }

    /// End the process group - SIGTERM, up to five seconds for the process
    /// to end and its group to empty, then SIGKILL - and reap the process;
    /// the pid file goes. A group member it started is ended with it.
    fn end(self: *External) void {
        // The pid itself only while it is unreaped (never a reused pid); the
        // group id cannot be reused while a member of the group lives.
        if (!self.waiter.done.load(.acquire)) std.posix.kill(self.pid, .TERM) catch {};
        std.posix.kill(-self.pid, .TERM) catch {};
        var waited: u64 = 0;
        while (waited < 5000 and !(self.waiter.done.load(.acquire) and groupGone(self.pid))) : (waited += 50) {
            Io.sleep(self.io, .fromMilliseconds(50), .awake) catch {};
        }
        if (!self.waiter.done.load(.acquire) or !groupGone(self.pid)) {
            if (!self.waiter.done.load(.acquire)) std.posix.kill(self.pid, .KILL) catch {};
            std.posix.kill(-self.pid, .KILL) catch {};
            self.waiter.waitFor(10_000);
        }
        self.thread.join();
        if (self.pid_path) |p| {
            Io.Dir.cwd().deleteFile(self.io, p) catch {};
            self.gpa.free(p);
            self.pid_path = null;
        }
    }

    pub fn stop(self: *External) void {
        self.end();
        self.gpa.destroy(self);
    }
};

/// The command with each "{port}" replaced by `port` (inside an argument
/// too: "http://localhost:{port}/").
pub fn substitute(arena: Allocator, argv: []const []const u8, port: u16) ![][]const u8 {
    var buf: [5]u8 = undefined;
    const text = try std.fmt.bufPrint(&buf, "{d}", .{port});
    const out = try arena.alloc([]const u8, argv.len);
    for (argv, out) |a, *o| o.* = try std.mem.replaceOwned(u8, arena, a, manifest.port_placeholder, text);
    return out;
}

/// A port nobody on this host listens on now: the kernel's pick for a
/// socket bound to every interface (the project's server may listen on all
/// of them: jtr serve binds 0.0.0.0), released at once.
pub fn freePort(io: Io) !u16 {
    const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.unspecified(0) };
    var l = try address.listen(io, .{});
    defer l.deinit(io);
    return l.socket.address.getPort();
}

/// Whether something on 127.0.0.1:`port` answers an HTTP GET of `path`
/// with a status line (any status).
pub fn answers(io: Io, port: u16, path: []const u8) bool {
    const address: Io.net.IpAddress = .{ .ip4 = Io.net.Ip4Address.loopback(port) };
    const stream = address.connect(io, .{ .mode = .stream }) catch return false;
    defer stream.close(io);
    var wbuf: [512]u8 = undefined;
    var writer = stream.writer(io, &wbuf);
    writer.interface.print("GET {s} HTTP/1.1\r\nHost: 127.0.0.1:{d}\r\nConnection: close\r\n\r\n", .{ path, port }) catch return false;
    writer.interface.flush() catch return false;
    var rbuf: [64]u8 = undefined;
    var reader = stream.reader(io, &rbuf);
    reader.interface.fill(8) catch return false;
    return std.mem.startsWith(u8, reader.interface.buffered(), "HTTP/1.");
}

const testing = std.testing;
const server_mod = @import("server.zig");

fn gone(pid: i32) bool {
    std.posix.kill(pid, @fromBackingInt(@intCast(0))) catch |err| return err == error.ProcessNotFound;
    return false;
}

test "substitute: every {port}, inside an argument too" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const out = try substitute(arena_state.allocator(), &.{ "node_modules/.bin/jtr", "serve", "--port", "{port}", "http://localhost:{port}/test/" }, 4100);
    try testing.expectEqualStrings("node_modules/.bin/jtr", out[0]);
    try testing.expectEqualStrings("4100", out[3]);
    try testing.expectEqualStrings("http://localhost:4100/test/", out[4]);
}

test "answers: a status line of any kind is an answer; nobody listening is none" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(root);
    const s = try server_mod.Server.start(testing.allocator, testing.io, .{ .root = root });
    defer s.stop();
    try testing.expect(answers(testing.io, s.port(), "/missing/")); // 404
    try testing.expect(!answers(testing.io, try freePort(testing.io), "/"));
}

test "start: the tree's own command with the harness's port and environment, its output logged; ready when the port answers; stop ends its whole group" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tree = try tmp.dir.realPathFileAlloc(testing.io, ".", a);
    // The command stands in for the project's server: it reports what it was
    // given, starts a child of its own (which says when SIGTERM reaches it)
    // and waits; the readiness GET is answered by the harness's own static
    // server on the port the test hands it.
    try tmp.dir.createDirPath(testing.io, "bin");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "bin/serve", .flags = .{ .permissions = .executable_file }, .data =
        \\#!/bin/sh
        \\( trap 'echo gone > term.txt; exit 0' TERM; while :; do sleep 0.1; done ) &
        \\echo "port=$1 dir=$PWD x=$X path=$PATH"
        \\exec sleep 30
        \\
    });
    const static = try server_mod.Server.start(testing.allocator, testing.io, .{ .root = tree });
    defer static.stop();
    var env: std.process.Environ.Map = .init(a);
    try env.put("PATH", "/node/bin:/usr/bin:/bin");
    try env.put("X", "1");
    const log = try std.fmt.allocPrint(a, "{s}/server.log", .{tree});
    const pid_file = try std.fmt.allocPrint(a, "{s}/server.pid", .{tree});
    const ext = try External.start(testing.allocator, testing.io, .{
        .argv = &.{ "bin/serve", "{port}" },
        .cwd = tree,
        .environ = &env,
        .ready_path = "/test/",
        .ready_ms = 10_000,
        .port = static.port(),
        .log_path = log,
        .pid_path = pid_file,
    });
    try testing.expectEqual(static.port(), ext.port());
    var pid_buf: [16]u8 = undefined;
    const pid = try std.fmt.parseInt(i32, std.mem.trim(u8, try tmp.dir.readFile(testing.io, "server.pid", &pid_buf), "\n"), 10);
    try testing.expectEqual(ext.pid, pid);
    // Its report, once it has written it (bounded).
    const want = try std.fmt.allocPrint(a, "port={d} dir={s} x=1 path=/node/bin:/usr/bin:/bin\n", .{ static.port(), tree });
    var text: []const u8 = "";
    var tries: u32 = 0;
    while (tries < 100) : (tries += 1) {
        text = try tmp.dir.readFileAlloc(testing.io, "server.log", a, .limited(4096));
        if (text.len >= want.len) break;
        try Io.sleep(testing.io, .fromMilliseconds(50), .awake);
    }
    try testing.expectEqualStrings(want, text);
    // Its own child must be running before the stop, to see SIGTERM reach it.
    try Io.sleep(testing.io, .fromMilliseconds(200), .awake);

    ext.stop();
    try testing.expect(gone(pid));
    try testing.expectError(error.FileNotFound, tmp.dir.access(testing.io, "server.pid", .{}));
    tries = 0;
    while (tries < 100) : (tries += 1) {
        if (tmp.dir.access(testing.io, "term.txt", .{})) break else |_| {}
        try Io.sleep(testing.io, .fromMilliseconds(50), .awake);
    }
    const term = try tmp.dir.readFileAlloc(testing.io, "term.txt", a, .limited(100));
    try testing.expectEqualStrings("gone\n", term);
}

test "start: a command that ends before it answers fails at once, its output kept" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tree = try tmp.dir.realPathFileAlloc(testing.io, ".", a);
    const log = try std.fmt.allocPrint(a, "{s}/server.log", .{tree});
    const t0 = Io.Timestamp.now(testing.io, .awake);
    try testing.expectError(error.ServerExited, External.start(testing.allocator, testing.io, .{
        .argv = &.{ "/bin/sh", "-c", "echo boom >&2; exit 3" },
        .cwd = tree,
        .ready_ms = 20_000,
        .log_path = log,
        .pid_path = try std.fmt.allocPrint(a, "{s}/server.pid", .{tree}),
    }));
    try testing.expect(t0.durationTo(Io.Timestamp.now(testing.io, .awake)).toMilliseconds() < 10_000);
    try testing.expectEqualStrings("boom\n", try tmp.dir.readFileAlloc(testing.io, "server.log", a, .limited(100)));
    try testing.expectError(error.FileNotFound, tmp.dir.access(testing.io, "server.pid", .{}));
}

test "start: a command that never answers is ended at the deadline" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const tree = try tmp.dir.realPathFileAlloc(testing.io, ".", a);
    const log = try std.fmt.allocPrint(a, "{s}/server.log", .{tree});
    // It prints its pid, then becomes `sleep` (exec keeps the pid).
    try testing.expectError(error.ServerNotReady, External.start(testing.allocator, testing.io, .{
        .argv = &.{ "/bin/sh", "-c", "echo $$; exec sleep 30" },
        .cwd = tree,
        .ready_ms = 1000,
        .log_path = log,
    }));
    const text = try tmp.dir.readFileAlloc(testing.io, "server.log", a, .limited(100));
    const pid = try std.fmt.parseInt(i32, std.mem.trim(u8, text, "\n"), 10);
    try testing.expect(gone(pid));
}
