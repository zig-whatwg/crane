//! WPT Server Manager
//!
//! This module manages the lifecycle of the `wpt serve` Python server.
//! Uses a lockfile to track the server PID and port.
//!
//! ## Usage
//!
//! ```zig
//! var server = try WptServer.init(allocator, "tests/wpt");
//! defer server.deinit();
//!
//! try server.start();
//! // Server is now running at http://localhost:8000
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const posix = std.posix;
const test_parser = @import("test_parser.zig");
const host = @import("host");
const clock = @import("clock");

/// Lockfile name stored in WPT root
const LOCKFILE_NAME = ".wpt_serve.lock";

/// The host every test URL is built from.
///
/// Not `localhost`. WPT generates its own certificate authority under
/// `tools/certs/`, and the leaf certificate's subject alternative names cover
/// `web-platform.test` and its subdomains only — a TLS connection to
/// `localhost:8443` cannot verify against it at any price short of disabling
/// verification. Using the same host for plain HTTP keeps the document origin
/// equal to the origin the script loader already builds subresource URLs from.
///
/// WPT's own setup instructions have this in `/etc/hosts` pointing at 127.0.0.1.
pub const WPT_HOST = "web-platform.test";

/// Does this test have to be served over TLS?
///
/// The marker is a component of the *filename*, per WPT's naming convention:
/// `foo.https.html`, `foo.https.any.js`, `foo.https.window.js`. Matching against
/// the whole path would sweep in every test under a directory that happened to
/// contain the string.
pub fn isHttpsTest(test_path: []const u8) bool {
    return std.mem.indexOf(u8, std.fs.path.basename(test_path), ".https.") != null;
}

/// Does this test have to be served over HTTP/2?
///
/// `.h2.` in the filename, as `.https.` is for TLS: `foo.h2.any.js` and the
/// wrappers generated from it (`foo.h2.any.html`, `foo.h2.any.worker.html`).
/// wptrunner serves these from `wpt serve`'s HTTP/2 listener (its
/// `ports["h2"]`), and their resources are relative URLs whose handlers
/// (`*.h2.py`) answer only HTTP/2 - fetched from the plain listener, the test
/// cannot run at all.
pub fn isH2Test(test_path: []const u8) bool {
    return std.mem.indexOf(u8, std.fs.path.basename(test_path), ".h2.") != null;
}

/// Which of `wpt serve`'s listeners serves a test. `.h2.` is checked first:
/// the HTTP/2 listener is TLS too.
pub const Listener = enum {
    http,
    https,
    h2,

    pub fn of(test_path: []const u8) Listener {
        if (isH2Test(test_path)) return .h2;
        if (isHttpsTest(test_path)) return .https;
        return .http;
    }

    pub fn scheme(self: Listener) []const u8 {
        return if (self == .http) "http" else "https";
    }
};

/// WPT's manifest joins filename flags with the decoded `wpt_flags` query
/// values (tools/manifest/item.py, URLManifestItem._flags and .https).
fn hasHttpsQueryFlag(variant: []const u8) bool {
    const before_fragment = variant[0 .. std.mem.indexOfScalar(u8, variant, '#') orelse variant.len];
    const query_start = std.mem.indexOfScalar(u8, before_fragment, '?') orelse return false;
    var fields = std.mem.splitScalar(u8, before_fragment[query_start + 1 ..], '&');
    while (fields.next()) |field| {
        const equals = std.mem.indexOfScalar(u8, field, '=') orelse continue;
        var key_buffer: ["wpt_flags".len]u8 = undefined;
        const key = (std.Uri.Component{ .percent_encoded = field[0..equals] }).toRaw(&key_buffer) catch continue;
        if (!std.mem.eql(u8, key, "wpt_flags")) continue;
        var value_buffer: ["https".len]u8 = undefined;
        const value = (std.Uri.Component{ .percent_encoded = field[equals + 1 ..] }).toRaw(&value_buffer) catch continue;
        // Form decoding also maps '+' to space; neither target contains a
        // space, so a '+' cannot match either target even without that step.
        if (std.mem.eql(u8, value, "https")) return true;
    }
    return false;
}

/// The origin a test's document has, on `wpt serve`'s default ports: the
/// HTTP/2 listener's (9000), the TLS one's (8443) or the plain one's (8000).
/// Every place that builds a test's URL starts from this, so the three
/// cannot drift apart.
pub fn testOriginFor(test_path: []const u8) []const u8 {
    return switch (Listener.of(test_path)) {
        .h2 => "https://" ++ WPT_HOST ++ ":9000",
        .https => "https://" ++ WPT_HOST ++ ":8443",
        .http => "http://" ++ WPT_HOST ++ ":8000",
    };
}

/// The origin of an absolute URL: scheme, host and port, no trailing slash.
///
/// Same-origin checks for blob URLs and worker scripts compare against this
/// string, so a TLS test handed the plain-HTTP origin fails them for a reason
/// that has nothing to do with the code under test. A slice of the input, not a
/// copy; null for anything that is not an absolute URL.
pub fn originOfUrl(url: []const u8) ?[]const u8 {
    const sep = std.mem.indexOf(u8, url, "://") orelse return null;
    const after_scheme = sep + 3;
    // The authority ends at the first delimiter that can follow it.
    const rest = url[after_scheme..];
    const end = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
    return url[0 .. after_scheme + end];
}

