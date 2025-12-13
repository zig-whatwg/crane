//! WPT HTTP Server
//!
//! HTTP server for serving Web Platform Tests. Implements the necessary
//! functionality to serve WPT test files and generate virtual test variants.
//!
//! ## Features
//!
//! - Static file serving from WPT directory
//! - MIME type detection based on file extension
//! - Virtual file generation for test variants:
//!   - .any.js → .any.html, .any.worker.html, .any.serviceworker.html
//!   - .window.js → .window.html
//! - /resources/testharness.js and /resources/testharnessreport.js
//! - CORS headers for cross-origin testing
//! - Query string handling
//!
//! ## Usage
//!
//! ```zig
//! var server = try HttpServer.init(allocator, .{
//!     .port = 8000,
//!     .wpt_root = "tests/wpt",
//! });
//! defer server.deinit();
//!
//! try server.start();
//! // Server runs until stop() is called
//! server.stop();
//! ```
//!
//! ## Specification References
//!
//! - WPT Server: https://web-platform-tests.org/running-tests/from-local-system.html

const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;

/// HTTP Server configuration
pub const ServerConfig = struct {
    /// Port to listen on (default: 8000)
    port: u16 = 8000,
    /// Secondary port for cross-origin tests (default: 8001)
    port2: u16 = 8001,
    /// HTTPS port (default: 8443)
    https_port: u16 = 8443,
    /// HTTPS port 2 (default: 8444)
    https_port2: u16 = 8444,
    /// Host to bind to (default: 127.0.0.1)
    host: []const u8 = "127.0.0.1",
    /// WPT root directory
    wpt_root: []const u8 = "tests/wpt",
    /// Resources directory (for testharness.js, etc.)
    resources_dir: ?[]const u8 = null,
    /// Enable verbose logging
    verbose: bool = false,
};

/// HTTP request parsed from client
pub const HttpRequest = struct {
    method: []const u8,
    path: []const u8,
    query: ?[]const u8,
    headers: std.StringHashMap([]const u8),
    allocator: Allocator,

    pub fn deinit(self: *HttpRequest) void {
        self.headers.deinit();
    }
};

/// HTTP response to send to client
pub const HttpResponse = struct {
    status_code: u16,
    status_text: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator) HttpResponse {
        return HttpResponse{
            .status_code = 200,
            .status_text = "OK",
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = "",
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HttpResponse) void {
        self.headers.deinit();
        if (self.body.len > 0) {
            self.allocator.free(self.body);
        }
    }

    pub fn setHeader(self: *HttpResponse, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }

    pub fn serialize(self: *HttpResponse, allocator: Allocator) ![]u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(allocator);

        // Status line
        try result.appendSlice(allocator, "HTTP/1.1 ");
        var status_buf: [8]u8 = undefined;
        const status_str = std.fmt.bufPrint(&status_buf, "{d}", .{self.status_code}) catch "500";
        try result.appendSlice(allocator, status_str);
        try result.append(allocator, ' ');
        try result.appendSlice(allocator, self.status_text);
        try result.appendSlice(allocator, "\r\n");

        // Headers
        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            try result.appendSlice(allocator, entry.key_ptr.*);
            try result.appendSlice(allocator, ": ");
            try result.appendSlice(allocator, entry.value_ptr.*);
            try result.appendSlice(allocator, "\r\n");
        }

        // Content-Length if not set
        if (!self.headers.contains("Content-Length")) {
            try result.appendSlice(allocator, "Content-Length: ");
            var len_buf: [16]u8 = undefined;
            const len_str = std.fmt.bufPrint(&len_buf, "{d}", .{self.body.len}) catch "0";
            try result.appendSlice(allocator, len_str);
            try result.appendSlice(allocator, "\r\n");
        }

        // End of headers
        try result.appendSlice(allocator, "\r\n");

        // Body
        try result.appendSlice(allocator, self.body);

        return result.toOwnedSlice(allocator);
    }
};

