//! WPT Server Manager
//!
//! This module manages the lifecycle of the `wpt serve` Python server.
//! The WPT server provides proper URL routing, script rewrites (like
//! WebIDLParser.js → webidl2.js), and test variant generation.
//!
//! ## Usage
//!
//! ```zig
//! var server = try WptServer.init(allocator, "tests/wpt");
//! defer server.deinit();
//!
//! try server.start();
//! defer server.stop();
//!
//! // Server is now running at http://localhost:8000
//! // Navigate browser to test URLs like:
//! // http://localhost:8000/url/url-constructor.any.html
//! ```
//!
//! ## Configuration
//!
//! Requires `tests/wpt/config.json` with:
//! ```json
//! {
//!   "browser_host": "localhost",
//!   "bind_address": true,
//!   "alternate_hosts": {},
//!   "check_subdomains": false,
//!   "ports": {"http": [8000, 8001]}
//! }
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// WPT Server manager
pub const WptServer = struct {
    allocator: Allocator,
    /// WPT root directory
    wpt_root: []const u8,
    /// Child process handle
    process: ?std.process.Child = null,
    /// Server port (default 8000)
    port: u16 = 8000,
    /// Whether server is running
    running: bool = false,

    /// Initialize the WPT server manager
    pub fn init(allocator: Allocator, wpt_root: []const u8) !*WptServer {
        const server = try allocator.create(WptServer);
        server.* = WptServer{
            .allocator = allocator,
            .wpt_root = try allocator.dupe(u8, wpt_root),
        };
        return server;
    }

    /// Cleanup
    pub fn deinit(self: *WptServer) void {
        if (self.running) {
            self.stop();
        }
        self.allocator.free(self.wpt_root);
        self.allocator.destroy(self);
    }

    /// Start the WPT server
    ///
    /// Launches `python wpt.py serve` in the WPT root directory.
    /// Waits for the server to become ready before returning.
    pub fn start(self: *WptServer) !void {
        if (self.running) return;

        // Build the command
        const argv = [_][]const u8{
            "python3",
            "wpt.py",
            "serve",
        };

        // Spawn the process
        var child = std.process.Child.init(&argv, self.allocator);
        child.cwd = self.wpt_root;

        // Don't inherit stdout/stderr - capture them to avoid noise
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();
        self.process = child;
        self.running = true;

        // Wait for server to be ready
        try self.waitForReady();
    }

    /// Stop the WPT server
    pub fn stop(self: *WptServer) void {
        if (!self.running) return;

        if (self.process) |*child| {
            // Send SIGTERM to gracefully stop
            _ = child.kill() catch {};

            // Wait for process to exit
            _ = child.wait() catch {};
        }

        self.process = null;
        self.running = false;
    }

    /// Wait for server to become ready
    fn waitForReady(self: *WptServer) !void {
        const max_attempts = 50; // 5 seconds total
        const delay_ms = 100;

        var attempt: usize = 0;
        while (attempt < max_attempts) : (attempt += 1) {
            if (self.isServerReady()) {
                return;
            }
            std.time.sleep(delay_ms * std.time.ns_per_ms);
        }

        return error.ServerStartTimeout;
    }

    /// Check if server is ready by attempting to connect
    fn isServerReady(self: *WptServer) bool {
        // Try to connect to the server
        const address = std.net.Address.parseIp4("127.0.0.1", self.port) catch return false;
        const stream = std.net.tcpConnectToAddress(address) catch return false;
        stream.close();
        return true;
    }

    /// Get the base URL for the server
    pub fn getBaseUrl(self: *WptServer) []const u8 {
        _ = self;
        return "http://localhost:8000";
    }

    /// Build a test URL from a test path
    ///
    /// Converts paths like "url/url-constructor.any.js" to
    /// "http://localhost:8000/url/url-constructor.any.html"
    pub fn buildTestUrl(self: *WptServer, allocator: Allocator, test_path: []const u8) ![]u8 {
        // Convert .any.js to .any.html for browser execution
        var url_path = test_path;
        var suffix: []const u8 = "";

        if (std.mem.endsWith(u8, test_path, ".any.js")) {
            url_path = test_path[0 .. test_path.len - 7]; // Remove ".any.js"
            suffix = ".any.html";
        } else if (std.mem.endsWith(u8, test_path, ".window.js")) {
            url_path = test_path[0 .. test_path.len - 10]; // Remove ".window.js"
            suffix = ".window.html";
        } else if (std.mem.endsWith(u8, test_path, ".worker.js")) {
            url_path = test_path[0 .. test_path.len - 10]; // Remove ".worker.js"
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

    var server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    {
        const url = try server.buildTestUrl(allocator, "url/url-constructor.any.js");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://localhost:8000/url/url-constructor.any.html", url);
    }

    {
        const url = try server.buildTestUrl(allocator, "encoding/api-basics.any.js");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://localhost:8000/encoding/api-basics.any.html", url);
    }

    {
        const url = try server.buildTestUrl(allocator, "dom/nodes/Element-matches.html");
        defer allocator.free(url);
        try std.testing.expectEqualStrings("http://localhost:8000/dom/nodes/Element-matches.html", url);
    }
}
