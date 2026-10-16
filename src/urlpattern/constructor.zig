//! URLPattern Constructor
//!
//! WHATWG URLPattern Standard: https://urlpattern.spec.whatwg.org/#urlpattern-class
//! Spec Reference: Section 1.2 URLPattern class
//!
//! This module implements the URLPattern constructor and component compilation,
//! providing the main API for creating URL patterns.
//!
//! ## Usage
//!
//! ```zig
//! const constructor = @import("constructor.zig");
//!
//! // Create from URL string
//! var pattern = try constructor.URLPattern.create(allocator, .{
//!     .string = "https://example.com/:path",
//! }, .{});
//! defer pattern.deinit(allocator);
//!
//! // Create from URLPatternInit
//! var pattern2 = try constructor.URLPattern.create(allocator, .{
//!     .init = .{
//!         .protocol = "https",
//!         .hostname = "*.example.com",
//!         .pathname = "/:section/:page",
//!     },
//! }, .{});
//! defer pattern2.deinit(allocator);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import other URLPattern modules
const tokenizer = @import("tokenizer.zig");
const parser = @import("parser.zig");
const regex_generator = @import("regex_generator.zig");
const canonicalize = @import("canonicalize.zig");
const constructor_string_parser = @import("constructor_string_parser.zig");
const pcre2_ffi = @import("pcre2_ffi.zig");

const URLPatternInit = constructor_string_parser.URLPatternInit;
const Part = parser.Part;
const Options = parser.Options;
const Regex = pcre2_ffi.Regex;

/// Error types for URLPattern construction
pub const ConstructorError = error{
    InvalidPattern,
    InvalidProtocol,
    InvalidHostname,
    InvalidPort,
    InvalidPathname,
    DuplicateName,
    CompilationFailed,
    OutOfMemory,
};

/// A compiled URL pattern component
pub const Component = struct {
    /// The pattern string in canonical form
    pattern_string: []const u8,
    /// Compiled PCRE2 regex (null until PCRE2 is fully integrated)
    regex: ?Regex,
    /// Generated regex string (for debugging/testing)
    regex_string: []const u8,
    /// Names of capturing groups in order
    group_names: [][]const u8,
    /// Whether any part contains a custom regular expression
    has_regexp_groups: bool,

    _allocator: Allocator,
    _owned_pattern_string: ?[]u8,
    _owned_regex_string: ?[]u8,
    _owned_group_names: ?[][]u8,

    pub fn deinit(self: *Component) void {
        if (self.regex) |*r| {
            var regex = r;
            regex.deinit();
        }
        if (self._owned_pattern_string) |s| self._allocator.free(s);
        if (self._owned_regex_string) |s| self._allocator.free(s);
        if (self._owned_group_names) |names| {
            for (names) |name| {
                self._allocator.free(name);
            }
            self._allocator.free(names);
        }
        // Free the group_names pointer slice (allocated in compileComponent)
        if (self.group_names.len > 0) {
            // Cast from [][]const u8 to [][]u8 since we allocated it ourselves
            const ptr: [*][]const u8 = @constCast(self.group_names.ptr);
            self._allocator.free(ptr[0..self.group_names.len]);
        }
    }
};

/// Input type for URLPattern constructor
pub const Input = union(enum) {
    /// A URL pattern string like "https://example.com/:path"
    string: []const u8,
    /// A URLPatternInit dictionary with individual component patterns
    init: URLPatternInit,
};

/// Options for URLPattern construction
pub const URLPatternOptions = struct {
    /// Ignore case when matching
    ignore_case: bool = false,
};