/// HTTP Server for serving WPT tests
pub const HttpServer = struct {
    allocator: Allocator,
    config: ServerConfig,
    server: ?net.Server,
    running: std.atomic.Value(bool),
    thread: ?std.Thread,

    const Self = @This();

    /// Initialize the HTTP server
    pub fn init(allocator: Allocator, config: ServerConfig) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .allocator = allocator,
            .config = config,
            .server = null,
            .running = std.atomic.Value(bool).init(false),
            .thread = null,
        };
        return self;
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *Self) void {
        self.stop();
        self.allocator.destroy(self);
    }

    /// Start the server in a background thread
    pub fn start(self: *Self) !void {
        if (self.running.load(.acquire)) {
            return error.AlreadyRunning;
        }

        // Bind server
        const address = net.Address.parseIp4(self.config.host, self.config.port) catch {
            return error.InvalidAddress;
        };

        self.server = net.Address.listen(address, .{
            .reuse_address = true,
        }) catch |err| {
            std.debug.print("Failed to bind to {s}:{d}: {}\n", .{ self.config.host, self.config.port, err });
            return error.BindFailed;
        };

        self.running.store(true, .release);

        // Start accept thread
        self.thread = std.Thread.spawn(.{}, acceptLoop, .{self}) catch |err| {
            self.running.store(false, .release);
            if (self.server) |*s| {
                s.deinit();
                self.server = null;
            }
            return err;
        };

        if (self.config.verbose) {
            std.debug.print("WPT HTTP Server listening on http://{s}:{d}\n", .{ self.config.host, self.config.port });
        }
    }

    /// Stop the server
    pub fn stop(self: *Self) void {
        if (!self.running.load(.acquire)) return;

        self.running.store(false, .release);

        // Close server socket to unblock accept
        if (self.server) |*s| {
            s.deinit();
            self.server = null;
        }

        // Wait for thread
        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
    }

    /// Get the server URL
    pub fn getUrl(self: *Self) ![]u8 {
        var buf: [256]u8 = undefined;
        const url = try std.fmt.bufPrint(&buf, "http://{s}:{d}", .{ self.config.host, self.config.port });
        return try self.allocator.dupe(u8, url);
    }

    /// Accept loop running in background thread
    fn acceptLoop(self: *Self) void {
        while (self.running.load(.acquire)) {
            const server = self.server orelse return;

            // Accept connection
            const conn = server.accept() catch |err| {
                if (!self.running.load(.acquire)) return; // Expected on shutdown
                std.debug.print("Accept error: {}\n", .{err});
                continue;
            };

            // Handle connection (synchronously for simplicity)
            self.handleConnection(conn) catch |err| {
                std.debug.print("Connection error: {}\n", .{err});
            };
        }
    }

    /// Handle a single connection
    fn handleConnection(self: *Self, conn: net.Server.Connection) !void {
        defer conn.stream.close();

        // Read request
        var buf: [8192]u8 = undefined;
        const bytes_read = conn.stream.read(&buf) catch |err| {
            std.debug.print("Read error: {}\n", .{err});
            return;
        };

        if (bytes_read == 0) return;

        // Parse request
        var request = try self.parseRequest(buf[0..bytes_read]);
        defer request.deinit();

        // Handle request
        var response = try self.handleRequest(&request);
        defer response.deinit();

        // Send response
        const response_bytes = try response.serialize(self.allocator);
        defer self.allocator.free(response_bytes);

        _ = conn.stream.write(response_bytes) catch {};
    }

    /// Parse HTTP request
    fn parseRequest(self: *Self, data: []const u8) !HttpRequest {
        var request = HttpRequest{
            .method = "",
            .path = "",
            .query = null,
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .allocator = self.allocator,
        };
        errdefer request.headers.deinit();

        // Find end of request line
        const request_line_end = std.mem.indexOf(u8, data, "\r\n") orelse return error.InvalidRequest;
        const request_line = data[0..request_line_end];

        // Parse request line: METHOD PATH HTTP/VERSION
        var parts = std.mem.splitScalar(u8, request_line, ' ');

        request.method = parts.next() orelse return error.InvalidRequest;

        const full_path = parts.next() orelse return error.InvalidRequest;

        // Split path and query string
        if (std.mem.indexOf(u8, full_path, "?")) |query_start| {
            request.path = full_path[0..query_start];
            request.query = full_path[query_start + 1 ..];
        } else {
            request.path = full_path;
        }

        // Parse headers (simplified - just look for Host)
        var line_start = request_line_end + 2;
        while (line_start < data.len) {
            const line_end = std.mem.indexOfPos(u8, data, line_start, "\r\n") orelse break;
            if (line_end == line_start) break; // Empty line = end of headers

            const line = data[line_start..line_end];
            if (std.mem.indexOf(u8, line, ": ")) |colon_pos| {
                const name = line[0..colon_pos];
                const value = line[colon_pos + 2 ..];
                try request.headers.put(name, value);
            }

            line_start = line_end + 2;
        }

        return request;
    }

    /// Handle an HTTP request
    fn handleRequest(self: *Self, request: *HttpRequest) !HttpResponse {
        var response = HttpResponse.init(self.allocator);
        errdefer response.deinit();

        // Add CORS headers for WPT
        try response.setHeader("Access-Control-Allow-Origin", "*");
        try response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        try response.setHeader("Access-Control-Allow-Headers", "*");

        // Handle OPTIONS (CORS preflight)
        if (std.mem.eql(u8, request.method, "OPTIONS")) {
            response.status_code = 204;
            response.status_text = "No Content";
            return response;
        }

        // Handle GET requests
        if (!std.mem.eql(u8, request.method, "GET")) {
            response.status_code = 405;
            response.status_text = "Method Not Allowed";
            return response;
        }

        // Normalize path
        const path = if (std.mem.eql(u8, request.path, "/")) "/index.html" else request.path;

        // Check for virtual test file (.any.html, .window.html)
        if (try self.handleVirtualFile(path, &response)) {
            return response;
        }

        // Check for testharness resources
        if (try self.handleResources(path, &response)) {
            return response;
        }

        // Check for .sub.* files (WPT server-side substitution)
        if (try self.handleSubstitutionFile(path, &response)) {
            return response;
        }

        // Try to serve static file
        if (try self.serveStaticFile(path, &response)) {
            return response;
        }

        // 404 Not Found
        response.status_code = 404;
        response.status_text = "Not Found";
        try response.setHeader("Content-Type", "text/plain");
        response.body = try self.allocator.dupe(u8, "Not Found");

        return response;
    }

    /// Handle virtual test files (.any.html, .window.html)
    fn handleVirtualFile(self: *Self, path: []const u8, response: *HttpResponse) !bool {
        // Check for .any.html → generate from .any.js
        if (std.mem.endsWith(u8, path, ".any.html")) {
            const js_path = try std.mem.concat(self.allocator, u8, &.{
                path[0 .. path.len - 10], // Remove .any.html
                ".any.js",
            });
            defer self.allocator.free(js_path);

            return try self.generateTestHtml(js_path[1..], "any", response);
        }

        // Check for .any.worker.html → generate from .any.js for worker context
        if (std.mem.endsWith(u8, path, ".any.worker.html")) {
            const js_path = try std.mem.concat(self.allocator, u8, &.{
                path[0 .. path.len - 16], // Remove .any.worker.html
                ".any.js",
            });
            defer self.allocator.free(js_path);

            return try self.generateTestHtml(js_path[1..], "worker", response);
        }

        // Check for .any.worker.js → generate worker wrapper script
        // This is the script that gets executed in the Worker context
        // It imports testharness.js first, then the actual test file
        if (std.mem.endsWith(u8, path, ".any.worker.js")) {
            const base_path = path[0 .. path.len - 14]; // Remove ".any.worker.js"
            const original_js = try std.mem.concat(self.allocator, u8, &.{
                base_path,
                ".any.js",
            });
            defer self.allocator.free(original_js);

            return try self.generateWorkerWrapper(original_js, response);
        }

        // Check for .window.html → generate from .window.js
        if (std.mem.endsWith(u8, path, ".window.html")) {
            const js_path = try std.mem.concat(self.allocator, u8, &.{
                path[0 .. path.len - 12], // Remove .window.html
                ".window.js",
            });
            defer self.allocator.free(js_path);

            return try self.generateTestHtml(js_path[1..], "window", response);
        }

        return false;
    }

    /// Generate test HTML wrapper
    fn generateTestHtml(self: *Self, js_relative_path: []const u8, test_type: []const u8, response: *HttpResponse) !bool {
        // Check if the JS file exists
        const full_path = try std.fs.path.join(self.allocator, &.{ self.config.wpt_root, js_relative_path });
        defer self.allocator.free(full_path);

        std.fs.cwd().access(full_path, .{}) catch return false;

        // Generate HTML wrapper
        const js_url = try std.mem.concat(self.allocator, u8, &.{ "/", js_relative_path });
        defer self.allocator.free(js_url);

        var html = std.ArrayListUnmanaged(u8){};
        errdefer html.deinit(self.allocator);

        try html.appendSlice(self.allocator, "<!DOCTYPE html>\n<html>\n<head>\n");
        try html.appendSlice(self.allocator, "<meta charset=\"utf-8\">\n");
        try html.appendSlice(self.allocator, "<title>");
        try html.appendSlice(self.allocator, js_relative_path);
        try html.appendSlice(self.allocator, "</title>\n");

        // Include testharness.js
        try html.appendSlice(self.allocator, "<script src=\"/resources/testharness.js\"></script>\n");
        try html.appendSlice(self.allocator, "<script src=\"/resources/testharnessreport.js\"></script>\n");

        if (std.mem.eql(u8, test_type, "worker")) {
            // Worker test - use fetch_tests_from_worker with the worker wrapper script
            // The wrapper script (e.g., test.any.worker.js) loads testharness.js first,
            // then the actual test file (test.any.js)
            const worker_js_url = try std.mem.concat(self.allocator, u8, &.{
                js_url[0 .. js_url.len - 3], // Remove ".js"
                ".worker.js",
            });
            defer self.allocator.free(worker_js_url);

            try html.appendSlice(self.allocator, "<script>\nfetch_tests_from_worker(new Worker(\"");
            try html.appendSlice(self.allocator, worker_js_url);
            try html.appendSlice(self.allocator, "\"));\n</script>\n");
        } else {
            // Window or any test - include script directly
            try html.appendSlice(self.allocator, "<script src=\"");
            try html.appendSlice(self.allocator, js_url);
            try html.appendSlice(self.allocator, "\"></script>\n");
        }

        try html.appendSlice(self.allocator, "</head>\n<body>\n</body>\n</html>");

        response.status_code = 200;
        response.status_text = "OK";
        try response.setHeader("Content-Type", "text/html;charset=utf-8");
        response.body = try html.toOwnedSlice(self.allocator);

        return true;
    }

    /// Generate worker wrapper script for .any.worker.js requests
    /// This script loads testharness.js first, then the actual test file
    /// Per WPT: Workers need a wrapper that imports testharness.js before the test
    fn generateWorkerWrapper(self: *Self, original_js_path: []const u8, response: *HttpResponse) !bool {
        // Check if the original JS file exists
        // The path is like "/console/test.any.js" - strip leading slash for file access
        const file_path = if (original_js_path.len > 0 and original_js_path[0] == '/')
            original_js_path[1..]
        else
            original_js_path;

        const full_path = try std.fs.path.join(self.allocator, &.{ self.config.wpt_root, file_path });
        defer self.allocator.free(full_path);

        std.fs.cwd().access(full_path, .{}) catch return false;

        // Generate worker wrapper script
        var script = std.ArrayListUnmanaged(u8){};
        errdefer script.deinit(self.allocator);

        // Set up GLOBAL object for WPT worker context
        try script.appendSlice(self.allocator,
            \\self.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            \\
        );

        // Import testharness.js first
        try script.appendSlice(self.allocator, "importScripts(\"/resources/testharness.js\");\n");

        // Import the actual test file
        try script.appendSlice(self.allocator, "importScripts(\"");
        try script.appendSlice(self.allocator, original_js_path);
        try script.appendSlice(self.allocator, "\");\n");

        // Call done() to signal test completion
        // Per testharness.js: in worker context, done() is called after all tests are defined
        try script.appendSlice(self.allocator, "done();\n");

        response.status_code = 200;
        response.status_text = "OK";
        try response.setHeader("Content-Type", "application/javascript;charset=utf-8");
        response.body = try script.toOwnedSlice(self.allocator);

        return true;
    }

    /// Handle testharness resource files
    fn handleResources(self: *Self, path: []const u8, response: *HttpResponse) !bool {
        if (!std.mem.startsWith(u8, path, "/resources/")) return false;

        const resource_name = path[11..]; // Remove "/resources/"

        // Check for testharness.js
        if (std.mem.eql(u8, resource_name, "testharness.js")) {
            // Look in WPT resources or runner resources
            const wpt_path = try std.fs.path.join(self.allocator, &.{ self.config.wpt_root, "resources", "testharness.js" });
            defer self.allocator.free(wpt_path);

            if (try self.serveFile(wpt_path, "application/javascript;charset=utf-8", response)) {
                return true;
            }

            // Fallback to runner resources
            if (self.config.resources_dir) |res_dir| {
                const runner_path = try std.fs.path.join(self.allocator, &.{ res_dir, "testharness.js" });
                defer self.allocator.free(runner_path);

                if (try self.serveFile(runner_path, "application/javascript;charset=utf-8", response)) {
                    return true;
                }
            }
        }

        // Check for testharnessreport.js
        if (std.mem.eql(u8, resource_name, "testharnessreport.js")) {
            // First try WPT resources
            const wpt_path = try std.fs.path.join(self.allocator, &.{ self.config.wpt_root, "resources", "testharnessreport.js" });
            defer self.allocator.free(wpt_path);

            if (try self.serveFile(wpt_path, "application/javascript;charset=utf-8", response)) {
                return true;
            }

            // Fallback to runner resources
            if (self.config.resources_dir) |res_dir| {
                const runner_path = try std.fs.path.join(self.allocator, &.{ res_dir, "testharnessreport.js" });
                defer self.allocator.free(runner_path);

                if (try self.serveFile(runner_path, "application/javascript;charset=utf-8", response)) {
                    return true;
                }
            }

            // Generate minimal testharnessreport.js if not found
            const minimal_report =
                \\// Minimal testharnessreport.js for WPT runner
                \\(function() {
                \\  function dump(test, status) {
                \\    var msg = test.name + ": " + status;
                \\    if (test.message) msg += " - " + test.message;
                \\    console.log(msg);
                \\  }
                \\  add_result_callback(function(test) {
                \\    dump(test, test.status === 0 ? "PASS" : test.status === 1 ? "FAIL" : "TIMEOUT");
                \\  });
                \\  add_completion_callback(function(tests, status) {
                \\    console.log("WPT_COMPLETE:" + JSON.stringify({tests: tests.length, status: status.status}));
                \\  });
                \\})();
            ;

            response.status_code = 200;
            response.status_text = "OK";
            try response.setHeader("Content-Type", "application/javascript;charset=utf-8");
            response.body = try self.allocator.dupe(u8, minimal_report);
            return true;
        }

        // Try to serve other resources from WPT directory
        const full_path = try std.fs.path.join(self.allocator, &.{ self.config.wpt_root, "resources", resource_name });
        defer self.allocator.free(full_path);

        return try self.serveFile(full_path, getMimeType(resource_name), response);
    }

    /// Handle .sub.* files (WPT server-side substitution)
    /// Files like .sub.js, .sub.html use {{var}} syntax for dynamic content
    fn handleSubstitutionFile(self: *Self, path: []const u8, response: *HttpResponse) !bool {
        // Check if this is a .sub.* file
        if (std.mem.indexOf(u8, path, ".sub.")) |_| {
            // This is a substitution file - serve with variable replacement
            const relative_path = if (path[0] == '/') path[1..] else path;
            const full_path = try std.fs.path.join(self.allocator, &.{ self.config.wpt_root, relative_path });
            defer self.allocator.free(full_path);

            // Read the file
            const file = std.fs.cwd().openFile(full_path, .{}) catch return false;
            defer file.close();

            const stat = try file.stat();
            const content = try self.allocator.alloc(u8, stat.size);
            defer self.allocator.free(content);

            const bytes_read = try file.readAll(content);
            if (bytes_read != stat.size) {
                return false;
            }

            // Perform substitutions
            const substituted = try self.performSubstitutions(content);

            response.status_code = 200;
            response.status_text = "OK";
            try response.setHeader("Content-Type", getMimeType(path));
            response.body = substituted;

            return true;
        }
        return false;
    }

    /// Perform WPT server-side substitutions on content
    /// Replaces {{var}} patterns with actual values
    fn performSubstitutions(self: *Self, content: []const u8) ![]u8 {
        var result: std.ArrayListUnmanaged(u8) = .{};
        errdefer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < content.len) {
            // Look for {{
            if (i + 1 < content.len and content[i] == '{' and content[i + 1] == '{') {
                // Find closing }}
                const var_start = i + 2;
                var var_end = var_start;
                var depth: usize = 1;
                while (var_end < content.len) {
                    if (var_end + 1 < content.len and content[var_end] == '}' and content[var_end + 1] == '}') {
                        depth -= 1;
                        if (depth == 0) break;
                    } else if (var_end + 1 < content.len and content[var_end] == '{' and content[var_end + 1] == '{') {
                        depth += 1;
                        var_end += 1;
                    }
                    var_end += 1;
                }

                if (depth == 0) {
                    // Found a complete {{var}}
                    const var_name = content[var_start..var_end];
                    const value = self.getSubstitutionValue(var_name);
                    try result.appendSlice(self.allocator, value);
                    i = var_end + 2; // Skip past }}
                } else {
                    // No closing }}, keep the {{
                    try result.append(self.allocator, content[i]);
                    i += 1;
                }
            } else {
                try result.append(self.allocator, content[i]);
                i += 1;
            }
        }

        return try result.toOwnedSlice(self.allocator);
    }

    /// Get the value for a WPT substitution variable
    fn getSubstitutionValue(self: *Self, var_name: []const u8) []const u8 {
        // Handle common WPT substitution variables
        // See: https://web-platform-tests.org/writing-tests/server-pipes.html

        // {{host}} - the server hostname
        if (std.mem.eql(u8, var_name, "host")) {
            return self.config.host;
        }

        // {{ports[http][0]}} - primary HTTP port
        if (std.mem.eql(u8, var_name, "ports[http][0]")) {
            return switch (self.config.port) {
                8000 => "8000",
                8080 => "8080",
                80 => "80",
                else => "8000",
            };
        }

        // {{ports[http][1]}} - secondary HTTP port
        if (std.mem.eql(u8, var_name, "ports[http][1]")) {
            return switch (self.config.port2) {
                8001 => "8001",
                8081 => "8081",
                else => "8001",
            };
        }

        // {{ports[https][0]}} - primary HTTPS port
        if (std.mem.eql(u8, var_name, "ports[https][0]")) {
            return switch (self.config.https_port) {
                8443 => "8443",
                443 => "443",
                else => "8443",
            };
        }

        // {{ports[https][1]}} - secondary HTTPS port
        if (std.mem.eql(u8, var_name, "ports[https][1]")) {
            return switch (self.config.https_port2) {
                8444 => "8444",
                else => "8444",
            };
        }

        // {{domains[www2]}} - alternate domain
        if (std.mem.eql(u8, var_name, "domains[www2]")) {
            return "www2.localhost";
        }

        // {{hosts[alt][]}} - alternate host (not same site)
        if (std.mem.eql(u8, var_name, "hosts[alt][]")) {
            return "127.0.0.1";
        }

        // {{hosts[alt][www2]}} - alternate host www2
        if (std.mem.eql(u8, var_name, "hosts[alt][www2]")) {
            return "www2.127.0.0.1";
        }

        // {{location[server]}} - full server URL
        if (std.mem.eql(u8, var_name, "location[server]")) {
            return "http://localhost:8000";
        }

        // Unknown variable - return empty string to avoid breaking
        // In a full implementation, we'd log a warning
        return "";
    }

    /// Serve a static file
    fn serveStaticFile(self: *Self, path: []const u8, response: *HttpResponse) !bool {
        // Build full path
        const relative_path = if (path[0] == '/') path[1..] else path;
        const full_path = try std.fs.path.join(self.allocator, &.{ self.config.wpt_root, relative_path });
        defer self.allocator.free(full_path);

        return try self.serveFile(full_path, getMimeType(path), response);
    }

    /// Serve a specific file
    fn serveFile(self: *Self, path: []const u8, content_type: []const u8, response: *HttpResponse) !bool {
        const file = std.fs.cwd().openFile(path, .{}) catch return false;
        defer file.close();

        const stat = try file.stat();
        const content = try self.allocator.alloc(u8, stat.size);
        errdefer self.allocator.free(content);

        const bytes_read = try file.readAll(content);
        if (bytes_read != stat.size) {
            self.allocator.free(content);
            return false;
        }

        response.status_code = 200;
        response.status_text = "OK";
        try response.setHeader("Content-Type", content_type);
        response.body = content;

        return true;
    }
};

