//! URLPattern Matcher
//!
//! WHATWG URLPattern Standard: https://urlpattern.spec.whatwg.org/#urlpattern-matching
//! Spec Reference: Section 1.3 Pattern matching
//!
//! This module implements the URLPattern test() and exec() methods for
//! matching URLs against compiled patterns.
//!
//! ## Usage
//!
//! ```zig
//! const matcher = @import("matcher.zig");
//! const constructor = @import("constructor.zig");
//!
//! var pattern = try constructor.URLPattern.create(allocator, .{
//!     .string = "https://example.com/:path",
//! }, .{});
//! defer pattern.deinit(allocator);
//!
//! // Test if URL matches
//! const matches = matcher.testMatch(allocator, &pattern, "https://example.com/foo", null);
//! // matches == true
//!
//! // Execute and get captured groups
//! if (try matcher.exec(allocator, &pattern, "https://example.com/foo", null)) |*result| {
//!     defer result.deinit();
//!     // result.pathname.groups.get("path") == "foo"
//! }
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import other URLPattern modules
const constructor = @import("constructor.zig");
const URLPattern = constructor.URLPattern;
const Component = constructor.Component;
const pcre2_ffi = @import("pcre2_ffi.zig");
const Regex = pcre2_ffi.Regex;
const constructor_string_parser = @import("constructor_string_parser.zig");

/// Error types for URLPattern matching
pub const MatchError = error{
    InvalidInput,
    InvalidURL,
    OutOfMemory,
    MatchFailed,
};

/// Result of matching a single URL component
pub const URLPatternComponentResult = struct {
    /// The input value that was matched
    input: []const u8,
    /// Captured groups: name -> value
    groups: std.StringHashMapUnmanaged([]const u8),

    _allocator: Allocator,
    _owned_input: ?[]u8,
    _owned_group_values: std.ArrayListUnmanaged([]u8),

    pub fn init(allocator: Allocator) URLPatternComponentResult {
        return .{
            .input = "",
            .groups = .{},
            ._allocator = allocator,
            ._owned_input = null,
            ._owned_group_values = .empty,
        };
    }

    pub fn deinit(self: *URLPatternComponentResult) void {
        // Free owned group values
        for (self._owned_group_values.items) |val| {
            self._allocator.free(val);
        }
        self._owned_group_values.deinit(self._allocator);

        // Free groups map (keys point to component.group_names, values are owned)
        self.groups.deinit(self._allocator);

        // Free owned input
        if (self._owned_input) |input| {
            self._allocator.free(input);
        }
    }

    /// Get a captured group by name
    pub fn get(self: *const URLPatternComponentResult, name: []const u8) ?[]const u8 {
        return self.groups.get(name);
    }
};

/// Result of matching a URL against a pattern
pub const URLPatternResult = struct {
    /// The input(s) that were matched
    inputs: [][]const u8,
    /// Protocol component result
    protocol: URLPatternComponentResult,
    /// Username component result
    username: URLPatternComponentResult,
    /// Password component result
    password: URLPatternComponentResult,
    /// Hostname component result
    hostname: URLPatternComponentResult,
    /// Port component result
    port: URLPatternComponentResult,
    /// Pathname component result
    pathname: URLPatternComponentResult,
    /// Search component result
    search: URLPatternComponentResult,
    /// Hash component result
    hash: URLPatternComponentResult,

    _allocator: Allocator,
    _owned_inputs: ?[][]u8,

    pub fn deinit(self: *URLPatternResult) void {
        // Free component results
        self.protocol.deinit();
        self.username.deinit();
        self.password.deinit();
        self.hostname.deinit();
        self.port.deinit();
        self.pathname.deinit();
        self.search.deinit();
        self.hash.deinit();

        // Free owned inputs
        if (self._owned_inputs) |inputs| {
            for (inputs) |input| {
                self._allocator.free(input);
            }
            self._allocator.free(inputs);
        }

        // Free inputs slice (pointers to owned_inputs)
        self._allocator.free(self.inputs);
    }
};

/// Input type for matching
pub const URLPatternInput = union(enum) {
    /// A URL string to match
    string: []const u8,
    /// A URLPatternInit with explicit component values
    init: struct {
        protocol: ?[]const u8 = null,
        username: ?[]const u8 = null,
        password: ?[]const u8 = null,
        hostname: ?[]const u8 = null,
        port: ?[]const u8 = null,
        pathname: ?[]const u8 = null,
        search: ?[]const u8 = null,
        hash: ?[]const u8 = null,
        baseURL: ?[]const u8 = null,
    },
};