/// WPT Server manager
pub const WptServer = struct {
    allocator: Allocator,
    /// WPT root directory
    wpt_root: []const u8,
    /// Server port (HTTP)
    port: u16 = 8000,
    /// Server port (TLS). `wpt serve` binds this alongside the HTTP one; it is
    /// not optional and not separately startable.
    https_port: u16 = 8443,
    /// Server port (HTTP/2, over TLS) - `ports["h2"]`, bound with the others.
    h2_port: u16 = 9000,
    /// PID of the server process (from lockfile or spawned)
    pid: ?posix.pid_t = null,
    /// Whether we spawned the server (vs found existing)
    we_spawned: bool = false,
    /// How long a port that does not answer is retried before nothing is
    /// said to serve it.
    probe_window_ms: u32 = 5000,
    /// How a server is started and watched (tests substitute one).
    launcher: Launcher = Launcher.wpt_serve,

    /// How `start` launches a server and learns that it died. The real one
    /// runs `python3 wpt.py serve`; the tests substitute launchers they
    /// control, so that no test starts a real `wpt serve` or depends on one.
    pub const Launcher = struct {
        context: ?*anyopaque = null,
        /// Start a server for `server.port` in `server.wpt_root`: its pid.
        spawn: *const fn (context: ?*anyopaque, server: *WptServer) anyerror!posix.pid_t,
        /// Whether the process `spawn` returned has exited; it is reaped if so.
        exited: *const fn (context: ?*anyopaque, pid: posix.pid_t) bool,

        pub const wpt_serve: Launcher = .{ .spawn = spawnWptServe, .exited = reapIfExited };
    };

    /// Initialize the WPT server manager
    pub fn init(allocator: Allocator, wpt_root: []const u8) !*WptServer {
        const server = try allocator.create(WptServer);
        server.* = WptServer{
            .allocator = allocator,
            .wpt_root = try allocator.dupe(u8, wpt_root),
        };
        return server;
    }

    /// Cleanup - kills server if we spawned it
    pub fn deinit(self: *WptServer) void {
        if (self.we_spawned and self.pid != null) {
            self.stop();
        }
        self.allocator.free(self.wpt_root);
        self.allocator.destroy(self);
    }

    /// Get lockfile path
    fn getLockfilePath(self: *WptServer) ![]u8 {
        return std.fs.path.join(self.allocator, &.{ self.wpt_root, LOCKFILE_NAME });
    }

    /// Start the WPT server, or adopt the one that is running.
    ///
    /// A runner shares one `wpt serve` per WPT root with every other runner on
    /// the machine (a sweep starts 8 at once; several lanes share a host), so
    /// the rules below decide who owns it. On 2026-10-28 one failed connect
    /// under load made a runner delete the shared server's lockfile and spawn
    /// a second server, whose child died at bind having already written its
    /// pid; at exit the runner removed the lockfile as its own, and from then
    /// on every runner that started found no lockfile, spawned, and removed it
    /// again - one rewrite per chunk start, even at low load.
    ///
    /// 1. A port that does not answer is retried for `probe_window_ms` before
    ///    nothing is said to serve it.
    /// 2. A spawned child that exits before the port answers started no
    ///    server: if the port answers, the server is someone else's, and it
    ///    is adopted (`we_spawned` stays false, the lockfile is not written).
    /// 3. The lockfile is removed only while it names our own server's pid.
    /// 4. A server is never spawned while a listener answers the port,
    ///    whether or not a lockfile names it - and only one runner per WPT
    ///    root decides to spawn at a time (`SpawnLock`).
    pub fn start(self: *WptServer) !void {
        // Rules 1 and 4: whatever answers the port is adopted, lockfile or not.
        if (try self.checkExistingServer()) return;

        // Nothing answered for the whole window. Two runners that both got
        // here would both spawn: one at a time decides.
        const spawn_lock = try SpawnLock.acquire(self.wpt_root);
        defer spawn_lock.release();
        // A runner that held the lock while we waited for it has started a
        // server, so look again for as long as for any other; with no one
        // ahead of us, one look covers the moment since our own window ended.
        if (try self.adoptExisting(if (spawn_lock.waited) self.probe_window_ms else 0)) return;

        try self.spawnServer();
    }

    /// Adopt the server that answers the port, if one does (rules 1 and 4).
    fn checkExistingServer(self: *WptServer) !bool {
        return self.adoptExisting(self.probe_window_ms);
    }

    /// Adopt whatever answers the port within `window_ms`: the lockfile's
    /// port when there is a readable lockfile, `self.port` otherwise. A
    /// lockfile whose port does not answer is stale and is deleted, unless
    /// another runner has rewritten it meanwhile.
    fn adoptExisting(self: *WptServer, window_ms: u32) !bool {
        const lock = self.readLockfile();
        if (lock) |l| self.port = l.port;

        // Adopt by probing the PORT, not the pid.
        //
        // The old probe was `kill(pid, 0)`, and a ZOMBIE answers that. On
        // 2026-09-22 a runner spawned `wpt serve` while another server already
        // held :8000; the child died at bind, its parent never reaped it, and it
        // had already written this lockfile. Every runner since then "adopted"
        // a defunct pid. That is harmless only while some OTHER process happens
        // to be serving the port; the moment it is not, every run reports
        // "Page load error: error.NetworkError" at 0ms, with no curl diagnostic,
        // because there was never anything to connect to. A TCP connect answers
        // the question this code actually asks.
        if (self.portAnswers(window_ms)) {
            // Something serves the port. Remember the lockfile's pid only if it
            // is a live process; otherwise adopt with no pid, which `stop()`
            // already treats as "not ours to signal".
            self.pid = if (lock) |l| (if (std.c.kill(l.pid, @enumFromInt(0)) == 0) l.pid else null) else null;
            self.we_spawned = false;
            return true;
        }
        // Nothing serves the port: the lockfile is stale whatever its pid says.
        if (lock) |l| self.deleteLockfileNaming(l);
        return false;
    }

    /// Whether the port answers a connect within `window_ms` - at least one
    /// attempt, then one every `probe_interval_ms`. A single failed connect is
    /// not an answer: a busy server's full accept queue fails one too.
    fn portAnswers(self: *WptServer, window_ms: u32) bool {
        const timer = clock.Timer.start();
        while (true) {
            if (self.isServerReady()) return true;
            if (timer.read() >= @as(u64, window_ms) * std.time.ns_per_ms) return false;
            clock.sleep(probe_interval_ms * std.time.ns_per_ms);
        }
    }

    const probe_interval_ms = 100;
    /// How long a spawned server has to answer its port.
    const ready_timeout_ms = 10_000;

    /// Spawn a server and wait until it answers the port. The lockfile is
    /// written only then, and only while our own child is alive: a child
    /// that has exited started no server, and a port that answers anyway is
    /// someone else's (rule 2). A child still starting when another server
    /// begins to answer would be taken for ours; rule 4 and `SpawnLock` leave
    /// that only to a server started outside the runners, and rule 3 keeps a
    /// lockfile written that way from outliving us.
    fn spawnServer(self: *WptServer) !void {
        const pid = try self.launcher.spawn(self.launcher.context, self);
        const timer = clock.Timer.start();
        while (timer.read() < ready_timeout_ms * std.time.ns_per_ms) {
            if (self.launcher.exited(self.launcher.context, pid)) {
                if (try self.adoptExisting(self.probe_window_ms)) return;
                return error.ServerExited;
            }
            if (self.isServerReady()) {
                self.pid = pid;
                self.we_spawned = true;
                try self.writeLockfile();
                return;
            }
            clock.sleep(probe_interval_ms * std.time.ns_per_ms);
        }
        // It never answered: it is not a server, and it is not left running.
        signalAndWait(pid);
        return error.ServerStartTimeout;
    }

    /// `Launcher.wpt_serve`'s spawn: `python3 wpt.py serve` in the WPT root.
    fn spawnWptServe(context: ?*anyopaque, self: *WptServer) anyerror!posix.pid_t {
        _ = context;
        const argv = [_][]const u8{
            "python3",
            "wpt.py",
            "serve",
            "--config",
            "config.json",
        };

        // 0.16 replaced Child.init + child.spawn() with std.process.spawn(io, options):
        // the stdio behaviours and cwd moved into the options struct, cwd became a
        // tagged union, and the child no longer owns an allocator.
        const child = try std.process.spawn(host.io(), .{
            .argv = &argv,
            .cwd = .{ .path = self.wpt_root },
            // Ignore output to avoid noise
            .stdout = .ignore,
            .stderr = .ignore,
        });
        return child.id orelse error.ServerSpawnFailed;
    }

    /// `Launcher.wpt_serve`'s exited: a non-blocking `waitpid`, which also
    /// reaps the child, so a server that died at bind is not left <defunct>.
    /// A pid that is not (or no longer) our child has exited as far as we
    /// can tell.
    fn reapIfExited(context: ?*anyopaque, pid: posix.pid_t) bool {
        _ = context;
        var status: c_int = 0;
        const rc = std.c.waitpid(pid, &status, std.c.W.NOHANG);
        return rc != 0;
    }

    /// Write the lockfile with PID and port
    fn writeLockfile(self: *WptServer) !void {
        const lockfile_path = try self.getLockfilePath();
        defer self.allocator.free(lockfile_path);

        const io = host.io();
        const file = try host.cwd().createFile(io, lockfile_path, .{});
        defer file.close(io);

        const content = try std.fmt.allocPrint(self.allocator, "{d}:{d}\n", .{ self.pid.?, self.port });
        defer self.allocator.free(content);
        try file.writeStreamingAll(io, content);
    }

    /// What a lockfile says: "pid:port".
    const Lock = struct {
        pid: posix.pid_t,
        port: u16,

        fn parse(content: []const u8) ?Lock {
            var iter = std.mem.splitScalar(u8, content, ':');
            const pid_str = iter.next() orelse return null;
            const port_str = iter.next() orelse return null;
            return .{
                .pid = std.fmt.parseInt(posix.pid_t, std.mem.trim(u8, pid_str, &std.ascii.whitespace), 10) catch return null,
                .port = std.fmt.parseInt(u16, std.mem.trim(u8, port_str, &std.ascii.whitespace), 10) catch return null,
            };
        }
    };

    /// The lockfile's content, or null when there is none or it does not
    /// parse (a lockfile being written reads empty for a moment). Neither is
    /// a reason to spawn: the port decides.
    fn readLockfile(self: *WptServer) ?Lock {
        const lockfile_path = self.getLockfilePath() catch return null;
        defer self.allocator.free(lockfile_path);
        var buf: [64]u8 = undefined;
        const content = host.cwd().readFile(host.io(), lockfile_path, &buf) catch return null;
        return Lock.parse(content);
    }

    /// Delete the lockfile only while it still says `lock` - never one another
    /// runner has written since we read it (rule 3).
    fn deleteLockfileNaming(self: *WptServer, lock: Lock) void {
        const now = self.readLockfile() orelse return;
        if (now.pid != lock.pid or now.port != lock.port) return;
        const lockfile_path = self.getLockfilePath() catch return;
        defer self.allocator.free(lockfile_path);
        host.cwd().deleteFile(host.io(), lockfile_path) catch {};
    }

    /// SIGTERM, a moment to shut down, then SIGKILL if it is still there.
    fn signalAndWait(pid: posix.pid_t) void {
        posix.kill(pid, posix.SIG.TERM) catch {};
        clock.sleep(100 * std.time.ns_per_ms);
        // Signal 0 is the existence probe; a zombie answers it, and SIGKILL
        // to one is harmless.
        if (std.c.kill(pid, @enumFromInt(0)) == 0) {
            posix.kill(pid, posix.SIG.KILL) catch {};
        }
    }

    /// Check if server is ready by attempting TCP connect
    fn isServerReady(self: *WptServer) bool {
        // 0.16: std.net is gone. IpAddress.parse takes no Io; connect and close do,
        // and ConnectOptions.mode has no default.
        const io = host.io();
        const address = std.Io.net.IpAddress.parseIp4("127.0.0.1", self.port) catch return false;
        const stream = address.connect(io, .{ .mode = .stream }) catch return false;
        stream.close(io);
        return true;
    }

    /// Stop the WPT server - but ONLY one we spawned ourselves.
    ///
    /// `start()` ADOPTS an already-running server when the lockfile names a
    /// live pid, and sets `we_spawned = false` for exactly that case. Killing
    /// an adopted server is not just impolite, it corrupts the next run:
    /// `wpt serve` is a multiprocessing parent whose children survive SIGTERM
    /// to the parent and keep holding :8000, so the next `start()` finds the
    /// port occupied, adopts the CORPSE, and every navigation then fails with a
    /// constant ~730ms NetworkError. One agent's baseline had 33 of 35 "ERROR"
    /// files laundered into noise by exactly this, which reads as an engine
    /// defect rather than a harness one.
    ///
    /// `deinit` already guards on `we_spawned`; `stop` did not, so calling it
    /// directly killed a server this process had merely borrowed.
    pub fn stop(self: *WptServer) void {
        if (!self.we_spawned) {
            // Not ours. Leave it running and just drop our reference.
            self.pid = null;
            return;
        }
        if (self.pid) |pid| {
            signalAndWait(pid);
            // The lockfile goes with our server - but only while it still
            // names it (rule 3). A runner whose child died at bind once took
            // the shared server's lockfile with it at exit, and with no
            // lockfile every later runner spawned and did the same.
            self.deleteLockfileNaming(.{ .pid = pid, .port = self.port });
        }

        self.pid = null;
        self.we_spawned = false;
    }

    /// Get the plain-HTTP base URL for the server, for display.
    ///
    /// Test URLs come from `buildTestUrl`, which picks the scheme per test.
    pub fn getBaseUrl(self: *WptServer, allocator: Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "http://{s}:{d}", .{ WPT_HOST, self.port });
    }

    /// The origin a given test's document will have once fetched.
    ///
    /// Same-origin checks for blob URLs and worker scripts compare against this,
    /// so it has to track the scheme and port the document actually came from.
    pub fn originFor(self: *WptServer, allocator: Allocator, test_path: []const u8) ![]u8 {
        const listener = Listener.of(test_path);
        return std.fmt.allocPrint(allocator, "{s}://{s}:{d}", .{ listener.scheme(), WPT_HOST, self.portOf(listener) });
    }

    /// This server's port for `listener`.
    fn portOf(self: *const WptServer, listener: Listener) u16 {
        return switch (listener) {
            .http => self.port,
            .https => self.https_port,
            .h2 => self.h2_port,
        };
    }

    /// Build a test URL from a test path, context type and variant.
    ///
    /// For .any.js tests, the WPT server generates different HTML wrappers:
    /// - Window context: test.any.html (runs test directly in window)
    /// - Worker context: test.any.worker.html (uses fetch_tests_from_worker)
    ///
    /// A `.https.` filename or `wpt_flags=https` query selects the TLS listener.
    ///
    /// `variant` is one of the file's `<meta name="variant">` values, appended
    /// verbatim after the wrapper suffix because it already carries its own `?`
    /// or `#`. Empty means the file declares no variants, which is the common
    /// case and leaves the URL exactly as it was before variants existed.
    pub fn buildTestUrl(
        self: *WptServer,
        allocator: Allocator,
        test_path: []const u8,
        context: test_parser.GlobalType,
        variant: []const u8,
    ) ![]u8 {
        var url_path = test_path;
        var suffix: []const u8 = "";

        if (std.mem.endsWith(u8, test_path, ".any.js")) {
            url_path = test_path[0 .. test_path.len - 7];
            // Generate context-specific URL
            suffix = switch (context) {
                .worker => ".any.worker.html",
                .sharedworker => ".any.sharedworker.html",
                .serviceworker => ".any.serviceworker.html",
                .worker_module => ".any.worker-module.html",
                .sharedworker_module => ".any.sharedworker-module.html",
                .serviceworker_module => ".any.serviceworker-module.html",
                else => ".any.html", // window and other contexts
            };
        } else if (std.mem.endsWith(u8, test_path, ".window.js")) {
            url_path = test_path[0 .. test_path.len - 10];
            suffix = ".window.html";
        } else if (std.mem.endsWith(u8, test_path, ".worker.js")) {
            url_path = test_path[0 .. test_path.len - 10];
            suffix = ".worker.html";
        }

        // A service worker variant is loaded over TLS whatever the file's
        // name says (WPT's manifest: its URL's "serviceworker" flag makes
        // it https, tools/manifest/item.py) - a service worker needs a
        // secure context.
        var listener: Listener = switch (context) {
            .serviceworker, .serviceworker_module => if (Listener.of(test_path) == .h2) .h2 else .https,
            else => Listener.of(test_path),
        };
        if (listener == .http and hasHttpsQueryFlag(variant)) listener = .https;
        return std.fmt.allocPrint(allocator, "{s}://{s}:{d}/{s}{s}{s}", .{
            listener.scheme(),
            WPT_HOST,
            self.portOf(listener),
            url_path,
            suffix,
            variant,
        });
    }
};

