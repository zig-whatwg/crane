//! URLPattern Matcher
//!
//! WHATWG URLPattern Standard: https://urlpattern.spec.whatwg.org/#urlpattern-matching
//! Spec Reference: Section 1.3 Pattern matching
//!
//! This module implements the URLPattern test() and exec() methods for
//! matching URLs against compiled patterns. Each component is matched with
//! RegExpBuiltinExec on its regular expression, in the realm the caller
//! names (regexp.zig).
//!
//! ## Usage
//!
//! ```zig
//! const matcher = @import("matcher.zig");
//! const constructor = @import("constructor.zig");
//!
//! var pattern = try constructor.URLPattern.create(allocator, realm, .{
//!     .string = "https://example.com/:path",
//! }, .{});
//! defer pattern.deinit(allocator);
//!
//! // Test if URL matches
//! const matches = try matcher.testMatch(allocator, realm, &pattern, "https://example.com/foo", null);
//! // matches == true
//!
//! // Execute and get captured groups
//! if (try matcher.exec(allocator, realm, &pattern, "https://example.com/foo", null)) |*result| {
//!     defer result.deinit();
//!     // result.pathname.get("path") == "foo"
//! }
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import other URLPattern modules
const constructor = @import("constructor.zig");
const URLPattern = constructor.URLPattern;
const Component = constructor.Component;
const regexp_module = @import("regexp.zig");
const Realm = regexp_module.Realm;
const constructor_string_parser = @import("constructor_string_parser.zig");

/// Error types for URLPattern matching. Nothing else can fail: a component's
/// RegExpBuiltinExec is infallible but for memory (its regexp compiled when
/// the pattern was made), and an input that does not parse is no match.
pub const MatchError = error{
    /// URL matching step 12.1: a URLPatternInit input with a separate base
    /// URL string - the binding throws a TypeError.
    InvalidInput,
    /// The engine cannot match (regexp.zig): the binding throws a
    /// NotSupportedError. The pattern was compiled by the same agent, so
    /// in practice it can.
    NotSupported,
    OutOfMemory,
};

/// One entry of a component result's groups record: a name from the
/// component's group name list and Get(execResult, ToString(index)) - null
/// for undefined (the group did not participate), apart from "".
pub const Group = struct {
    /// BORROWED from the component's group name list.
    name: []const u8,
    value: ?[]const u8,
};