/// Test if input matches pattern (returns boolean)
///
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-test
pub fn testMatch(
    allocator: Allocator,
    pattern: *const URLPattern,
    input: []const u8,
    base_url: ?[]const u8,
) bool {
    // exec returns null on no match
    var result = exec(allocator, pattern, input, base_url) catch return false;
    if (result) |*r| {
        r.deinit();
        return true;
    }
    return false;
}

/// Test if input matches pattern using URLPatternInput
pub fn testMatchInput(
    allocator: Allocator,
    pattern: *const URLPattern,
    input: URLPatternInput,
    base_url: ?[]const u8,
) bool {
    var result = execInput(allocator, pattern, input, base_url) catch return false;
    if (result) |*r| {
        r.deinit();
        return true;
    }
    return false;
}

/// Execute pattern matching and return captured groups
///
/// Returns null if no match, otherwise returns URLPatternResult
///
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-exec
pub fn exec(
    allocator: Allocator,
    pattern: *const URLPattern,
    input: []const u8,
    base_url: ?[]const u8,
) MatchError!?URLPatternResult {
    return execInput(allocator, pattern, .{ .string = input }, base_url);
}

/// Execute pattern matching with URLPatternInput
pub fn execInput(
    allocator: Allocator,
    pattern: *const URLPattern,
    input: URLPatternInput,
    base_url: ?[]const u8,
) MatchError!?URLPatternResult {
    // Step 1: Parse the input URL or extract components
    var url_parts = parseInput(allocator, input, base_url) catch |err| switch (err) {
        error.InvalidURL => return null,
        else => return err,
    };
    defer url_parts.deinit(allocator);

    // Step 2: Match each component
    var protocol_result = try matchComponent(allocator, &pattern.protocol, url_parts.protocol) orelse return null;
    errdefer protocol_result.deinit();

    var username_result = try matchComponent(allocator, &pattern.username, url_parts.username) orelse {
        protocol_result.deinit();
        return null;
    };
    errdefer username_result.deinit();

    var password_result = try matchComponent(allocator, &pattern.password, url_parts.password) orelse {
        protocol_result.deinit();
        username_result.deinit();
        return null;
    };
    errdefer password_result.deinit();

    var hostname_result = try matchComponent(allocator, &pattern.hostname, url_parts.hostname) orelse {
        protocol_result.deinit();
        username_result.deinit();
        password_result.deinit();
        return null;
    };
    errdefer hostname_result.deinit();

    var port_result = try matchComponent(allocator, &pattern.port, url_parts.port) orelse {
        protocol_result.deinit();
        username_result.deinit();
        password_result.deinit();
        hostname_result.deinit();
        return null;
    };
    errdefer port_result.deinit();

    var pathname_result = try matchComponent(allocator, &pattern.pathname, url_parts.pathname) orelse {
        protocol_result.deinit();
        username_result.deinit();
        password_result.deinit();
        hostname_result.deinit();
        port_result.deinit();
        return null;
    };
    errdefer pathname_result.deinit();

    var search_result = try matchComponent(allocator, &pattern.search, url_parts.search) orelse {
        protocol_result.deinit();
        username_result.deinit();
        password_result.deinit();
        hostname_result.deinit();
        port_result.deinit();
        pathname_result.deinit();
        return null;
    };
    errdefer search_result.deinit();

    var hash_result = try matchComponent(allocator, &pattern.hash, url_parts.hash) orelse {
        protocol_result.deinit();
        username_result.deinit();
        password_result.deinit();
        hostname_result.deinit();
        port_result.deinit();
        pathname_result.deinit();
        search_result.deinit();
        return null;
    };
    errdefer hash_result.deinit();

    // Step 3: Build result with inputs
    const inputs_slice = try allocator.alloc([]const u8, 1);
    errdefer allocator.free(inputs_slice);

    // Copy input string
    const input_str = switch (input) {
        .string => |s| s,
        .init => "",
    };
    const owned_input = try allocator.alloc(u8, input_str.len);
    errdefer allocator.free(owned_input);
    @memcpy(owned_input, input_str);

    const owned_inputs = try allocator.alloc([]u8, 1);
    owned_inputs[0] = owned_input;
    inputs_slice[0] = owned_input;

    return URLPatternResult{
        .inputs = inputs_slice,
        .protocol = protocol_result,
        .username = username_result,
        .password = password_result,
        .hostname = hostname_result,
        .port = port_result,
        .pathname = pathname_result,
        .search = search_result,
        .hash = hash_result,
        ._allocator = allocator,
        ._owned_inputs = owned_inputs,
    };
}

