//! WebDriver Session Management
//!
//! Each WebDriver session corresponds to a browser instance with its own
//! V8 context. Sessions are isolated from each other.

const std = @import("std");
const Allocator = std.mem.Allocator;
const protocol = @import("protocol.zig");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const Context = browser_mod.Context;
const v8 = @import("v8");

/// WebDriver Session
///
/// Manages a browser instance for WebDriver commands.
pub const Session = struct {
    allocator: Allocator,
    id: []const u8,
    browser: *Browser,
    timeouts: protocol.Timeouts,

    /// Create a new session with a fresh browser instance
    pub fn init(allocator: Allocator) !*Session {
        const session = try allocator.create(Session);
        errdefer allocator.destroy(session);

        // Generate session ID
        const id = try protocol.generateSessionId(allocator);
        errdefer allocator.free(id);

        // Create browser instance
        const browser = Browser.init(allocator, .{
            .persist_storage = false, // Don't persist storage for test sessions
            .snapshot_path = "", // Disable snapshot for faster startup in tests
        }) catch |err| {
            std.log.err("Failed to create browser: {}", .{err});
            return error.SessionNotCreated;
        };
        errdefer browser.deinit();

        session.* = .{
            .allocator = allocator,
            .id = id,
            .browser = browser,
            .timeouts = .{
                .script = protocol.Timeouts.default_script,
                .pageLoad = protocol.Timeouts.default_page_load,
                .implicit = protocol.Timeouts.default_implicit,
            },
        };

        return session;
    }

    /// Clean up session resources
    pub fn deinit(self: *Session) void {
        self.browser.deinit();
        self.allocator.free(self.id);
        self.allocator.destroy(self);
    }

    /// Navigate to a URL
    pub fn navigate(self: *Session, url: []const u8) !void {
        std.log.info("Session {s}: navigating to {s}", .{ self.id, url });

        // Navigate using browser
        try self.browser.navigate(url, .window);

        // Run event loop until page load completes or timeout
        const timeout = self.timeouts.pageLoad orelse protocol.Timeouts.default_page_load;
        try self.runUntilPageLoad(timeout);
    }

    /// Get current URL
    pub fn getUrl(self: *Session) ![]const u8 {
        const ctx = self.browser.current_context orelse return error.NoSuchWindow;
        return ctx.url;
    }

    /// Get page title via JavaScript
    pub fn getTitle(self: *Session, allocator: Allocator) ![]const u8 {
        return try self.executeScriptReturningString(allocator, "document.title || ''");
    }

    /// Execute synchronous JavaScript and return result as JSON string
    pub fn executeScript(self: *Session, allocator: Allocator, script: []const u8, args: ?std.json.Value) !?[]const u8 {
        _ = args; // TODO: handle args

        // Wrap script to capture return value as JSON
        const wrapped = try std.fmt.allocPrint(allocator,
            \\(function() {{
            \\    try {{
            \\        var __result = (function() {{ {s} }})();
            \\        return JSON.stringify(__result);
            \\    }} catch(e) {{
            \\        return JSON.stringify({{__error: e.message}});
            \\    }}
            \\}})()
        , .{script});
        defer allocator.free(wrapped);

        return try self.executeScriptReturningString(allocator, wrapped);
    }

    /// Execute asynchronous JavaScript
    ///
    /// This is the critical method for testharness.js integration.
    /// The script receives a callback function as the last argument.
    /// Execution blocks until the callback is invoked or timeout occurs.
    pub fn executeAsyncScript(self: *Session, allocator: Allocator, script: []const u8, args: ?std.json.Value) !?[]const u8 {
        _ = args; // TODO: handle args

        const ctx = self.browser.current_context orelse return error.NoSuchWindow;

        // Initialize completion flags
        const init_script =
            \\window.__webdriver_async_complete = false;
            \\window.__webdriver_async_result = null;
        ;
        _ = ctx.evaluateScript(init_script) catch {};

        // Wrap script with async callback mechanism
        // The callback is provided as the last argument to the script
        const wrapped = try std.fmt.allocPrint(allocator,
            \\(function() {{
            \\    var __wd_callback = function(result) {{
            \\        window.__webdriver_async_result = JSON.stringify(result);
            \\        window.__webdriver_async_complete = true;
            \\    }};
            \\    var __wd_args = [];
            \\    __wd_args.push(__wd_callback);
            \\    try {{
            \\        (function() {{ {s} }}).apply(null, __wd_args);
            \\    }} catch(e) {{
            \\        __wd_callback({{__error: e.message}});
            \\    }}
            \\}})()
        , .{script});
        defer allocator.free(wrapped);

        // Execute the script (non-blocking, sets up callbacks)
        _ = ctx.evaluateScript(wrapped) catch |err| {
            std.log.err("Async script execution error: {}", .{err});
            return error.JavascriptError;
        };

        // Run event loop until completion or timeout
        const timeout = self.timeouts.script orelse protocol.Timeouts.default_script;
        try self.runUntilAsyncComplete(timeout);

        // Retrieve result
        return try self.executeScriptReturningString(allocator, "window.__webdriver_async_result");
    }

    /// Execute script and return result as string
    fn executeScriptReturningString(self: *Session, allocator: Allocator, script: []const u8) ![]const u8 {
        const ctx = self.browser.current_context orelse return error.NoSuchWindow;

        const result = ctx.evaluateScript(script) catch |err| {
            std.log.err("Script execution error: {}", .{err});
            return error.JavascriptError;
        };

        if (result) |val| {
            // Convert V8 Value to string using V8 FFI
            const v8_ctx = ctx.v8_context orelse return error.NoSuchWindow;
            const str = v8.ffi.v8_Value_ToString(val, v8_ctx) orelse {
                return try allocator.dupe(u8, "null");
            };

            // Get UTF-8 length and allocate buffer
            const len = v8.ffi.v8_String_Utf8Length(str);
            if (len <= 0) return try allocator.dupe(u8, "");

            const buffer = try allocator.alloc(u8, @intCast(len));
            errdefer allocator.free(buffer);

            // Write UTF-8 bytes to buffer
            const written = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
            return buffer[0..@intCast(written)];
        }

        return try allocator.dupe(u8, "null");
    }

    /// Run event loop until page load completes
    fn runUntilPageLoad(self: *Session, timeout_ms: u64) !void {
        const start = std.time.milliTimestamp();
        const deadline = start + @as(i64, @intCast(timeout_ms));

        while (std.time.milliTimestamp() < deadline) {
            // Process event loop
            if (self.browser.event_loop) |event_loop| {
                _ = event_loop.eventLoop().runOnce();
            }

            // Check if page load complete (document.readyState === 'complete')
            if (self.isPageLoadComplete()) {
                return;
            }

            // Small yield to prevent CPU spin
            std.Thread.sleep(1 * std.time.ns_per_ms);
        }

        // Timeout is not an error for page load - we continue anyway
        std.log.warn("Page load timeout after {}ms", .{timeout_ms});
    }

    /// Run event loop until async script completes
    fn runUntilAsyncComplete(self: *Session, timeout_ms: u64) !void {
        const start = std.time.milliTimestamp();
        const deadline = start + @as(i64, @intCast(timeout_ms));

        while (std.time.milliTimestamp() < deadline) {
            // Process event loop
            if (self.browser.event_loop) |event_loop| {
                _ = event_loop.eventLoop().runOnce();
            }

            // Check if async complete
            if (self.isAsyncComplete()) {
                return;
            }

            // Small yield
            std.Thread.sleep(1 * std.time.ns_per_ms);
        }

        return error.ScriptTimeout;
    }

    /// Check if page load is complete
    fn isPageLoadComplete(self: *Session) bool {
        const ctx = self.browser.current_context orelse return true;
        const v8_ctx = ctx.v8_context orelse return true;
        const script = "document.readyState === 'complete' ? 'true' : 'false'";
        const result = ctx.evaluateScript(script) catch return false;
        if (result) |val| {
            const str = v8.ffi.v8_Value_ToString(val, v8_ctx) orelse return false;
            const len = v8.ffi.v8_String_Utf8Length(str);
            if (len <= 0) return false;

            var buf: [16]u8 = undefined;
            const written = v8.ffi.v8_String_WriteUtf8(str, &buf, @intCast(@min(len, 16)));
            return std.mem.eql(u8, buf[0..@intCast(written)], "true");
        }
        return false;
    }

    /// Check if async script completed
    fn isAsyncComplete(self: *Session) bool {
        const ctx = self.browser.current_context orelse return true;
        const v8_ctx = ctx.v8_context orelse return true;
        const script = "window.__webdriver_async_complete === true ? 'true' : 'false'";
        const result = ctx.evaluateScript(script) catch return false;
        if (result) |val| {
            const str = v8.ffi.v8_Value_ToString(val, v8_ctx) orelse return false;
            const len = v8.ffi.v8_String_Utf8Length(str);
            if (len <= 0) return false;

            var buf: [16]u8 = undefined;
            const written = v8.ffi.v8_String_WriteUtf8(str, &buf, @intCast(@min(len, 16)));
            return std.mem.eql(u8, buf[0..@intCast(written)], "true");
        }
        return false;
    }
};

/// Session manager - maintains active sessions
pub const SessionManager = struct {
    allocator: Allocator,
    sessions: std.StringHashMap(*Session),

    pub fn init(allocator: Allocator) SessionManager {
        return .{
            .allocator = allocator,
            .sessions = std.StringHashMap(*Session).init(allocator),
        };
    }

    pub fn deinit(self: *SessionManager) void {
        var it = self.sessions.valueIterator();
        while (it.next()) |session| {
            session.*.deinit();
        }
        self.sessions.deinit();
    }

    pub fn createSession(self: *SessionManager) !*Session {
        const session = try Session.init(self.allocator);
        errdefer session.deinit();

        try self.sessions.put(session.id, session);
        return session;
    }

    pub fn getSession(self: *SessionManager, id: []const u8) ?*Session {
        return self.sessions.get(id);
    }

    pub fn deleteSession(self: *SessionManager, id: []const u8) bool {
        if (self.sessions.fetchRemove(id)) |entry| {
            entry.value.deinit();
            return true;
        }
        return false;
    }
};