/// Result of matching a single URL component ("create a component match
/// result").
pub const URLPatternComponentResult = struct {
    /// The input value that was matched
    input: []const u8,
    /// The groups record, in the component's group name list order.
    groups: []const Group,

    _allocator: Allocator,
    _owned_input: ?[]u8,
    _owned_groups: []const Group,
    _captures: ?regexp_module.Captures,

    pub fn init(allocator: Allocator) URLPatternComponentResult {
        return .{
            .input = "",
            .groups = &.{},
            ._allocator = allocator,
            ._owned_input = null,
            ._owned_groups = &.{},
            ._captures = null,
        };
    }

    pub fn deinit(self: *URLPatternComponentResult) void {
        if (self._captures) |*captures| captures.deinit();
        self._allocator.free(self._owned_groups);
        if (self._owned_input) |input| {
            self._allocator.free(input);
        }
    }

    /// The group named `name`: null when there is none; a Group whose value
    /// is null when it is undefined.
    pub fn get(self: *const URLPatternComponentResult, name: []const u8) ?Group {
        for (self.groups) |group| {
            if (std.mem.eql(u8, group.name, name)) return group;
        }
        return null;
    }

    /// The string the group named `name` matched: null when there is no such
    /// group or it is undefined.
    pub fn value(self: *const URLPatternComponentResult, name: []const u8) ?[]const u8 {
        const group = self.get(name) orelse return null;
        return group.value;
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
    realm: Realm,
    pattern: *const URLPattern,
    input: []const u8,
    base_url: ?[]const u8,
) MatchError!bool {
    return testMatchInput(allocator, realm, pattern, .{ .string = input }, base_url);
}

/// Test if input matches pattern using URLPatternInput: "match" is not null.
pub fn testMatchInput(
    allocator: Allocator,
    realm: Realm,
    pattern: *const URLPattern,
    input: URLPatternInput,
    base_url: ?[]const u8,
) MatchError!bool {
    var result = try execInput(allocator, realm, pattern, input, base_url) orelse return false;
    result.deinit();
    return true;
}

/// Execute pattern matching and return captured groups
///
/// Returns null if no match, otherwise returns URLPatternResult
///
/// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-exec
pub fn exec(
    allocator: Allocator,
    realm: Realm,
    pattern: *const URLPattern,
    input: []const u8,
    base_url: ?[]const u8,
) MatchError!?URLPatternResult {
    return execInput(allocator, realm, pattern, .{ .string = input }, base_url);
}

/// Execute pattern matching with URLPatternInput. `realm` is the one the
/// components' regular expressions run in; BORROWED for the call.
pub fn execInput(
    allocator: Allocator,
    realm: Realm,
    pattern: *const URLPattern,
    input: URLPatternInput,
    base_url: ?[]const u8,
) MatchError!?URLPatternResult {
    // Step 1: Parse the input URL or extract components
    var url_parts = parseInput(allocator, input, base_url) catch |err| switch (err) {
        error.InvalidURL => return null,
        error.InvalidInput => return error.InvalidInput,
        error.OutOfMemory => return error.OutOfMemory,
    };
    defer url_parts.deinit(allocator);

    // Step 2: Match each component
    var protocol_result = try matchComponent(allocator, realm, &pattern.protocol, url_parts.protocol) orelse return null;
    errdefer protocol_result.deinit();

    var username_result = try matchComponent(allocator, realm, &pattern.username, url_parts.username) orelse {
        protocol_result.deinit();
        return null;
    };
    errdefer username_result.deinit();

    var password_result = try matchComponent(allocator, realm, &pattern.password, url_parts.password) orelse {
        protocol_result.deinit();
        username_result.deinit();
        return null;
    };
    errdefer password_result.deinit();

    var hostname_result = try matchComponent(allocator, realm, &pattern.hostname, url_parts.hostname) orelse {
        protocol_result.deinit();
        username_result.deinit();
        password_result.deinit();
        return null;
    };
    errdefer hostname_result.deinit();

    var port_result = try matchComponent(allocator, realm, &pattern.port, url_parts.port) orelse {
        protocol_result.deinit();
        username_result.deinit();
        password_result.deinit();
        hostname_result.deinit();
        return null;
    };
    errdefer port_result.deinit();

    var pathname_result = try matchComponent(allocator, realm, &pattern.pathname, url_parts.pathname) orelse {
        protocol_result.deinit();
        username_result.deinit();
        password_result.deinit();
        hostname_result.deinit();
        port_result.deinit();
        return null;
    };
    errdefer pathname_result.deinit();

    var search_result = try matchComponent(allocator, realm, &pattern.search, url_parts.search) orelse {
        protocol_result.deinit();
        username_result.deinit();
        password_result.deinit();
        hostname_result.deinit();
        port_result.deinit();
        pathname_result.deinit();
        return null;
    };
    errdefer search_result.deinit();

    var hash_result = try matchComponent(allocator, realm, &pattern.hash, url_parts.hash) orelse {
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

/// parseInput's errors: InvalidURL is "return null" (steps 12.2, 13.2.2.2,
/// 13.4), which execInput answers.
const ParseError = error{ InvalidInput, InvalidURL, OutOfMemory };

fn parseInput(allocator: Allocator, input: URLPatternInput, base_url_string: ?[]const u8) ParseError!URLParts {
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

/// Match a single component: RegExpBuiltinExec(component's regular
/// expression, input) ("match" steps 14-21), and for a match, "create a
/// component match result" given the component, input and execResult.
fn matchComponent(
    allocator: Allocator,
    realm: Realm,
    component: *const Component,
    input: []const u8,
) MatchError!?URLPatternComponentResult {
    const exec_result = component.regexp.exec(realm, input, allocator) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.NotSupported => return error.NotSupported,
        // The pattern's construction compiled this string with these flags,
        // so RegExpCreate cannot throw for it now; were it to, there is no
        // execResult: no match.
        error.InvalidPattern => return null,
    };
    var captures = exec_result orelse return null;
    errdefer captures.deinit();

    // 1. Let result be a new URLPatternComponentResult.
    var result = URLPatternComponentResult.init(allocator);
    errdefer result.deinit();
    // 2. Set result["input"] to input.
    const owned_input = try allocator.dupe(u8, input);
    result.input = owned_input;
    result._owned_input = owned_input;
    // 3. Let groups be a record<USVString, (USVString or undefined)>.
    const groups = try allocator.alloc(Group, component.group_names.len);
    result._owned_groups = groups;
    // 4-5. For each index 1..size of the group name list: groups[name] is
    //      Get(execResult, ToString(index)).
    for (component.group_names, 0..) |name, i| {
        groups[i] = .{ .name = name, .value = captures.get(i + 1) };
    }
    // 6. Set result["groups"] to groups.
    result.groups = groups;
    result._captures = captures;
    // 7. Return result.
    return result;
}

// Matching runs each component's regular expression in an engine, so the
// tests that match live in tests/v8 (urlpattern_matcher_test.zig and
// urlpattern_corpus_test.zig), where there is one.
