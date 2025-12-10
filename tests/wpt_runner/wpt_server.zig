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

/// Lockfile name stored in WPT root
const LOCKFILE_NAME = ".wpt_serve.lock";

/// WPT Server manager
pub const WptServer = struct {
    allocator: Allocator,
    /// WPT root directory
    wpt_root: []const u8,
    /// Server port
    port: u16 = 8000,
    /// PID of the server process (from lockfile or spawned)
    pid: ?posix.pid_t = null,
    /// Whether we spawned the server (vs found existing)
    we_spawned: bool = false,

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

    /// Start the WPT server
    ///
    /// First checks if a server is already running (via lockfile).
    /// If not, spawns a new server and writes the lockfile.
    pub fn start(self: *WptServer) !void {
        // Check for existing server
        if (try self.checkExistingServer()) {
            return; // Server already running
        }

        // Spawn new server
        try self.spawnServer();
    }

    /// Check if an existing server is running via lockfile
    fn checkExistingServer(self: *WptServer) !bool {
        const lockfile_path = try self.getLockfilePath();
        defer self.allocator.free(lockfile_path);

        const file = std.fs.cwd().openFile(lockfile_path, .{}) catch |err| {
            if (err == error.FileNotFound) return false;
            return err;
        };
        defer file.close();

        // Read lockfile: "pid:port"
        var buf: [64]u8 = undefined;
        const bytes_read = try file.readAll(&buf);
        const content = buf[0..bytes_read];

        // Parse PID and port
        var iter = std.mem.splitScalar(u8, content, ':');
        const pid_str = iter.next() orelse return false;
        const port_str = iter.next() orelse return false;

        const pid = std.fmt.parseInt(posix.pid_t, std.mem.trim(u8, pid_str, &std.ascii.whitespace), 10) catch return false;
        const port = std.fmt.parseInt(u16, std.mem.trim(u8, port_str, &std.ascii.whitespace), 10) catch return false;

        // Check if process is still alive (signal 0 just checks existence)
        if (posix.kill(pid, 0)) {
            // Process exists, use it
            self.pid = pid;
            self.port = port;
            self.we_spawned = false;
            return true;
        } else |_| {
            // Process doesn't exist - stale lockfile, remove it
            std.fs.cwd().deleteFile(lockfile_path) catch {};
            return false;
        }
    }

    /// Spawn the wpt serve process
    fn spawnServer(self: *WptServer) !void {
        const argv = [_][]const u8{
            "python3",
            "wpt.py",
            "serve",
            "--config",
            "config.json",
        };

        var child = std.process.Child.init(&argv, self.allocator);
        child.cwd = self.wpt_root;

        // Ignore output to avoid noise
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;

        try child.spawn();

        self.pid = child.id;
        self.we_spawned = true;

        // Write lockfile
        try self.writeLockfile();

        // Wait for server to be ready (simple TCP check)
        try self.waitForReady();
    }

    /// Write the lockfile with PID and port
    fn writeLockfile(self: *WptServer) !void {
        const lockfile_path = try self.getLockfilePath();
        defer self.allocator.free(lockfile_path);

        const file = try std.fs.cwd().createFile(lockfile_path, .{});
        defer file.close();

        const content = try std.fmt.allocPrint(self.allocator, "{d}:{d}\n", .{ self.pid.?, self.port });
        defer self.allocator.free(content);
        try file.writeAll(content);
    }

    /// Remove the lockfile
    fn removeLockfile(self: *WptServer) void {
        const lockfile_path = self.getLockfilePath() catch return;
        defer self.allocator.free(lockfile_path);
        std.fs.cwd().deleteFile(lockfile_path) catch {};
    }

    /// Wait for server to become ready
    fn waitForReady(self: *WptServer) !void {
        const max_attempts = 100; // 10 seconds total
        const delay_ns: u64 = 100 * std.time.ns_per_ms;

        var attempt: usize = 0;
        while (attempt < max_attempts) : (attempt += 1) {
            if (self.isServerReady()) {
                return;
            }
            std.Thread.sleep(delay_ns);
        }

        return error.ServerStartTimeout;
    }

    /// Check if server is ready by attempting TCP connect
    fn isServerReady(self: *WptServer) bool {
        const address = std.net.Address.parseIp4("127.0.0.1", self.port) catch return false;
        const stream = std.net.tcpConnectToAddress(address) catch return false;
        stream.close();
        return true;
    }

    /// Stop the WPT server
    pub fn stop(self: *WptServer) void {
        if (self.pid) |pid| {
            // Send SIGTERM
            posix.kill(pid, posix.SIG.TERM) catch {};

            // Give it a moment to shutdown gracefully
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Force kill if still alive
            if (posix.kill(pid, 0)) {
                posix.kill(pid, posix.SIG.KILL) catch {};
            } else |_| {}
        }

        if (self.we_spawned) {
            self.removeLockfile();
        }

        self.pid = null;
        self.we_spawned = false;
    }

    /// Get the base URL for the server
    pub fn getBaseUrl(self: *WptServer) []const u8 {
        _ = self;
        return "http://localhost:8000";
    }

    /// Build a test URL from a test path and context type
    ///
    /// For .any.js tests, the WPT server generates different HTML wrappers:
    /// - Window context: test.any.html (runs test directly in window)
    /// - Worker context: test.any.worker.html (uses fetch_tests_from_worker)
    pub fn buildTestUrl(self: *WptServer, allocator: Allocator, test_path: []const u8, context: test_parser.GlobalType) ![]u8 {
        var url_path = test_path;
        var suffix: []const u8 = "";

        if (std.mem.endsWith(u8, test_path, ".any.js")) {
            url_path = test_path[0 .. test_path.len - 7];
            // Generate context-specific URL
            suffix = switch (context) {
                .worker => ".any.worker.html",
                .sharedworker => ".any.sharedworker.html",
                .serviceworker => ".any.serviceworker.html",
                else => ".any.html", // window and other contexts
            };
        } else if (std.mem.endsWith(u8, test_path, ".window.js")) {
            url_path = test_path[0 .. test_path.len - 10];
            suffix = ".window.html";
        } else if (std.mem.endsWith(u8, test_path, ".worker.js")) {
            url_path = test_path[0 .. test_path.len - 10];
            suffix = ".worker.html";
        }

        return std.fmt.allocPrint(allocator, "{s}/{s}{s}", .{
            self.getBaseUrl(),
            url_path,
            suffix,
        });
    }
};

test "WptServer.buildTestUrl" {
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    // Window context (default for .any.js)
    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .window);
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://localhost:8000/url/url-constructor.any.html", url);
    }

    // Worker context generates .any.worker.html
    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .worker);
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://localhost:8000/url/url-constructor.any.worker.html", url);
    }

    // Window context for another .any.js test
    {
        const url = try server.buildTestUrl(allocator, "encoding/api-basics.any.js", .window);
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://localhost:8000/encoding/api-basics.any.html", url);
    }

    // HTML files ignore context (always use raw path)
    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.html", .window);
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://localhost:8000/dom/nodes/Element-matches.html", url);
    }
}
