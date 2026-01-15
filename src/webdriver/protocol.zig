//! WebDriver Protocol - JSON Wire Protocol Implementation
//!
//! Handles parsing and serialization of WebDriver protocol messages.
//! Based on W3C WebDriver specification.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// WebDriver error codes per W3C spec
pub const ErrorCode = enum {
    element_click_intercepted,
    element_not_interactable,
    insecure_certificate,
    invalid_argument,
    invalid_cookie_domain,
    invalid_element_state,
    invalid_selector,
    invalid_session_id,
    javascript_error,
    move_target_out_of_bounds,
    no_such_alert,
    no_such_cookie,
    no_such_element,
    no_such_frame,
    no_such_window,
    no_such_shadow_root,
    script_timeout,
    session_not_created,
    stale_element_reference,
    detached_shadow_root,
    timeout,
    unable_to_set_cookie,
    unable_to_capture_screen,
    unexpected_alert_open,
    unknown_command,
    unknown_error,
    unknown_method,
    unsupported_operation,

    pub fn httpStatus(self: ErrorCode) std.http.Status {
        return switch (self) {
            .element_click_intercepted => .bad_request,
            .element_not_interactable => .bad_request,
            .insecure_certificate => .bad_request,
            .invalid_argument => .bad_request,
            .invalid_cookie_domain => .bad_request,
            .invalid_element_state => .bad_request,
            .invalid_selector => .bad_request,
            .invalid_session_id => .not_found,
            .javascript_error => .internal_server_error,
            .move_target_out_of_bounds => .internal_server_error,
            .no_such_alert => .not_found,
            .no_such_cookie => .not_found,
            .no_such_element => .not_found,
            .no_such_frame => .not_found,
            .no_such_window => .not_found,
            .no_such_shadow_root => .not_found,
            .script_timeout => .internal_server_error,
            .session_not_created => .internal_server_error,
            .stale_element_reference => .not_found,
            .detached_shadow_root => .not_found,
            .timeout => .internal_server_error,
            .unable_to_set_cookie => .internal_server_error,
            .unable_to_capture_screen => .internal_server_error,
            .unexpected_alert_open => .internal_server_error,
            .unknown_command => .not_found,
            .unknown_error => .internal_server_error,
            .unknown_method => .method_not_allowed,
            .unsupported_operation => .internal_server_error,
        };
    }

    pub fn toString(self: ErrorCode) []const u8 {
        return switch (self) {
            .element_click_intercepted => "element click intercepted",
            .element_not_interactable => "element not interactable",
            .insecure_certificate => "insecure certificate",
            .invalid_argument => "invalid argument",
            .invalid_cookie_domain => "invalid cookie domain",
            .invalid_element_state => "invalid element state",
            .invalid_selector => "invalid selector",
            .invalid_session_id => "invalid session id",
            .javascript_error => "javascript error",
            .move_target_out_of_bounds => "move target out of bounds",
            .no_such_alert => "no such alert",
            .no_such_cookie => "no such cookie",
            .no_such_element => "no such element",
            .no_such_frame => "no such frame",
            .no_such_window => "no such window",
            .no_such_shadow_root => "no such shadow root",
            .script_timeout => "script timeout",
            .session_not_created => "session not created",
            .stale_element_reference => "stale element reference",
            .detached_shadow_root => "detached shadow root",
            .timeout => "timeout",
            .unable_to_set_cookie => "unable to set cookie",
            .unable_to_capture_screen => "unable to capture screen",
            .unexpected_alert_open => "unexpected alert open",
            .unknown_command => "unknown command",
            .unknown_error => "unknown error",
            .unknown_method => "unknown method",
            .unsupported_operation => "unsupported operation",
        };
    }
};

/// WebDriver response wrapper
pub const Response = struct {
    allocator: Allocator,

    /// Create a success response with value
    pub fn success(allocator: Allocator, value: anytype) ![]const u8 {
        // Serialize the value to JSON using Zig 0.15 API
        const json_value = try std.json.Stringify.valueAlloc(allocator, value, .{});
        defer allocator.free(json_value);

        // Wrap in {"value": ...} response format
        return try std.fmt.allocPrint(allocator, "{{\"value\":{s}}}", .{json_value});
    }

    /// Create a success response with null value
    pub fn successNull(allocator: Allocator) ![]const u8 {
        return try allocator.dupe(u8, "{\"value\":null}");
    }

    /// Create an error response
    pub fn err(allocator: Allocator, code: ErrorCode, message: []const u8) ![]const u8 {
        var string: std.ArrayListUnmanaged(u8) = .empty;
        errdefer string.deinit(allocator);

        try string.appendSlice(allocator, "{\"value\":{\"error\":\"");
        try string.appendSlice(allocator, code.toString());
        try string.appendSlice(allocator, "\",\"message\":\"");
        // Escape message for JSON
        for (message) |c| {
            switch (c) {
                '"' => try string.appendSlice(allocator, "\\\""),
                '\\' => try string.appendSlice(allocator, "\\\\"),
                '\n' => try string.appendSlice(allocator, "\\n"),
                '\r' => try string.appendSlice(allocator, "\\r"),
                '\t' => try string.appendSlice(allocator, "\\t"),
                else => try string.append(allocator, c),
            }
        }
        try string.appendSlice(allocator, "\",\"stacktrace\":\"\"}}");

        return try string.toOwnedSlice(allocator);
    }
};