/// Held while one runner decides whether to spawn a server for a WPT root
/// (rule 4): an exclusive `flock` on the root directory itself, so no file is
/// added to the tree, and the kernel releases it when its holder exits,
/// however it exits. Two runners that both found nothing on the port would
/// otherwise both spawn, and the loser's child would die at bind.
const SpawnLock = struct {
    dir: std.Io.Dir,
    /// Whether another runner held it first - and so may have started a
    /// server meanwhile.
    waited: bool,

    fn acquire(wpt_root: []const u8) !SpawnLock {
        const io = host.io();
        const dir = try host.cwd().openDir(io, wpt_root, .{});
        errdefer dir.close(io);
        // flock takes any descriptor; File.lock is how std spells it.
        const file: std.Io.File = .{ .handle = dir.handle, .flags = .{ .nonblocking = false } };
        if (try file.tryLock(io, .exclusive)) return .{ .dir = dir, .waited = false };
        try file.lock(io, .exclusive);
        return .{ .dir = dir, .waited = true };
    }

    /// Closing the descriptor releases the lock.
    fn release(self: SpawnLock) void {
        self.dir.close(host.io());
    }
};

/// Write a lockfile naming `pid` into a scratch WPT root.
fn writeTestLockfile(io: std.Io, dir: std.Io.Dir, pid: posix.pid_t, port: u16) !void {
    var file = try dir.createFile(io, LOCKFILE_NAME, .{});
    defer file.close(io);
    var buf: [64]u8 = undefined;
    try file.writeStreamingAll(io, try std.fmt.bufPrint(&buf, "{d}:{d}\n", .{ pid, port }));
}