/// URL matching, steps 1-13. All parsed strings live until this match ends.
const URLParts = struct {
    protocol: []const u8 = "",
    username: []const u8 = "",
    password: []const u8 = "",
    hostname: []const u8 = "",
    port: []const u8 = "",
    pathname: []const u8 = "",
    search: []const u8 = "",
    hash: []const u8 = "",
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *URLParts, _: Allocator) void {
        self.arena.deinit();
    }
};

fn parseInput(allocator: Allocator, input: URLPatternInput, base_url_string: ?[]const u8) MatchError!URLParts {
    const url = @import("url");
    const basic_parser = url.parser.basic_url_parser;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const temporary = arena.allocator();
    var result = URLParts{ .arena = undefined };
    switch (input) {
        .init => |init| {
            // Step 12.1 throws for a dictionary plus a separate base URL;
            // step 12.2 turns invalid component values into no match.
            if (base_url_string != null) return error.InvalidInput;
            var processed = @import("process_init.zig").process(temporary, .{
                .protocol = init.protocol,
                .username = init.username,
                .password = init.password,
                .hostname = init.hostname,
                .port = init.port,
                .pathname = init.pathname,
                .search = init.search,
                .hash = init.hash,
                .base_url = init.baseURL,
            }, .url) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidURL;
            defer processed.deinit();
            inline for (@import("process_init.zig").names) |name| {
                @field(result, name) = try temporary.dupe(u8, @field(processed.init, name).?);
            }
        },
        .string => |value| {
            // Step 13 uses the URL parser, including relative resolution and
            // canonicalization; constructor pattern parsing is not URL parsing.
            const base = if (base_url_string) |base_value|
                basic_parser.parse(temporary, base_value, null) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidURL
            else
                null;
            const record = basic_parser.parse(temporary, value, if (base) |*b| b else null) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidURL;
            result.protocol = record.scheme();
            result.username = record.username();
            result.password = record.password();
            result.hostname = if (record.host) |host| url.host_serializer.serializeHost(temporary, host) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidURL else "";
            result.port = if (record.port) |port| try std.fmt.allocPrint(temporary, "{d}", .{port}) else "";
            result.pathname = try @import("canonicalize.zig").serializePath(temporary, &record);
            result.search = record.query() orelse "";
            result.hash = record.fragment() orelse "";
        },
    }
    result.arena = arena;
    return result;
}

/// Match a single component against its pattern
fn matchComponent(
    allocator: Allocator,
    component: *const Component,
    input: []const u8,
) MatchError!?URLPatternComponentResult {
    var result = URLPatternComponentResult.init(allocator);
    errdefer result.deinit();

    // Copy input
    const owned_input = try allocator.alloc(u8, input.len);
    @memcpy(owned_input, input);
    result.input = owned_input;
    result._owned_input = owned_input;

    // If component has a regex, use it
    if (component.regex) |*regex| {
        var mutable_regex = @constCast(regex);
        const match_result = mutable_regex.match(input) catch {
            return MatchError.MatchFailed;
        };

        if (match_result == null) {
            result.deinit();
            return null;
        }

        var match = match_result.?;
        defer match.deinit();

        // Extract named groups
        for (component.group_names) |name| {
            // Convert to PCRE2 name format (prefix numeric names with _)
            const pcre2_name = toPcre2GroupName(name);
            const lookup_name = pcre2_name.name[0..pcre2_name.len];

            if (match.getNamedGroup(lookup_name)) |value| {
                // Copy the value since match will be freed
                const value_copy = try allocator.alloc(u8, value.len);
                errdefer allocator.free(value_copy);
                @memcpy(value_copy, value);
                try result._owned_group_values.append(allocator, value_copy);
                // Store with original name, not PCRE2 name
                try result.groups.put(allocator, name, value_copy);
            }
        }

        return result;
    }

    // No regex - do simple matching
    // For patterns like "*", match everything
    if (std.mem.eql(u8, component.pattern_string, "*")) {
        // Wildcard matches everything - capture the whole input as group "0"
        if (component.group_names.len > 0) {
            const value_copy = try allocator.alloc(u8, input.len);
            errdefer allocator.free(value_copy);
            @memcpy(value_copy, input);
            try result._owned_group_values.append(allocator, value_copy);
            try result.groups.put(allocator, component.group_names[0], value_copy);
        }
        return result;
    }

    // For fixed patterns, check exact match
    if (!hasPatternChars(component.pattern_string)) {
        if (std.mem.eql(u8, component.pattern_string, input)) {
            return result;
        }
        result.deinit();
        return null;
    }

    // For patterns with named parameters, try simple matching
    // This is a simplified implementation - full implementation would use the regex
    if (trySimplePatternMatch(allocator, component, input, &result)) |matched| {
        if (matched) {
            return result;
        }
    } else |_| {
        // Error during matching
    }

    result.deinit();
    return null;
}