/// Get MIME type from file extension
fn getMimeType(path: []const u8) []const u8 {
    const ext = blk: {
        const last_dot = std.mem.lastIndexOf(u8, path, ".");
        if (last_dot) |pos| {
            break :blk path[pos..];
        }
        break :blk "";
    };

    if (std.mem.eql(u8, ext, ".html") or std.mem.eql(u8, ext, ".htm")) {
        return "text/html;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".js") or std.mem.eql(u8, ext, ".mjs")) {
        return "application/javascript;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".css")) {
        return "text/css;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".json")) {
        return "application/json;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".xml")) {
        return "application/xml;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".txt")) {
        return "text/plain;charset=utf-8";
    } else if (std.mem.eql(u8, ext, ".png")) {
        return "image/png";
    } else if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg")) {
        return "image/jpeg";
    } else if (std.mem.eql(u8, ext, ".gif")) {
        return "image/gif";
    } else if (std.mem.eql(u8, ext, ".svg")) {
        return "image/svg+xml";
    } else if (std.mem.eql(u8, ext, ".woff")) {
        return "font/woff";
    } else if (std.mem.eql(u8, ext, ".woff2")) {
        return "font/woff2";
    } else {
        return "application/octet-stream";
    }
}

// =============================================================================
// Tests
// =============================================================================