/// Adoption is decided by whether the PORT answers, not by the pid, so a test
/// has to own its port: listen on one nothing else uses for the adopt case,
/// and name one nothing listens on for the stale case. Writing :8000 as these
/// tests once did made their outcome depend on whether a real `wpt serve`
/// happened to be running on the machine.
const test_live_port: u16 = 38123;
const test_dead_port: u16 = 38124;

test "a live lockfile is adopted, not owned" {
    // Under --supervise the parent starts the server and every child finds it
    // this way. A child that thought it owned the server would SIGTERM it on
    // exit and leave the rest of the run with nothing to talk to.
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(root);

    // A real listener on the port, so the probe has something to answer it.
    const live_addr = try std.Io.net.IpAddress.parseIp4("127.0.0.1", test_live_port);
    var listener = try live_addr.listen(std.testing.io, .{ .mode = .stream });
    defer listener.deinit(std.testing.io);

    try writeTestLockfile(std.testing.io, tmp.dir, std.c.getpid(), test_live_port);

    const server = try WptServer.init(allocator, root);
    defer server.deinit();

    try std.testing.expect(try server.checkExistingServer());
    try std.testing.expectEqual(std.c.getpid(), server.pid.?);
    try std.testing.expectEqual(test_live_port, server.port);
    try std.testing.expect(!server.we_spawned);

    // Still there: adopting must not consume the lockfile the owner wrote.
    try tmp.dir.access(std.testing.io, LOCKFILE_NAME, .{});
}

