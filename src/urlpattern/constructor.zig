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
        // Step 1: Process input to get URLPatternInit
        var init: URLPatternInit = undefined;
        var owns_init = false;

        switch (input) {
            .string => |s| {
                // Parse constructor string
                init = constructor_string_parser.parse(allocator, s) catch {
                    return ConstructorError.InvalidPattern;
                };
                owns_init = true;
            },
            .init => |i| {
                init = i;
            },
        }
        defer if (owns_init) {
            // URLPatternInit doesn't allocate, so nothing to free
        };

        // Step 2: Process each component
        // Apply default patterns for missing components

        // Protocol defaults to "*"
        const protocol_pattern = init.protocol orelse "*";
        var protocol = try compileComponent(
            allocator,
            protocol_pattern,
            .protocol,
            null,
            options.ignore_case,
        );
        errdefer protocol.deinit();

        // Username defaults to "*"
        const username_pattern = init.username orelse "*";
        var username = try compileComponent(
            allocator,
            username_pattern,
            .username,
            null,
            options.ignore_case,
        );
        errdefer username.deinit();

        // Password defaults to "*"
        const password_pattern = init.password orelse "*";
        var password = try compileComponent(
            allocator,
            password_pattern,
            .password,
            null,
            options.ignore_case,
        );
        errdefer password.deinit();

        // Hostname defaults to "*"
        const hostname_pattern = init.hostname orelse "*";
        var hostname = try compileComponent(
            allocator,
            hostname_pattern,
            .hostname,
            null,
            options.ignore_case,
        );
        errdefer hostname.deinit();

        // Port defaults to "*"
        const port_pattern = init.port orelse "*";
        var port = try compileComponent(
            allocator,
            port_pattern,
            .port,
            protocol_pattern,
            options.ignore_case,
        );
        errdefer port.deinit();

        // Pathname defaults to "*" (or "/" for special schemes)
        const pathname_default = if (isSpecialScheme(protocol_pattern)) "/" else "*";
        const pathname_pattern = init.pathname orelse pathname_default;
        var pathname = try compileComponent(
            allocator,
            pathname_pattern,
            .pathname,
            protocol_pattern,
            options.ignore_case,
        );
        errdefer pathname.deinit();

        // Search defaults to "*"
        const search_pattern = init.search orelse "*";
        var search = try compileComponent(
            allocator,
            search_pattern,
            .search,
            null,
            options.ignore_case,
        );
        errdefer search.deinit();

        // Hash defaults to "*"
        const hash_pattern = init.hash orelse "*";
        var hash = try compileComponent(
            allocator,
            hash_pattern,
            .hash,
            null,
            options.ignore_case,
        );
        errdefer hash.deinit();

        return Self{
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

/// Check if a scheme is a "special scheme"
fn isSpecialScheme(scheme: []const u8) bool {
    const special_schemes = [_][]const u8{ "http", "https", "ws", "wss", "ftp", "file" };
    for (special_schemes) |s| {
        if (std.ascii.eqlIgnoreCase(scheme, s)) {
            return true;
        }
    }
    // Also check for wildcard which could match special schemes
    if (std.mem.eql(u8, scheme, "*")) {
        return true;
    }
    return false;
}

/// Get parser options for a component type
fn getParserOptions(component_type: ComponentType) Options {
    return switch (component_type) {
        .hostname => parser.hostname_options,
        .pathname => parser.pathname_options,
        else => parser.default_options,
    };
}

/// Canonicalize a value based on component type
fn canonicalizeValue(
    allocator: Allocator,
    value: []const u8,
    component_type: ComponentType,
    protocol_value: ?[]const u8,
) ConstructorError![]u8 {
    const result = switch (component_type) {
        .protocol => canonicalize.canonicalizeProtocol(allocator, value),
        .username => canonicalize.canonicalizeUsername(allocator, value),
        .password => canonicalize.canonicalizePassword(allocator, value),
        .hostname => canonicalize.canonicalizeHostname(allocator, value),
        .port => canonicalize.canonicalizePort(allocator, value, protocol_value),
        .pathname => canonicalize.canonicalizePathname(allocator, value),
        .search => canonicalize.canonicalizeSearch(allocator, value),
        .hash => canonicalize.canonicalizeHash(allocator, value),
    };

    return result catch |err| switch (err) {
        error.InvalidProtocol => return ConstructorError.InvalidProtocol,
        error.InvalidHostname => return ConstructorError.InvalidHostname,
        error.InvalidIPv6 => return ConstructorError.InvalidHostname,
        error.InvalidPort => return ConstructorError.InvalidPort,
        error.InvalidPathname => return ConstructorError.InvalidPathname,
        error.OutOfMemory => return ConstructorError.OutOfMemory,
    };
}

/// Encoding callback that canonicalizes based on component type
fn makeEncodingCallback(component_type: ComponentType, protocol_value: ?[]const u8) struct {
    component_type: ComponentType,
    protocol_value: ?[]const u8,

    pub fn encode(self: @This(), allocator: Allocator, input: []const u8) Allocator.Error![]u8 {
        // For pattern compilation, we need a simpler encoding that doesn't fail
        // We use identity encoding and let canonicalization happen separately
        _ = self;
        const result = try allocator.alloc(u8, input.len);
        @memcpy(result, input);
        return result;
    }
} {
    return .{
        .component_type = component_type,
        .protocol_value = protocol_value,
    };
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

/// Generate a pattern string from parts
fn generatePatternString(allocator: Allocator, parts: []const Part) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    for (parts) |part| {
        // Add prefix
        try result.appendSlice(allocator, part.prefix);

        switch (part.type) {
            .fixed_text => {
                // Escape special characters in fixed text
                for (part.value) |c| {
                    if (c == ':' or c == '*' or c == '(' or c == ')' or c == '{' or c == '}' or c == '\\') {
                        try result.append(allocator, '\\');
                    }
                    try result.append(allocator, c);
                }
            },
            .segment_wildcard => {
                // :name format
                try result.append(allocator, ':');
                try result.appendSlice(allocator, part.name);
            },
            .full_wildcard => {
                if (part.name.len > 0 and !isNumericName(part.name)) {
                    // :name format with asterisk modifier implied
                    try result.append(allocator, ':');
                    try result.appendSlice(allocator, part.name);
                } else {
                    // * wildcard
                    try result.append(allocator, '*');
                }
            },
            .regexp => {
                // :name(regexp) or (regexp) format
                if (part.name.len > 0 and !isNumericName(part.name)) {
                    try result.append(allocator, ':');
                    try result.appendSlice(allocator, part.name);
                }
                try result.append(allocator, '(');
                try result.appendSlice(allocator, part.value);
                try result.append(allocator, ')');
            },
        }

        // Add suffix
        try result.appendSlice(allocator, part.suffix);

        // Add modifier
        try result.appendSlice(allocator, part.modifier.toString());
    }

    return result.toOwnedSlice(allocator);
}

/// Check if a name is numeric (auto-generated)
fn isNumericName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |c| {
        if (c < '0' or c > '9') return false;
    }
    return true;
}