/// A compiled URL pattern for matching URLs
///
/// URLPattern provides a way to match URLs against patterns,
/// extracting named or positional groups from the matched URL components.
pub const URLPattern = struct {
    /// Protocol/scheme component pattern
    protocol: Component,
    /// Username component pattern
    username: Component,
    /// Password component pattern
    password: Component,
    /// Hostname component pattern
    hostname: Component,
    /// Port component pattern
    port: Component,
    /// Pathname component pattern
    pathname: Component,
    /// Search/query component pattern
    search: Component,
    /// Hash/fragment component pattern
    hash: Component,

    /// Whether ignore_case was set
    ignore_case: bool,

    const Self = @This();

    /// Create a new URLPattern
    ///
    /// Spec: https://urlpattern.spec.whatwg.org/#dom-urlpattern-urlpattern
    pub fn create(allocator: Allocator, input: Input, options: URLPatternOptions) ConstructorError!Self {
        return createWithBase(allocator, input, null, options);
    }

    pub fn createWithBase(allocator: Allocator, input: Input, base_url: ?[]const u8, options: URLPatternOptions) ConstructorError!Self {
        // Create, steps 1-3: only string input accepts a separate base URL.
        var init = switch (input) {
            .string => |value| constructor_string_parser.parse(allocator, value) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidPattern,
            .init => |value| value,
        };
        if (input == .string) {
            if (base_url == null and init.protocol == null) return error.InvalidPattern;
            if (base_url) |base| init.base_url = base;
        } else if (base_url != null) return error.InvalidPattern;

        // Steps 4-5: process inheritance, then default every absent component.
        var processed = @import("process_init.zig").process(allocator, init, .pattern) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidPattern;
        defer processed.deinit();
        init = processed.init;
        inline for (@import("process_init.zig").names) |name| {
            if (@field(init, name) == null) @field(init, name) = "*";
        }
        // Step 6: default-port elision applies to the entire literal input,
        // before compiling fragments (443* must retain its 443 prefix).
        if (@import("url").special_schemes.defaultPort(init.protocol.?)) |default_port| {
            const port = std.fmt.parseInt(u16, init.port.?, 10) catch null;
            if (port != null and port.? == default_port and allDigits(init.port.?)) init.port = "";
        }

        var protocol = try compileProtocol(allocator, init.protocol.?);
        errdefer protocol.deinit();
        var username = try compileComponent(allocator, init.username.?, .username, false, false);
        errdefer username.deinit();
        var password = try compileComponent(allocator, init.password.?, .password, false, false);
        errdefer password.deinit();
        var hostname = try compileComponent(allocator, init.hostname.?, .hostname, false, false);
        errdefer hostname.deinit();
        var port = try compileComponent(allocator, init.port.?, .port, false, false);
        errdefer port.deinit();
        var pathname = try compileComponent(allocator, init.pathname.?, .pathname, try protocolMatchesSpecialScheme(&protocol), options.ignore_case);
        errdefer pathname.deinit();
        var search = try compileComponent(allocator, init.search.?, .search, false, options.ignore_case);
        errdefer search.deinit();
        var hash = try compileComponent(allocator, init.hash.?, .hash, false, options.ignore_case);
        errdefer hash.deinit();
        return .{
            .protocol = protocol,
            .username = username,
            .password = password,
            .hostname = hostname,
            .port = port,
            .pathname = pathname,
            .search = search,
            .hash = hash,
            .ignore_case = options.ignore_case,
        };
    }

    /// Free all resources
    pub fn deinit(self: *Self, allocator: Allocator) void {
        _ = allocator;
        self.protocol.deinit();
        self.username.deinit();
        self.password.deinit();
        self.hostname.deinit();
        self.port.deinit();
        self.pathname.deinit();
        self.search.deinit();
        self.hash.deinit();
    }

    /// Check if the pattern has any regexp groups
    pub fn hasRegexpGroups(self: *const Self) bool {
        return self.protocol.has_regexp_groups or
            self.username.has_regexp_groups or
            self.password.has_regexp_groups or
            self.hostname.has_regexp_groups or
            self.port.has_regexp_groups or
            self.pathname.has_regexp_groups or
            self.search.has_regexp_groups or
            self.hash.has_regexp_groups;
    }
};

/// Component type for canonicalization
const ComponentType = enum {
    protocol,
    username,
    password,
    hostname,
    port,
    pathname,
    search,
    hash,
};

/// Compile a protocol for both the constructor-string parser and create.
pub fn compileProtocol(allocator: Allocator, input: []const u8) ConstructorError!Component {
    return compileComponent(allocator, input, .protocol, false, false);
}