test "a lockfile naming a dead process is cleared" {
    // A crashed run can leave its lockfile behind. Trusting it would point the
    // next run at a port nothing is listening on, and every test would fail
    // for a reason that has nothing to do with the browser.
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(root);

    // Above any pid_max, so kill() cannot find it and cannot ever be reused.
    try writeTestLockfile(std.testing.io, tmp.dir, 2147483646, test_dead_port);

    const server = try WptServer.init(allocator, root);
    defer server.deinit();
    server.probe_window_ms = 300;

    try std.testing.expect(!try server.checkExistingServer());
    try std.testing.expect(server.pid == null);
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(std.testing.io, LOCKFILE_NAME, .{}));
}

test "no lockfile and nothing on the port means no server to adopt" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(root);

    const server = try WptServer.init(allocator, root);
    defer server.deinit();
    // The port is probed with or without a lockfile, so it must be one
    // nothing listens on - not :8000, where a real `wpt serve` may run.
    server.port = test_dead_port;
    server.probe_window_ms = 300;

    try std.testing.expect(!try server.checkExistingServer());
    try std.testing.expect(server.pid == null);
}

/// Pids that cannot exist (above any pid_max): the test launchers below start
/// no process, and a `stop()` that signals one of these signals nothing.
const no_such_pid: posix.pid_t = 2147483640;

/// A launcher for the tests that starts no process: `spawn` binds the
/// server's port in this process, as `wpt serve` binds its ports. When the
/// port is free the "server" is up until `deinit`; when something already
/// holds it, the "server" has died at bind - what a real `wpt serve` does
/// beside the shared one.
const BindingLauncher = struct {
    pid: posix.pid_t,
    spawns: u32 = 0,
    listener: ?std.Io.net.Server = null,

    fn launcher(self: *BindingLauncher) WptServer.Launcher {
        return .{ .context = self, .spawn = spawn, .exited = exited };
    }

    fn spawn(context: ?*anyopaque, server: *WptServer) anyerror!posix.pid_t {
        const self: *BindingLauncher = @ptrCast(@alignCast(context.?));
        self.spawns += 1;
        const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", server.port);
        self.listener = address.listen(std.testing.io, .{ .mode = .stream }) catch null;
        return self.pid;
    }

    fn exited(context: ?*anyopaque, pid: posix.pid_t) bool {
        const self: *BindingLauncher = @ptrCast(@alignCast(context.?));
        std.debug.assert(pid == self.pid);
        return self.listener == null;
    }

    fn deinit(self: *BindingLauncher) void {
        if (self.listener) |*l| l.deinit(std.testing.io);
    }
};

/// A listener that starts listening only after a delay, on its own thread:
/// a served port whose first connects fail, as a busy shared server's do.
const LateListener = struct {
    port: u16,
    delay_ms: u64,
    listener: ?std.Io.net.Server = null,

    fn run(self: *LateListener) void {
        clock.sleep(self.delay_ms * std.time.ns_per_ms);
        const address = std.Io.net.IpAddress.parseIp4("127.0.0.1", self.port) catch return;
        self.listener = address.listen(std.testing.io, .{ .mode = .stream }) catch null;
    }

    fn deinit(self: *LateListener) void {
        if (self.listener) |*l| l.deinit(std.testing.io);
    }
};

fn expectLockfile(dir: std.Io.Dir, expected: []const u8) !void {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings(expected, try dir.readFile(std.testing.io, LOCKFILE_NAME, &buf));
}

test "a lockfile naming a dead pid is adopted, and left as it is, while its port is served" {
    // The shared server's lock can name a pid that is gone (a runner that
    // spawned, died at bind and wrote its pid anyway). The port is what
    // answers the question, and adopting rewrites nothing.
    const allocator = std.testing.allocator;
    const port: u16 = 38125;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(root);

    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
    var listener = try address.listen(std.testing.io, .{ .mode = .stream });
    defer listener.deinit(std.testing.io);
    try writeTestLockfile(std.testing.io, tmp.dir, no_such_pid, port);

    var launcher: BindingLauncher = .{ .pid = no_such_pid - 1 };
    defer launcher.deinit();
    const server = try WptServer.init(allocator, root);
    defer server.deinit();
    server.launcher = launcher.launcher();
    server.probe_window_ms = 300;

    try server.start();
    try std.testing.expectEqual(@as(u32, 0), launcher.spawns);
    try std.testing.expect(!server.we_spawned);
    try std.testing.expect(server.pid == null);
    try std.testing.expectEqual(port, server.port);
    try expectLockfile(tmp.dir, "2147483640:38125\n");
}

test "a missing lockfile is no reason to spawn while the port is served" {
    // 2026-10-28 on chat.local: once the shared server's lock was gone,
    // every runner that started spawned its own `wpt serve`, which died at
    // bind, and then deleted the lock again at exit.
    const allocator = std.testing.allocator;
    const port: u16 = 38126;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(root);

    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
    var listener = try address.listen(std.testing.io, .{ .mode = .stream });
    defer listener.deinit(std.testing.io);

    var launcher: BindingLauncher = .{ .pid = no_such_pid };
    defer launcher.deinit();
    const server = try WptServer.init(allocator, root);
    defer server.deinit();
    server.launcher = launcher.launcher();
    server.probe_window_ms = 300;
    server.port = port;

    try server.start();
    try std.testing.expectEqual(@as(u32, 0), launcher.spawns);
    try std.testing.expect(!server.we_spawned);
    try std.testing.expect(server.pid == null);
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(std.testing.io, LOCKFILE_NAME, .{}));
}

test "an unreadable lockfile is no reason to spawn while the port is served" {
    const allocator = std.testing.allocator;
    const port: u16 = 38127;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(root);

    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
    var listener = try address.listen(std.testing.io, .{ .mode = .stream });
    defer listener.deinit(std.testing.io);
    {
        var file = try tmp.dir.createFile(std.testing.io, LOCKFILE_NAME, .{});
        defer file.close(std.testing.io);
        try file.writeStreamingAll(std.testing.io, "not a lock");
    }

    var launcher: BindingLauncher = .{ .pid = no_such_pid };
    defer launcher.deinit();
    const server = try WptServer.init(allocator, root);
    defer server.deinit();
    server.launcher = launcher.launcher();
    server.probe_window_ms = 300;
    server.port = port;

    try server.start();
    try std.testing.expectEqual(@as(u32, 0), launcher.spawns);
    try std.testing.expect(!server.we_spawned);
    try expectLockfile(tmp.dir, "not a lock");
}