test "HttpServer - getMimeType" {
    try std.testing.expectEqualStrings("text/html;charset=utf-8", getMimeType("page.html"));
    try std.testing.expectEqualStrings("application/javascript;charset=utf-8", getMimeType("script.js"));
    try std.testing.expectEqualStrings("text/css;charset=utf-8", getMimeType("style.css"));
    try std.testing.expectEqualStrings("application/json;charset=utf-8", getMimeType("data.json"));
    try std.testing.expectEqualStrings("image/png", getMimeType("image.png"));
    try std.testing.expectEqualStrings("application/octet-stream", getMimeType("unknown.xyz"));
}

test "HttpResponse - serialize" {
    const allocator = std.testing.allocator;

    var response = HttpResponse.init(allocator);
    defer response.deinit();

    response.status_code = 200;
    response.status_text = "OK";
    try response.setHeader("Content-Type", "text/html");
    response.body = try allocator.dupe(u8, "<html></html>");

    const serialized = try response.serialize(allocator);
    defer allocator.free(serialized);

    try std.testing.expect(std.mem.startsWith(u8, serialized, "HTTP/1.1 200 OK\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, serialized, "Content-Type: text/html") != null);
    try std.testing.expect(std.mem.endsWith(u8, serialized, "<html></html>"));
}

test "HttpServer - performSubstitutions" {
    const allocator = std.testing.allocator;

    var server = try HttpServer.init(allocator, .{
        .port = 8000,
        .host = "localhost",
    });
    defer server.deinit();

    // Test simple variable substitution
    {
        const input = "var HOST = '{{host}}';";
        const result = try server.performSubstitutions(input);
        defer allocator.free(result);
        try std.testing.expectEqualStrings("var HOST = 'localhost';", result);
    }

    // Test port substitution
    {
        const input = "var PORT = '{{ports[http][0]}}';";
        const result = try server.performSubstitutions(input);
        defer allocator.free(result);
        try std.testing.expectEqualStrings("var PORT = '8000';", result);
    }

    // Test multiple substitutions
    {
        const input = "{{host}}:{{ports[http][0]}}";
        const result = try server.performSubstitutions(input);
        defer allocator.free(result);
        try std.testing.expectEqualStrings("localhost:8000", result);
    }

    // Test no substitutions
    {
        const input = "plain text with no vars";
        const result = try server.performSubstitutions(input);
        defer allocator.free(result);
        try std.testing.expectEqualStrings("plain text with no vars", result);
    }
}

test "HttpServer - getSubstitutionValue" {
    const allocator = std.testing.allocator;

    var server = try HttpServer.init(allocator, .{
        .port = 8000,
        .port2 = 8001,
        .https_port = 8443,
        .host = "localhost",
    });
    defer server.deinit();

    try std.testing.expectEqualStrings("localhost", server.getSubstitutionValue("host"));
    try std.testing.expectEqualStrings("8000", server.getSubstitutionValue("ports[http][0]"));
    try std.testing.expectEqualStrings("8001", server.getSubstitutionValue("ports[http][1]"));
    try std.testing.expectEqualStrings("8443", server.getSubstitutionValue("ports[https][0]"));
    try std.testing.expectEqualStrings("www2.localhost", server.getSubstitutionValue("domains[www2]"));
    try std.testing.expectEqualStrings("", server.getSubstitutionValue("unknown_var"));
}