/// Compile a single URL pattern component
fn compileComponent(
    allocator: Allocator,
    input: []const u8,
    component_type: ComponentType,
    protocol_value: ?[]const u8,
    ignore_case: bool,
) ConstructorError!Component {
    // Step 1: Get parser options based on component type
    const options = getParserOptions(component_type);

    // Step 2: Parse the pattern string
    var parse_result = parser.parsePatternString(
        allocator,
        input,
        options,
        parser.identityEncoding,
    ) catch |err| switch (err) {
        error.InvalidPattern => return ConstructorError.InvalidPattern,
        error.DuplicateName => return ConstructorError.DuplicateName,
        error.OutOfMemory => return ConstructorError.OutOfMemory,
    };
    defer parse_result.deinit();

    // Step 3: Canonicalize fixed text parts
    for (parse_result.parts) |*part| {
        if (part.type == .fixed_text) {
            // Try to canonicalize the value
            const canonical = canonicalizeValue(allocator, part.value, component_type, protocol_value) catch {
                // If canonicalization fails, keep original value
                continue;
            };

            // Update the part with canonical value
            if (part._owned_value) |old| {
                part._allocator.?.free(old);
            }
            part.value = canonical;
            part._owned_value = canonical;
            part._allocator = allocator;
        }
    }

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
    const pattern_string = generatePatternString(allocator, parse_result.parts) catch {
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
    const allocator = std.testing.allocator;

    var pattern = try URLPattern.create(allocator, .{
        .string = "/users/:id/posts/:postId",
    }, .{});
    defer pattern.deinit(allocator);

    // Protocol should be default wildcard
    try std.testing.expectEqualStrings("*", pattern.protocol.pattern_string);
    // Pathname should have the parameters
    try std.testing.expect(pattern.pathname.pattern_string.len > 0);
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