test "a port whose first connects fail is retried before its lockfile is called stale" {
    // One failed connect - a busy shared server's accept queue - used to be
    // enough to delete its lock and spawn a second server.
    const allocator = std.testing.allocator;
    const port: u16 = 38128;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(root);

    try writeTestLockfile(std.testing.io, tmp.dir, std.c.getpid(), port);
    var late: LateListener = .{ .port = port, .delay_ms = 300 };
    defer late.deinit();
    const thread = try std.Thread.spawn(.{}, LateListener.run, .{&late});

    var launcher: BindingLauncher = .{ .pid = no_such_pid };
    defer launcher.deinit();
    const server = try WptServer.init(allocator, root);
    defer server.deinit();
    server.launcher = launcher.launcher();
    server.probe_window_ms = 3000;

    const started = server.start();
    thread.join();
    try started;
    try std.testing.expectEqual(@as(u32, 0), launcher.spawns);
    try std.testing.expect(!server.we_spawned);
    try std.testing.expectEqual(std.c.getpid(), server.pid.?);
    var expected: [64]u8 = undefined;
    try expectLockfile(tmp.dir, try std.fmt.bufPrint(&expected, "{d}:{d}\n", .{ std.c.getpid(), port }));
}

test "a spawned server that dies at bind while the port answers is adopted, and nothing is rewritten" {
    // What `start` does once it has decided to spawn. The port turns out to
    // be served by someone else: our child dies at bind, and the lock must
    // still name the server that answers, not the corpse.
    const allocator = std.testing.allocator;
    const port: u16 = 38129;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(root);

    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
    var listener = try address.listen(std.testing.io, .{ .mode = .stream });
    defer listener.deinit(std.testing.io);
    try writeTestLockfile(std.testing.io, tmp.dir, std.c.getpid(), port);

    var launcher: BindingLauncher = .{ .pid = no_such_pid };
    defer launcher.deinit();
    const server = try WptServer.init(allocator, root);
    defer server.deinit();
    server.launcher = launcher.launcher();
    server.probe_window_ms = 300;
    server.port = port;

    try server.spawnServer();
    try std.testing.expectEqual(@as(u32, 1), launcher.spawns);
    try std.testing.expect(launcher.listener == null);
    try std.testing.expect(!server.we_spawned);
    try std.testing.expectEqual(std.c.getpid(), server.pid.?);
    var expected: [64]u8 = undefined;
    try expectLockfile(tmp.dir, try std.fmt.bufPrint(&expected, "{d}:{d}\n", .{ std.c.getpid(), port }));
}

test "stop removes the lockfile only while it names our own pid" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(root);

    const server = try WptServer.init(allocator, root);
    defer server.deinit();
    server.port = test_dead_port;

    // Another runner's server has the lock now: ours is not to remove.
    try writeTestLockfile(std.testing.io, tmp.dir, std.c.getpid(), test_dead_port);
    server.pid = no_such_pid;
    server.we_spawned = true;
    server.stop();
    var expected: [64]u8 = undefined;
    try expectLockfile(tmp.dir, try std.fmt.bufPrint(&expected, "{d}:{d}\n", .{ std.c.getpid(), test_dead_port }));

    // Our own lock goes with our server.
    try writeTestLockfile(std.testing.io, tmp.dir, no_such_pid, test_dead_port);
    server.pid = no_such_pid;
    server.we_spawned = true;
    server.stop();
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(std.testing.io, LOCKFILE_NAME, .{}));
}

/// One runner of the race below: starts when `go` is set.
const RacingRunner = struct {
    server: *WptServer,
    launcher: BindingLauncher,
    go: *std.atomic.Value(bool),
    result: anyerror!void = {},

    fn run(self: *RacingRunner) void {
        while (!self.go.load(.acquire)) std.atomic.spinLoopHint();
        self.result = self.server.start();
    }
};

test "two runners starting together spawn one server between them" {
    // A sweep starts its runners at once. With no server up, each probes,
    // finds nothing and would spawn; one at a time decides, and the second
    // adopts what the first started.
    const allocator = std.testing.allocator;
    const port: u16 = 38130;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(root);

    var go = std.atomic.Value(bool).init(false);
    var runners: [2]RacingRunner = undefined;
    for (&runners, 0..) |*r, i| {
        r.* = .{
            .server = try WptServer.init(allocator, root),
            .launcher = .{ .pid = no_such_pid - @as(posix.pid_t, @intCast(i)) },
            .go = &go,
        };
        r.server.launcher = r.launcher.launcher();
        r.server.probe_window_ms = 300;
        r.server.port = port;
    }
    defer for (&runners) |*r| {
        r.server.deinit();
        r.launcher.deinit();
    };

    var threads: [2]std.Thread = undefined;
    for (&threads, &runners) |*t, *r| t.* = try std.Thread.spawn(.{}, RacingRunner.run, .{r});
    go.store(true, .release);
    for (threads) |t| t.join();
    for (runners) |r| try r.result;

    try std.testing.expectEqual(@as(u32, 1), runners[0].launcher.spawns + runners[1].launcher.spawns);
    const spawner: usize = if (runners[0].server.we_spawned) 0 else 1;
    try std.testing.expect(runners[spawner].server.we_spawned);
    try std.testing.expect(!runners[1 - spawner].server.we_spawned);
    var expected: [64]u8 = undefined;
    try expectLockfile(tmp.dir, try std.fmt.bufPrint(&expected, "{d}:{d}\n", .{ runners[spawner].launcher.pid, port }));
}

