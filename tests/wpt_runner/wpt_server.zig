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

/// Required WPT hostnames for proper test execution
/// These must be configured in /etc/hosts to resolve to 127.0.0.1
/// See: https://web-platform-tests.org/running-tests/from-local-system.html#system-setup
pub const required_hosts = [_][]const u8{
    "web-platform.test",
    "www.web-platform.test",
    "www1.web-platform.test",
    "www2.web-platform.test",
    "xn--n3h.web-platform.test", // IDN hostname
    "xn--lve-6lad.web-platform.test", // IDN hostname
};

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
    /// First validates host configuration, then checks if a server is already running (via lockfile).
    /// If not, spawns a new server and writes the lockfile.
    /// Always verifies all required ports are ready.
    pub fn start(self: *WptServer) !void {
        // Validate host configuration before starting
        try self.validateHostConfiguration();

        // Check for existing server
        if (try self.checkExistingServer()) {
            // Verify all required ports are ready (existing server may not have alternate ports)
            self.waitForReady() catch {
                // Existing server doesn't have all ports - kill it and start fresh
                std.debug.print("WPT Server: Existing server missing required ports, restarting...\n", .{});
                self.stop();
                try self.spawnServer();
            };
            return;
        }

        // Spawn new server
        try self.spawnServer();
    }

    /// Validate that required WPT hostnames are configured in /etc/hosts
    /// WPT tests require specific hostnames to be resolvable to 127.0.0.1
    fn validateHostConfiguration(self: *WptServer) !void {
        _ = self;
        var missing_hosts: usize = 0;

        for (required_hosts) |host| {
            // Check /etc/hosts directly since std.net.Address.resolveIp only parses IP strings
            if (!hostExistsInHostsFile(host)) {
                if (missing_hosts == 0) {
                    std.debug.print("\n", .{});
                    std.debug.print("ERROR: Required WPT hostnames not configured.\n", .{});
                    std.debug.print("The following hosts must resolve to 127.0.0.1:\n", .{});
                    std.debug.print("\n", .{});
                }
                std.debug.print("  Missing: {s}\n", .{host});
                missing_hosts += 1;
            }
        }

        if (missing_hosts > 0) {
            std.debug.print("\n", .{});
            std.debug.print("To fix, add these lines to /etc/hosts:\n", .{});
            std.debug.print("\n", .{});
            for (required_hosts) |host| {
                std.debug.print("  127.0.0.1   {s}\n", .{host});
            }
            std.debug.print("\n", .{});
            std.debug.print("See: https://web-platform-tests.org/running-tests/from-local-system.html#system-setup\n", .{});
            std.debug.print("\n", .{});
            return error.HostNotConfigured;
        }
    }

    /// Check if a hostname exists in /etc/hosts
    fn hostExistsInHostsFile(hostname: []const u8) bool {
        const file = std.fs.openFileAbsolute("/etc/hosts", .{}) catch return false;
        defer file.close();

        var buf: [4096]u8 = undefined;
        const bytes_read = file.readAll(&buf) catch return false;
        const content = buf[0..bytes_read];

        // Parse each line looking for the hostname
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            // Skip comments and empty lines
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            // Split by whitespace to get IP and hostnames
            var parts = std.mem.tokenizeAny(u8, trimmed, " \t");
            _ = parts.next(); // Skip IP address

            // Check remaining parts for hostname match
            while (parts.next()) |host| {
                if (std.mem.eql(u8, host, hostname)) {
                    return true;
                }
            }
        }
        return false;
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

    /// Required ports for WPT alternate ports infrastructure
    /// See: https://github.com/web-platform-tests/rfcs/blob/master/rfcs/address_space_overrides.md
    const required_ports = [_]u16{
        8000, // http primary
        8001, // http secondary
        8002, // http-local (Local Network Access)
        8003, // http-public (Local Network Access)
        8443, // https primary
        8444, // https secondary
        8445, // https-local (Local Network Access)
        8446, // https-public (Local Network Access)
    };

    /// Wait for server to become ready on all required ports
    fn waitForReady(self: *WptServer) !void {
        // First wait for primary port
        try self.waitForPort(self.port);

        // Then verify all required ports are open
        for (required_ports) |port| {
            self.waitForPort(port) catch |err| {
                std.debug.print("WPT Server: Port {d} failed to open: {}\n", .{ port, err });
                return err;
            };
        }
    }

    /// Wait for a specific port to become ready
    fn waitForPort(self: *WptServer, port: u16) !void {
        _ = self;
        const max_attempts = 100; // 10 seconds total per port
        const delay_ns: u64 = 100 * std.time.ns_per_ms;

        var attempt: usize = 0;
        while (attempt < max_attempts) : (attempt += 1) {
            if (isPortReady(port)) {
                return;
            }
            std.Thread.sleep(delay_ns);
        }

        return error.PortNotReady;
    }

    /// Check if a specific port is ready by attempting TCP connect
    fn isPortReady(port: u16) bool {
        const address = std.net.Address.parseIp4("127.0.0.1", port) catch return false;
        const stream = std.net.tcpConnectToAddress(address) catch return false;
        stream.close();
        return true;
    }

    /// Check if server is ready by attempting TCP connect to primary port
    fn isServerReady(self: *WptServer) bool {
        return isPortReady(self.port);
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

    /// Get the base URL for the server (HTTP)
    /// Uses web-platform.test hostname as required by WPT specification
    /// See: https://web-platform-tests.org/running-tests/from-local-system.html#system-setup
    pub fn getBaseUrl(self: *WptServer) []const u8 {
        _ = self;
        return "http://web-platform.test:8000";
    }

    /// Get the base URL for HTTPS connections
    /// Uses port 8443 (primary HTTPS port)
    /// WPT server uses self-signed certificates - SSL verification should be disabled
    pub fn getHttpsBaseUrl(self: *WptServer) []const u8 {
        _ = self;
        return "https://web-platform.test:8443";
    }

    /// Build test URL with scheme based on test path
    /// Tests with .https. in the path or ending in .https.html use HTTPS
    pub fn buildTestUrlWithScheme(self: *WptServer, allocator: Allocator, test_path: []const u8, context: test_parser.GlobalType) ![]u8 {
        // Determine if test requires HTTPS
        const use_https = std.mem.indexOf(u8, test_path, ".https.") != null or
            std.mem.endsWith(u8, test_path, ".https.html") or
            std.mem.endsWith(u8, test_path, ".https.htm");

        const base_url = if (use_https) self.getHttpsBaseUrl() else self.getBaseUrl();

        var url_path = test_path;
        var suffix: []const u8 = "";

        if (std.mem.endsWith(u8, test_path, ".any.js")) {
            url_path = test_path[0 .. test_path.len - 7];
            suffix = switch (context) {
                .worker => ".any.worker.html",
                .sharedworker => ".any.sharedworker.html",
                .serviceworker => ".any.serviceworker.html",
                else => ".any.html",
            };
        } else if (std.mem.endsWith(u8, test_path, ".window.js")) {
            url_path = test_path[0 .. test_path.len - 10];
            suffix = ".window.html";
        } else if (std.mem.endsWith(u8, test_path, ".worker.js")) {
            url_path = test_path[0 .. test_path.len - 10];
            suffix = ".worker.html";
        }

        return try std.fmt.allocPrint(allocator, "{s}/{s}{s}", .{
            base_url,
            url_path,
            suffix,
        });
    }

    /// Build a test URL from a test path and context type
    ///
    /// For .any.js tests, the WPT server generates different HTML wrappers:
    /// - Window context: test.any.html (runs test directly in window)
    /// - Worker context: test.any.worker.html (uses fetch_tests_from_worker)
    ///
    /// This method automatically detects HTTPS requirements from file flags
    /// (.https., .h2.) and uses the appropriate scheme and port.
    pub fn buildTestUrl(self: *WptServer, allocator: Allocator, test_path: []const u8, context: test_parser.GlobalType) ![]u8 {
        // Delegate to buildTestUrlWithScheme which handles HTTPS detection
        return self.buildTestUrlWithScheme(allocator, test_path, context);
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
        try std.testing.expectEqualStrings("http://web-platform.test:8000/url/url-constructor.any.html", url);
    }

    // Worker context generates .any.worker.html
    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js", .worker);
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/url/url-constructor.any.worker.html", url);
    }

    // Window context for another .any.js test
    {
        const url = try server.buildTestUrl(allocator, "encoding/api-basics.any.js", .window);
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/encoding/api-basics.any.html", url);
    }

    // HTML files ignore context (always use raw path)
    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.html", .window);
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://web-platform.test:8000/dom/nodes/Element-matches.html", url);
    }
}

test "WptServer.getBaseUrl returns web-platform.test" {
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    const base_url = server.getBaseUrl();
    try std.testing.expectEqualStrings("http://web-platform.test:8000", base_url);
}