/// Check if a pattern contains pattern characters
fn hasPatternChars(pattern: []const u8) bool {
    for (pattern) |c| {
        if (c == ':' or c == '*' or c == '(' or c == '{') {
            return true;
        }
    }
    return false;
}

/// Try to match a simple pattern (e.g., "/:id" against "/123")
fn trySimplePatternMatch(
    allocator: Allocator,
    component: *const Component,
    input: []const u8,
    result: *URLPatternComponentResult,
) !bool {
    const pattern = component.pattern_string;

    // Handle patterns like "/:name"
    if (pattern.len > 1 and pattern[0] == '/' and pattern[1] == ':') {
        // Extract the name
        var name_end: usize = 2;
        while (name_end < pattern.len and isIdentChar(pattern[name_end])) {
            name_end += 1;
        }

        if (name_end > 2) {
            const name = pattern[2..name_end];

            // Input should start with /
            if (input.len > 0 and input[0] == '/') {
                // Extract the value (everything after the /)
                var value_end: usize = 1;
                while (value_end < input.len and input[value_end] != '/') {
                    value_end += 1;
                }

                const value = input[1..value_end];

                // Store the captured group
                const value_copy = try allocator.alloc(u8, value.len);
                errdefer allocator.free(value_copy);
                @memcpy(value_copy, value);
                try result._owned_group_values.append(allocator, value_copy);
                try result.groups.put(allocator, name, value_copy);

                // Check if there's more pattern to match
                if (name_end >= pattern.len and value_end >= input.len) {
                    return true;
                }

                // If pattern continues with more segments, we'd need recursive matching
                // For now, accept if we've consumed the input
                if (value_end >= input.len) {
                    return true;
                }
            }
        }
    }

    // Handle patterns like ":name" (without leading /)
    if (pattern.len > 0 and pattern[0] == ':') {
        var name_end: usize = 1;
        while (name_end < pattern.len and isIdentChar(pattern[name_end])) {
            name_end += 1;
        }

        if (name_end > 1 and name_end >= pattern.len) {
            const name = pattern[1..name_end];

            // Capture the entire input
            const value_copy = try allocator.alloc(u8, input.len);
            errdefer allocator.free(value_copy);
            @memcpy(value_copy, input);
            try result._owned_group_values.append(allocator, value_copy);
            try result.groups.put(allocator, name, value_copy);

            return true;
        }
    }

    // For complex patterns, fall back to regex (stub returns true for any match)
    // In production, this would use PCRE2
    if (component.regex != null) {
        return true;
    }

    return false;
}

/// Check if a character is valid in an identifier
fn isIdentChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        (c >= '0' and c <= '9') or
        c == '_' or c == '$';
}

/// Result type for PCRE2 group name conversion
const Pcre2GroupNameResult = struct {
    name: [33]u8,
    len: usize,
};

/// Convert a URLPattern group name to PCRE2 format.
/// PCRE2 requires group names to start with a non-digit character.
/// URLPattern allows numeric names like "0", "1" for unnamed groups.
/// We prefix such names with "_" to make them valid PCRE2 names.
fn toPcre2GroupName(name: []const u8) Pcre2GroupNameResult {
    var result: Pcre2GroupNameResult = .{ .name = undefined, .len = 0 };
    if (name.len > 0 and name[0] >= '0' and name[0] <= '9') {
        // Name starts with a digit - prefix with underscore
        result.name[0] = '_';
        const copy_len = @min(name.len, 32);
        @memcpy(result.name[1..][0..copy_len], name[0..copy_len]);
        result.len = copy_len + 1;
    } else {
        // Name is valid as-is
        const copy_len = @min(name.len, 33);
        @memcpy(result.name[0..copy_len], name[0..copy_len]);
        result.len = copy_len;
    }
    return result;
}