test "WptServer.buildTestUrl" {
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    // Window context (default for .any.js)
    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/url/url-constructor.any.html", url);
    }

    // Worker context generates .any.worker.html
    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .worker, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/url/url-constructor.any.worker.html", url);
    }

    // A service worker variant is https whatever the file's name says
    // (WPT's manifest: tools/manifest/item.py), on the TLS listener.
    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .serviceworker, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("https://web-platform.test:8443/url/url-constructor.any.serviceworker.html", url);
    }
    {
        const url = try server.buildTestUrl(allocator, "cookiestore/x.https.any.js", .serviceworker, "?v");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("https://web-platform.test:8443/cookiestore/x.https.any.serviceworker.html?v", url);
    }

    // Window context for another .any.js test
    {
        const url = try server.buildTestUrl(allocator, "encoding/api-basics.any.js", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/encoding/api-basics.any.html", url);
    }

    // HTML files ignore context (always use raw path)
    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.html", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/dom/nodes/Element-matches.html", url);
    }
}

test "buildTestUrl appends a variant verbatim" {
    // A variant carries its own leading `?` or `#` - WPT writes them as
    // `<meta name="variant" content="?include=file">` - so it is concatenated
    // rather than joined. Anything that normalised it here would build a URL
    // that is not the one MANIFEST.json lists.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    {
        const url = try server.buildTestUrl(allocator, "encoding/single-byte-decoder.html", .window, "?windows-1252");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "http://web-platform.test:8000/encoding/single-byte-decoder.html?windows-1252",
            url,
        );
    }

    // A fragment variant is passed through untouched, not turned into a query.
    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.html", .window, "#target");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "http://web-platform.test:8000/dom/nodes/Element-matches.html#target",
            url,
        );
    }
}

test "buildTestUrl puts the variant after the generated wrapper suffix" {
    // The path `wpt serve` routes on is the wrapper - `x.any.worker.html` - and
    // the query is what the test reads back out of `location.search`. Appending
    // the variant before the suffix would ask for `x.any?q=1.worker.html` and
    // 404 every variant of every .any.js in the corpus.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .window, "?include=file");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "http://web-platform.test:8000/url/url-constructor.any.html?include=file",
            url,
        );
    }
    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .worker, "?include=file");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "http://web-platform.test:8000/url/url-constructor.any.worker.html?include=file",
            url,
        );
    }
    {
        const url = try server.buildTestUrl(allocator, "html/dom/idlharness.https.window.js", .window, "?exclude=Node");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "https://web-platform.test:8443/html/dom/idlharness.https.window.html?exclude=Node",
            url,
        );
    }
}

test "buildTestUrl with an empty variant is byte-identical to no variant" {
    // Two thirds of the corpus declares no variant and is modelled as declaring
    // one empty one, so this is the path almost every test takes. It has to
    // produce exactly the URL it produced before variants existed.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    for ([_][]const u8{
        "dom/nodes/Element-matches.html",
        "url/url-constructor.any.js",
        "fetch/api/basic/keepalive.https.any.js",
    }) |path| {
        for ([_]test_parser.GlobalType{ .window, .worker }) |ctx| {
            const url = try server.buildTestUrl(allocator, path, ctx, "");
            defer allocator.free(url);
            try std.testing.expect(std.mem.indexOfScalar(u8, url, '?') == null);
            try std.testing.expect(std.mem.endsWith(u8, url, ".html"));
        }
    }
}

test "a variant does not leak into the document origin" {
    // Same-origin checks compare against `originFor`, which is derived from the
    // path alone. If the query ever reached the origin string, every variant of
    // every test would look cross-origin to its own blob URLs and workers.
    const allocator = std.testing.allocator;

    var server = WptServer{ .allocator = allocator, .wpt_root = "tests/wpt" };

    const url = try server.buildTestUrl(allocator, "url/a-element.html", .window, "?include=file");
    defer allocator.free(url);
    const origin = try server.originFor(allocator, "url/a-element.html");
    defer allocator.free(origin);
    try std.testing.expectEqualStrings(origin, originOfUrl(url).?);
}

test "isHttpsTest keys off the filename, not the directory" {
    // WPT's convention is a flag in the *filename*. A directory that happens to
    // contain the string must not drag every test under it onto TLS.
    try std.testing.expect(isHttpsTest("fetch/api/basic/keepalive.https.any.js"));
    try std.testing.expect(isHttpsTest("cookiestore/cookieStore_get_arguments.https.html"));
    try std.testing.expect(isHttpsTest("html/dom/idlharness.https.window.js"));

    try std.testing.expect(!isHttpsTest("url/url-constructor.any.js"));
    try std.testing.expect(!isHttpsTest("dom/nodes/Element-matches.html"));
    // "https" without the trailing dot is just a word in a name.
    try std.testing.expect(!isHttpsTest("fetch/api/request/request-https.html"));
    // A directory carrying the marker does not make the test itself secure.
    try std.testing.expect(!isHttpsTest("some.https.dir/plain.html"));
}

test "a .https. test is fetched over TLS on the HTTPS port" {
    // These are 371 of the 4,107 in-scope sources. Served over plain HTTP they
    // 404 or hang, so every one of them baselines as TIMEOUT for a reason that
    // has nothing to do with the engine.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    {
        const url = try server.buildTestUrl(allocator, "cookiestore/cookieStore_get_arguments.https.html", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "https://web-platform.test:8443/cookiestore/cookieStore_get_arguments.https.html",
            url,
        );
    }

    // The suffix rewrite for generated wrappers still applies under TLS.
    {
        const url = try server.buildTestUrl(allocator, "fetch/api/basic/keepalive.https.any.js", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "https://web-platform.test:8443/fetch/api/basic/keepalive.https.any.html",
            url,
        );
    }
    {
        const url = try server.buildTestUrl(allocator, "html/dom/idlharness.https.window.js", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings(
            "https://web-platform.test:8443/html/dom/idlharness.https.window.html",
            url,
        );
    }
}

