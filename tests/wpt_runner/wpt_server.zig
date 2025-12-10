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
//!
//! // Fetch resources from the server
//! const content = try server.fetch(allocator, "/url/url-constructor.any.html");
//! defer allocator.free(content);
//! ```
//!
//! ## Configuration
//!
//! Uses `tests/wpt/config.json` with:
//! ```json
//! {
//!   "browser_host": "localhost",
//!   "bind_address": true,
//!   "alternate_hosts": {},
//!   "check_subdomains": false,
//!   "ports": {"http": [8000, 8001]},
//!   "ssl": {"type": "none"}
//! }
//! ```
//!
//! ## Server Features
//!
//! The wpt serve server provides:
//! - URL rewrites (e.g., `/resources/WebIDLParser.js` → `/resources/webidl2/lib/webidl2.js`)
//! - Virtual test variants (`.any.js` → `.any.html`, `.any.worker.html`)
//! - Proper MIME types for all resources
//! - CORS headers for cross-origin requests
//! - .headers files for per-resource HTTP headers

const std = @import("std");
const Allocator = std.mem.Allocator;

/// HTTP response from wpt serve
pub const HttpResponse = struct {
    allocator: Allocator,
    status_code: u16,
    body: []u8,
    content_type: ?[]u8,

    pub fn deinit(self: *HttpResponse) void {
        self.allocator.free(self.body);
        if (self.content_type) |ct| {
            self.allocator.free(ct);
        }
    }

    pub fn isOk(self: HttpResponse) bool {
        return self.status_code >= 200 and self.status_code < 300;
    }
};