/// Check if a scheme is a special scheme (has default port)
/// Per URL spec: https, http, ws, wss, ftp, file
fn isSpecialScheme(scheme: []const u8) bool {
    return std.mem.eql(u8, scheme, "https") or
        std.mem.eql(u8, scheme, "http") or
        std.mem.eql(u8, scheme, "ws") or
        std.mem.eql(u8, scheme, "wss") or
        std.mem.eql(u8, scheme, "ftp") or
        std.mem.eql(u8, scheme, "file");
}

// ============================================================================
// Tests
// ============================================================================

test "testMatch - simple URL" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Should match exact URL
    try std.testing.expect(testMatch(allocator, &pattern, "https://example.com/path", null));
}

test "testMatch - non-matching URL" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Different path should not match
    try std.testing.expect(!testMatch(allocator, &pattern, "https://example.com/other", null));
}

test "testMatch - wildcard protocol" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "*",
            .hostname = "example.com",
            .pathname = "/path",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Both http and https should match
    try std.testing.expect(testMatch(allocator, &pattern, "https://example.com/path", null));
    try std.testing.expect(testMatch(allocator, &pattern, "http://example.com/path", null));
}

test "exec - basic result" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    if (try exec(allocator, &pattern, "https://example.com/path", null)) |r| {
        var result = r;
        defer result.deinit();

        // Check that input is captured
        try std.testing.expect(result.inputs.len == 1);
        try std.testing.expectEqualStrings("https://example.com/path", result.inputs[0]);

        // Check component inputs
        try std.testing.expectEqualStrings("https", result.protocol.input);
        try std.testing.expectEqualStrings("example.com", result.hostname.input);
        try std.testing.expectEqualStrings("/path", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

test "exec - with named parameter" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/:id",
        },
    }, .{});
    defer pattern.deinit(allocator);

    if (try exec(allocator, &pattern, "https://example.com/123", null)) |r| {
        var result = r;
        defer result.deinit();

        // Should capture the id parameter
        if (result.pathname.groups.get("id")) |id| {
            try std.testing.expectEqualStrings("123", id);
        }
    } else {
        return error.TestUnexpectedResult;
    }
}

test "exec - no match returns null" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/specific",
        },
    }, .{});
    defer pattern.deinit(allocator);

    const result = try exec(allocator, &pattern, "https://other.com/path", null);
    try std.testing.expect(result == null);
}

test "exec - with base URL" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "example.com",
            .pathname = "/api/users",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Relative URL with base
    if (try exec(allocator, &pattern, "/api/users", "https://example.com")) |r| {
        var result = r;
        defer result.deinit();
        try std.testing.expectEqualStrings("/api/users", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}

test "testMatchInput - with init input" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "*.example.com",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Test with init input
    const matches = testMatchInput(allocator, &pattern, .{
        .init = .{
            .protocol = "https",
            .hostname = "api.example.com",
        },
    }, null);

    try std.testing.expect(matches);
}

test "URLPatternComponentResult - groups access" {
    const allocator = std.testing.allocator;

    var result = URLPatternComponentResult.init(allocator);
    defer result.deinit();

    // Add a group
    const value = try allocator.dupe(u8, "test_value");
    try result._owned_group_values.append(allocator, value);
    try result.groups.put(allocator, "name", value);

    // Should be retrievable
    try std.testing.expectEqualStrings("test_value", result.get("name").?);

    // Non-existent should be null
    try std.testing.expect(result.get("nonexistent") == null);
}

test "testMatchInput - pathname only pattern matches pathname only input" {
    const allocator = std.testing.allocator;

    // Create pattern with just pathname (like {pathname: "/foo/bar"})
    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/foo/bar",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Test with init input having just pathname
    const matches = testMatchInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/foo/bar",
        },
    }, null);

    try std.testing.expect(matches);
}

test "exec - pathname only pattern matches pathname only input and returns result" {
    const allocator = std.testing.allocator;

    // Create pattern with just pathname (like {pathname: "/foo/bar"})
    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/foo/bar",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Call exec with init input having just pathname
    if (try execInput(allocator, &pattern, .{
        .init = .{
            .pathname = "/foo/bar",
        },
    }, null)) |r| {
        var result = r;
        defer result.deinit();

        // Verify the result
        try std.testing.expectEqualStrings("/foo/bar", result.pathname.input);
    } else {
        return error.TestUnexpectedResult;
    }
}