test "HTTPS query flags select the TLS listener without matching other parameters" {
    const allocator = std.testing.allocator;
    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();
    server.port = 8001;
    server.https_port = 8444;

    const cases = [_]struct {
        path: []const u8 = "websockets/cookies/006.html",
        variant: []const u8 = "",
        origin: []const u8,
    }{
        .{ .path = "crane/ws3-secure-cookie.https.html", .origin = "https://web-platform.test:8444" },
        .{ .variant = "?wss&wpt_flags=https", .origin = "https://web-platform.test:8444" },
        .{ .origin = "http://web-platform.test:8001" },
        .{ .variant = "?wpt_flags=www&wpt_flags=https#fragment", .origin = "https://web-platform.test:8444" },
        .{ .variant = "?wpt%5Fflags=h%74tps", .origin = "https://web-platform.test:8444" },
        .{ .variant = "?not_wpt_flags=https", .origin = "http://web-platform.test:8001" },
        .{ .variant = "?wpt_flags=https-extra", .origin = "http://web-platform.test:8001" },
        .{ .variant = "?wpt_flags=HTTPS", .origin = "http://web-platform.test:8001" },
        .{ .variant = "?other=wpt_flags%3Dhttps", .origin = "http://web-platform.test:8001" },
        .{ .variant = "#?wpt_flags=https", .origin = "http://web-platform.test:8001" },
        .{ .variant = "?other=1#wpt_flags=https", .origin = "http://web-platform.test:8001" },
    };
    for (cases) |case| {
        const built = try server.buildTestUrl(allocator, case.path, .window, case.variant);
        defer allocator.free(built);
        try std.testing.expectEqualStrings(case.origin, originOfUrl(built).?);
        const expected = try std.mem.concat(allocator, u8, &.{ case.origin, "/", case.path, case.variant });
        defer allocator.free(expected);
        try std.testing.expectEqualStrings(expected, built);
    }

    const worker_url = try server.buildTestUrl(allocator, "crane/ws3-flag.any.js", .worker, "?wpt_flags=https");
    defer allocator.free(worker_url);
    try std.testing.expectEqualStrings("https://web-platform.test:8444/crane/ws3-flag.any.worker.html?wpt_flags=https", worker_url);

    const h2_url = try server.buildTestUrl(allocator, "example.h2.html", .window, "?wpt_flags=https");
    defer allocator.free(h2_url);
    try std.testing.expectEqualStrings("https://web-platform.test:9000/example.h2.html?wpt_flags=https", h2_url);
}

test "a .h2. test is fetched from the HTTP/2 listener, and every URL builder agrees" {
    const allocator = std.testing.allocator;

    try std.testing.expect(isH2Test("fetch/api/basic/request-upload.h2.any.js"));
    try std.testing.expect(isH2Test("fetch/api/basic/request-upload.h2.any.worker.html"));
    try std.testing.expect(!isH2Test("fetch/h2.test/a.any.js"));
    try std.testing.expect(!isH2Test("fetch/api/basic/request-upload.any.js"));

    try std.testing.expectEqualStrings("http://web-platform.test:8000", testOriginFor("dom/nodes/Element-matches.html"));
    try std.testing.expectEqualStrings("https://web-platform.test:8443", testOriginFor("fetch/api/basic/keepalive.https.any.js"));
    try std.testing.expectEqualStrings("https://web-platform.test:9000", testOriginFor("xhr/status.h2.window.js"));
    // An h2 test is TLS as well; the HTTP/2 listener wins.
    try std.testing.expectEqualStrings("https://web-platform.test:9000", testOriginFor("a/b.h2.https.html"));

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();
    {
        const url = try server.buildTestUrl(allocator, "fetch/api/basic/request-upload.h2.any.js", .worker, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("https://web-platform.test:9000/fetch/api/basic/request-upload.h2.any.worker.html", url);
    }
    {
        const origin = try server.originFor(allocator, "xhr/status.h2.window.js");
        defer allocator.free(origin);
        try std.testing.expectEqualStrings(testOriginFor("xhr/status.h2.window.js"), origin);
    }
}

test "the document origin matches the scheme and port the test was fetched from" {
    // Blob URLs and worker script fetches are same-origin checked against this
    // string. Handing a TLS test the http:// origin makes those checks fail in
    // a way that looks like a spec bug.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    {
        const origin = try server.originFor(allocator, "url/url-constructor.any.js");
        defer allocator.free(origin);
        try std.testing.expectEqualStrings("http://web-platform.test:8000", origin);
    }
    {
        const origin = try server.originFor(allocator, "fetch/api/basic/keepalive.https.any.js");
        defer allocator.free(origin);
        try std.testing.expectEqualStrings("https://web-platform.test:8443", origin);
    }
}

test "a non-default port pair is carried into both schemes" {
    // The ports are fields, not literals, so a run that had to move off 8000
    // still builds URLs that point at itself.
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();
    server.port = 8001;
    server.https_port = 8444;

    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.html", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8001/dom/nodes/Element-matches.html", url);
    }
    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.https.html", .window, "");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("https://web-platform.test:8444/dom/nodes/Element-matches.https.html", url);
    }
}

test "originOfUrl keeps scheme, host and port and drops everything after" {
    try std.testing.expectEqualStrings(
        "http://web-platform.test:8000",
        originOfUrl("http://web-platform.test:8000/url/a-element.html").?,
    );
    try std.testing.expectEqualStrings(
        "https://web-platform.test:8443",
        originOfUrl("https://web-platform.test:8443/fetch/api/basic/x.https.html?q=1#frag").?,
    );
}

test "originOfUrl handles an authority with no path at all" {
    try std.testing.expectEqualStrings(
        "http://web-platform.test:8000",
        originOfUrl("http://web-platform.test:8000").?,
    );
}

test "originOfUrl stops at a query or fragment that precedes any slash" {
    try std.testing.expectEqualStrings(
        "http://web-platform.test:8000",
        originOfUrl("http://web-platform.test:8000?q=1").?,
    );
}

test "originOfUrl declines anything that is not an absolute URL" {
    try std.testing.expectEqual(@as(?[]const u8, null), originOfUrl("/url/a-element.html"));
    try std.testing.expectEqual(@as(?[]const u8, null), originOfUrl("a-element.html"));
    try std.testing.expectEqual(@as(?[]const u8, null), originOfUrl(""));
}

test "the origin of a built test URL is the origin the test will report" {
    const allocator = std.testing.allocator;

    var server = WptServer{ .allocator = allocator, .wpt_root = "tests/wpt" };

    const plain = try server.buildTestUrl(allocator, "url/a-element.html", .window, "");
    defer allocator.free(plain);
    const plain_origin = try server.originFor(allocator, "url/a-element.html");
    defer allocator.free(plain_origin);
    try std.testing.expectEqualStrings(plain_origin, originOfUrl(plain).?);

    const tls = try server.buildTestUrl(allocator, "fetch/api/basic/x.https.html", .window, "");
    defer allocator.free(tls);
    const tls_origin = try server.originFor(allocator, "fetch/api/basic/x.https.html");
    defer allocator.free(tls_origin);
    try std.testing.expectEqualStrings(tls_origin, originOfUrl(tls).?);
}