/// WPT Server manager
pub const WptServer = struct {
    allocator: Allocator,
    /// WPT root directory (absolute path)
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
    /// Launches `python wpt.py serve --config config.json` in the WPT root directory.
    /// Waits for the server to become ready before returning.
    pub fn start(self: *WptServer) !void {
        if (self.running) return;

        // Build the command - use the config.json we created
        const argv = [_][]const u8{
            "python3",
            "wpt.py",
            "serve",
            "--config",
            "config.json",
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

    /// Wait for server to become ready by polling HTTP endpoint
    fn waitForReady(self: *WptServer) !void {
        const max_attempts = 100; // 10 seconds total (wpt serve can take a while to start)
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

    /// Check if server is ready by making an HTTP request
    fn isServerReady(self: *WptServer) bool {
        // Try to fetch a known resource
        var response = self.fetchInternal("/resources/testharness.js") catch return false;
        defer response.deinit();
        return response.isOk();
    }

    /// Get the base URL for the server
    pub fn getBaseUrl(self: *WptServer) []const u8 {
        _ = self;
        return "http://localhost:8000";
    }

    /// Fetch a resource from the WPT server
    ///
    /// @param path The URL path (e.g., "/url/url-constructor.any.html")
    /// @return The response body as bytes
    pub fn fetch(self: *WptServer, allocator: Allocator, path: []const u8) ![]u8 {
        const response = try self.fetchWithHeaders(allocator, path);
        defer {
            if (response.content_type) |ct| allocator.free(ct);
        }
        // Don't free body - we're returning it
        return response.body;
    }

    /// Fetch a resource with full response information
    pub fn fetchWithHeaders(self: *WptServer, allocator: Allocator, path: []const u8) !HttpResponse {
        _ = allocator; // Use self.allocator for internal operations
        return self.fetchInternal(path);
    }

    /// Internal fetch implementation using raw TCP socket
    /// Sends a simple HTTP/1.1 GET request and parses the response
    fn fetchInternal(self: *WptServer, path: []const u8) !HttpResponse {
        // Connect to server
        const address = try std.net.Address.parseIp4("127.0.0.1", self.port);
        const stream = try std.net.tcpConnectToAddress(address);
        defer stream.close();

        // Build and send HTTP request
        const request = try std.fmt.allocPrint(self.allocator, "GET {s} HTTP/1.1\r\nHost: localhost:{d}\r\nConnection: close\r\n\r\n", .{
            path,
            self.port,
        });
        defer self.allocator.free(request);

        _ = try stream.write(request);

        // Read all response data
        var response_data: std.ArrayListUnmanaged(u8) = .{};
        defer response_data.deinit(self.allocator);

        var buf: [4096]u8 = undefined;
        while (true) {
            const n = stream.read(&buf) catch |err| {
                if (err == error.ConnectionResetByPeer) break;
                return err;
            };
            if (n == 0) break;
            try response_data.appendSlice(self.allocator, buf[0..n]);
        }

        // Parse HTTP response
        const full_response = response_data.items;

        // Find end of headers
        const header_end = std.mem.indexOf(u8, full_response, "\r\n\r\n") orelse {
            return HttpResponse{
                .allocator = self.allocator,
                .status_code = 0,
                .body = try self.allocator.dupe(u8, ""),
                .content_type = null,
            };
        };

        const headers = full_response[0..header_end];
        const body_start = header_end + 4;
        const body = full_response[body_start..];

        // Parse status code from first line (e.g., "HTTP/1.1 200 OK")
        var status_code: u16 = 0;
        if (std.mem.indexOf(u8, headers, " ")) |space_pos| {
            const after_version = headers[space_pos + 1 ..];
            if (std.mem.indexOf(u8, after_version, " ")) |second_space| {
                const code_str = after_version[0..second_space];
                status_code = std.fmt.parseInt(u16, code_str, 10) catch 0;
            }
        }

        // Parse Content-Type header
        var content_type: ?[]u8 = null;
        var lines = std.mem.splitSequence(u8, headers, "\r\n");
        while (lines.next()) |line| {
            if (std.ascii.startsWithIgnoreCase(line, "content-type:")) {
                const value = std.mem.trim(u8, line["content-type:".len..], " ");
                content_type = try self.allocator.dupe(u8, value);
                break;
            }
        }

        return HttpResponse{
            .allocator = self.allocator,
            .status_code = status_code,
            .body = try self.allocator.dupe(u8, body),
            .content_type = content_type,
        };
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

    /// Build test URL path without the base URL
    /// Returns path like "/url/url-constructor.any.html"
    pub fn buildTestPath(self: *WptServer, allocator: Allocator, test_path: []const u8) ![]u8 {
        _ = self;
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

        return std.fmt.allocPrint(allocator, "/{s}{s}", .{
            url_path,
            suffix,
        });
    }
};

test "WptServer.buildTestUrl" {
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
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

test "WptServer.buildTestPath" {
    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    {
        const path = try server.buildTestPath(allocator, "url/url-constructor.any.js");
        defer allocator.free(path);
        try std.testing.expectEqualStrings("/url/url-constructor.any.html", path);
    }

    {
        const path = try server.buildTestPath(allocator, "encoding/api-basics.window.js");
        defer allocator.free(path);
        try std.testing.expectEqualStrings("/encoding/api-basics.window.html", path);
    }

    {
        const path = try server.buildTestPath(allocator, "streams/test.worker.js");
        defer allocator.free(path);
        try std.testing.expectEqualStrings("/streams/test.worker.html", path);
    }

    {
        const path = try server.buildTestPath(allocator, "dom/nodes/Element-matches.html");
        defer allocator.free(path);
        try std.testing.expectEqualStrings("/dom/nodes/Element-matches.html", path);
    }
}

test "HttpResponse.isOk" {
    const allocator = std.testing.allocator;

    // Test 200 OK
    {
        var response = HttpResponse{
            .allocator = allocator,
            .status_code = 200,
            .body = try allocator.dupe(u8, "test"),
            .content_type = null,
        };
        defer response.deinit();
        try std.testing.expect(response.isOk());
    }

    // Test 404 Not Found
    {
        var response = HttpResponse{
            .allocator = allocator,
            .status_code = 404,
            .body = try allocator.dupe(u8, "not found"),
            .content_type = null,
        };
        defer response.deinit();
        try std.testing.expect(!response.isOk());
    }

    // Test 500 Internal Server Error
    {
        var response = HttpResponse{
            .allocator = allocator,
            .status_code = 500,
            .body = try allocator.dupe(u8, "error"),
            .content_type = null,
        };
        defer response.deinit();
        try std.testing.expect(!response.isOk());
    }
}

// =============================================================================
// Integration tests - these require the WPT server to be running
// They are skipped in normal test runs and can be run manually with:
//   WPT_SERVER_TEST=1 zig test tests/wpt_runner/wpt_server.zig
// =============================================================================

fn isIntegrationTestEnabled() bool {
    // Check environment variable to enable integration tests
    return std.posix.getenv("WPT_SERVER_TEST") != null;
}

test "WptServer integration - start/stop server" {
    if (!isIntegrationTestEnabled()) {
        std.debug.print("Skipping integration test (set WPT_SERVER_TEST=1 to run)\n", .{});
        return;
    }

    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    // Start the server
    try server.start();
    defer server.stop();

    try std.testing.expect(server.running);

    // Verify we can fetch a resource
    const content = try server.fetch(allocator, "/resources/testharness.js");
    defer allocator.free(content);

    // testharness.js should contain specific content
    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "function") != null);
}

test "WptServer integration - fetch test file with URL rewrites" {
    if (!isIntegrationTestEnabled()) {
        std.debug.print("Skipping integration test (set WPT_SERVER_TEST=1 to run)\n", .{});
        return;
    }

    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    try server.start();
    defer server.stop();

    // Fetch WebIDLParser.js - this should be rewritten to webidl2.js by the server
    const content = try server.fetch(allocator, "/resources/WebIDLParser.js");
    defer allocator.free(content);

    try std.testing.expect(content.len > 0);
}

test "WptServer integration - fetch .any.html variant" {
    if (!isIntegrationTestEnabled()) {
        std.debug.print("Skipping integration test (set WPT_SERVER_TEST=1 to run)\n", .{});
        return;
    }

    const allocator = std.testing.allocator;

    const server = try WptServer.init(allocator, "tests/wpt");
    defer server.deinit();

    try server.start();
    defer server.stop();

    // .any.js files can be accessed as .any.html via the server
    // The server generates the HTML wrapper
    var response = try server.fetchWithHeaders(allocator, "/url/url-constructor.any.html");
    defer response.deinit();

    try std.testing.expect(response.isOk());
    try std.testing.expect(response.body.len > 0);

    // The generated HTML should contain script tags for testharness
    try std.testing.expect(std.mem.indexOf(u8, response.body, "testharness") != null);
}