/// Protocol component matches a special scheme, steps 1-2. All consumers use
/// the compiled regexp; the regexp backend determines its matching semantics.
pub fn protocolMatchesSpecialScheme(component: *const Component) ConstructorError!bool {
    const regex = if (component.regex) |*value| @constCast(value) else return false;
    for ([_][]const u8{ "ftp", "file", "http", "https", "ws", "wss" }) |scheme| {
        var result = regex.match(scheme) catch |err| return if (err == error.OutOfMemory) error.OutOfMemory else error.CompilationFailed;
        if (result) |*matched| {
            matched.deinit();
            return true;
        }
    }
    return false;
}

fn allDigits(value: []const u8) bool {
    if (value.len == 0) return false;
    for (value) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
}

fn portEncoding(allocator: Allocator, value: []const u8) canonicalize.CanonicalizationError![]u8 {
    return canonicalize.canonicalizePort(allocator, value, null);
}

fn hostnameIsIPv6(value: []const u8) bool {
    // Hostname pattern is an IPv6 address, steps 1-4.
    return std.mem.startsWith(u8, value, "[") or std.mem.startsWith(u8, value, "{[") or std.mem.startsWith(u8, value, "\\[");
}

/// Check if any part has a regexp group
fn hasRegexpGroups(parts: []const Part) bool {
    for (parts) |part| {
        if (part.type == .regexp) {
            return true;
        }
    }
    return false;
}

/// Compile a single URL pattern component
fn compileComponent(
    allocator: Allocator,
    input: []const u8,
    component_type: ComponentType,
    special_path: bool,
    ignore_case: bool,
) ConstructorError!Component {
    // Compile a component, step 1: encode each fixed value, prefix and suffix
    // while parsing. Validation failures must propagate to construction.
    const options = if (component_type == .hostname) parser.hostname_options else if (special_path) parser.pathname_options else parser.default_options;
    const encoding: parser.EncodingCallback = switch (component_type) {
        .protocol => canonicalize.canonicalizeProtocol,
        .username => canonicalize.canonicalizeUsername,
        .password => canonicalize.canonicalizePassword,
        .hostname => if (hostnameIsIPv6(input)) canonicalize.canonicalizeIPv6Hostname else canonicalize.canonicalizeHostname,
        .port => portEncoding,
        .pathname => if (special_path) canonicalize.canonicalizePathname else canonicalize.canonicalizeOpaquePathname,
        .search => canonicalize.canonicalizeSearch,
        .hash => canonicalize.canonicalizeHash,
    };
    var parse_result = parser.parsePatternString(allocator, input, options, encoding) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.DuplicateName => return error.DuplicateName,
        else => return error.InvalidPattern,
    };
    defer parse_result.deinit();

    // Step 4: Generate regex and name list
    var gen_result = regex_generator.generateRegexAndNameList(
        allocator,
        parse_result.parts,
        options,
    ) catch |err| switch (err) {
        error.OutOfMemory => return ConstructorError.OutOfMemory,
    };
    // Don't defer deinit - we'll transfer ownership

    // Step 5: Compile the regex (stubbed for now)
    var regex: ?Regex = null;
    if (gen_result.regex.len > 0) {
        regex = Regex.compile(allocator, gen_result.regex, .{
            .caseless = ignore_case,
        }) catch {
            gen_result.deinit();
            return ConstructorError.CompilationFailed;
        };
    }

    // Step 6: Generate pattern string from parts
    const pattern_string = @import("pattern_string.zig").generate(allocator, parse_result.parts, options) catch {
        if (regex) |*r| r.deinit();
        gen_result.deinit();
        return ConstructorError.OutOfMemory;
    };

    // Step 7: Check for regexp groups
    const has_regexp = hasRegexpGroups(parse_result.parts);

    // Transfer ownership of names
    const owned_names = gen_result.name_list;
    gen_result.name_list = &[_][]u8{};

    // Build group_names slice that points to owned names
    const group_names_ptrs = allocator.alloc([]const u8, owned_names.len) catch {
        if (regex) |*r| r.deinit();
        allocator.free(gen_result.regex);
        for (owned_names) |name| allocator.free(name);
        allocator.free(owned_names);
        allocator.free(pattern_string);
        return ConstructorError.OutOfMemory;
    };
    for (owned_names, 0..) |name, i| {
        group_names_ptrs[i] = name;
    }

    return Component{
        .pattern_string = pattern_string,
        .regex = regex,
        .regex_string = gen_result.regex,
        .group_names = group_names_ptrs,
        .has_regexp_groups = has_regexp,
        ._allocator = allocator,
        ._owned_pattern_string = pattern_string,
        ._owned_regex_string = gen_result.regex,
        ._owned_group_names = owned_names,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "URLPattern.create - simple URL string" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{});
    defer pattern.deinit(allocator);

    // Protocol should be "https"
    try std.testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    // Hostname should be "example.com"
    try std.testing.expectEqualStrings("example.com", pattern.hostname.pattern_string);
    // Pathname should be "/path"
    try std.testing.expectEqualStrings("/path", pattern.pathname.pattern_string);
}