/// New session request body
pub const NewSessionRequest = struct {
    capabilities: ?Capabilities = null,

    pub const Capabilities = struct {
        alwaysMatch: ?CapabilitySet = null,
        firstMatch: ?[]const CapabilitySet = null,
    };

    pub const CapabilitySet = struct {
        browserName: ?[]const u8 = null,
        browserVersion: ?[]const u8 = null,
        platformName: ?[]const u8 = null,
        acceptInsecureCerts: ?bool = null,
        pageLoadStrategy: ?[]const u8 = null,
        proxy: ?ProxyConfig = null,
        timeouts: ?Timeouts = null,
    };

    pub const ProxyConfig = struct {
        proxyType: ?[]const u8 = null,
    };

    pub fn parse(allocator: Allocator, body: []const u8) !NewSessionRequest {
        if (body.len == 0) return .{};
        const parsed = std.json.parseFromSlice(NewSessionRequest, allocator, body, .{
            .ignore_unknown_fields = true,
        }) catch |e| {
            std.log.warn("Failed to parse new session request: {}", .{e});
            return .{};
        };
        return parsed.value;
    }
};

/// Timeouts configuration
pub const Timeouts = struct {
    script: ?u64 = null, // milliseconds, null means no timeout
    pageLoad: ?u64 = null, // default 300000 (5 minutes)
    implicit: ?u64 = null, // default 0

    pub const default_page_load: u64 = 300_000;
    pub const default_implicit: u64 = 0;
    pub const default_script: u64 = 30_000;

    pub fn parse(allocator: Allocator, body: []const u8) !Timeouts {
        if (body.len == 0) return .{};
        const parsed = std.json.parseFromSlice(Timeouts, allocator, body, .{
            .ignore_unknown_fields = true,
        }) catch return .{};
        return parsed.value;
    }
};

/// Navigate request body
pub const NavigateRequest = struct {
    url: []const u8,

    pub fn parse(allocator: Allocator, body: []const u8) !NavigateRequest {
        const parsed = std.json.parseFromSlice(NavigateRequest, allocator, body, .{
            .ignore_unknown_fields = true,
        }) catch return error.InvalidArgument;
        return parsed.value;
    }
};

/// Execute script request body
pub const ExecuteScriptRequest = struct {
    script: []const u8,
    args: ?std.json.Value = null,

    pub fn parse(allocator: Allocator, body: []const u8) !ExecuteScriptRequest {
        const parsed = std.json.parseFromSlice(struct {
            script: []const u8,
            args: ?std.json.Value = null,
        }, allocator, body, .{
            .ignore_unknown_fields = true,
        }) catch return error.InvalidArgument;
        return .{
            .script = parsed.value.script,
            .args = parsed.value.args,
        };
    }
};

/// Session info for new session response
pub const SessionInfo = struct {
    sessionId: []const u8,
    capabilities: SessionCapabilities,

    pub const SessionCapabilities = struct {
        browserName: []const u8 = "crane",
        browserVersion: []const u8 = "0.1.0",
        platformName: []const u8 = "any",
        acceptInsecureCerts: bool = false,
        pageLoadStrategy: []const u8 = "normal",
        setWindowRect: bool = true,
        timeouts: Timeouts = .{
            .script = Timeouts.default_script,
            .pageLoad = Timeouts.default_page_load,
            .implicit = Timeouts.default_implicit,
        },
    };
};

/// Generate a random session ID (UUID v4 format)
pub fn generateSessionId(allocator: Allocator) ![]const u8 {
    var buf: [36]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = prng.random();

    // Generate random bytes
    var bytes: [16]u8 = undefined;
    random.bytes(&bytes);

    // Set version (4) and variant (RFC 4122)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    // Format as UUID string
    _ = std.fmt.bufPrint(&buf, "{x:0>2}{x:0>2}{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{
        bytes[0],  bytes[1],  bytes[2],  bytes[3],
        bytes[4],  bytes[5],
        bytes[6],  bytes[7],
        bytes[8],  bytes[9],
        bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15],
    }) catch unreachable;

    return try allocator.dupe(u8, &buf);
}

test "generateSessionId produces valid UUID" {
    const allocator = std.testing.allocator;
    const id = try generateSessionId(allocator);
    defer allocator.free(id);

    try std.testing.expectEqual(@as(usize, 36), id.len);
    try std.testing.expectEqual(@as(u8, '-'), id[8]);
    try std.testing.expectEqual(@as(u8, '-'), id[13]);
    try std.testing.expectEqual(@as(u8, '-'), id[18]);
    try std.testing.expectEqual(@as(u8, '-'), id[23]);
}

test "Response.success serializes correctly" {
    const allocator = std.testing.allocator;

    const response = try Response.success(allocator, "hello");
    defer allocator.free(response);

    try std.testing.expectEqualStrings("{\"value\":\"hello\"}", response);
}

test "Response.err serializes correctly" {
    const allocator = std.testing.allocator;

    const response = try Response.err(allocator, .invalid_argument, "bad input");
    defer allocator.free(response);

    try std.testing.expect(std.mem.indexOf(u8, response, "invalid argument") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "bad input") != null);
}