test "URLPattern.create - URL with named parameter" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/:id",
    }, .{});
    defer pattern.deinit(allocator);

    // Protocol should be "https"
    try std.testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    // Pathname should have the named parameter
    try std.testing.expect(std.mem.indexOf(u8, pattern.pathname.pattern_string, ":id") != null or
        std.mem.indexOf(u8, pattern.pathname.pattern_string, "id") != null);
}

test "URLPattern.create - from URLPatternInit" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .init = .{
            .protocol = "https",
            .hostname = "*.example.com",
            .pathname = "/api/:version/*",
        },
    }, .{});
    defer pattern.deinit(allocator);

    // Check components
    try std.testing.expectEqualStrings("https", pattern.protocol.pattern_string);
    // Hostname should contain the wildcard
    try std.testing.expect(pattern.hostname.pattern_string.len > 0);
    // Pathname should have named parameter
    try std.testing.expect(pattern.pathname.pattern_string.len > 0);
}

test "URLPattern.create - wildcard patterns" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "*://*/*",
    }, .{});
    defer pattern.deinit(allocator);

    // All wildcards should compile
    try std.testing.expect(pattern.protocol.pattern_string.len > 0);
    try std.testing.expect(pattern.hostname.pattern_string.len > 0);
    try std.testing.expect(pattern.pathname.pattern_string.len > 0);
}

test "URLPattern.create - with search and hash" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path?:query#:section",
    }, .{});
    defer pattern.deinit(allocator);

    // Check that search and hash are captured
    try std.testing.expect(pattern.search.pattern_string.len > 0);
    try std.testing.expect(pattern.hash.pattern_string.len > 0);
}

test "URLPattern.create - relative pathname" {
    // Create step 2.2: relative strings require a base (WPT vectors 216-217).
    try std.testing.expectError(error.InvalidPattern, URLPattern.create(std.testing.allocator, .{
        .string = "/users/:id/posts/:postId",
    }, .{}));
}

test "URLPattern.create - ignore_case option" {
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "https://example.com/path",
    }, .{ .ignore_case = true });
    defer pattern.deinit(allocator);

    try std.testing.expect(pattern.ignore_case);
}

test "Component - has_regexp_groups" {
    const allocator = std.testing.allocator;

    // Pattern with custom regexp
    var pattern1 = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/users/:id(\\d+)",
        },
    }, .{});
    defer pattern1.deinit(allocator);

    try std.testing.expect(pattern1.pathname.has_regexp_groups);

    // Pattern without custom regexp
    var pattern2 = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/users/:id",
        },
    }, .{});
    defer pattern2.deinit(allocator);

    try std.testing.expect(!pattern2.pathname.has_regexp_groups);
}

test "URLPattern.hasRegexpGroups" {
    const allocator = std.testing.allocator;

    var pattern1 = try URLPattern.create(allocator, .{
        .init = .{
            .pathname = "/users/:id(\\d+)",
        },
    }, .{});
    defer pattern1.deinit(allocator);

    try std.testing.expect(pattern1.hasRegexpGroups());

    var pattern2 = try URLPattern.create(allocator, .{
        .string = "https://example.com/*",
    }, .{});
    defer pattern2.deinit(allocator);

    try std.testing.expect(!pattern2.hasRegexpGroups());
}
