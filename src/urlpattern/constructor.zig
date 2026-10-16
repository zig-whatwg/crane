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
//! // Create from URL string, compiling its regexps in `realm`
//! var pattern = try constructor.URLPattern.create(allocator, realm, .{
//!     .string = "https://example.com/:path",
//! }, .{});
//! defer pattern.deinit(allocator);
//!
//! // Create from URLPatternInit
//! var pattern2 = try constructor.URLPattern.create(allocator, realm, .{
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
const regexp_module = @import("regexp.zig");

const URLPatternInit = constructor_string_parser.URLPatternInit;
const Part = parser.Part;
const Options = parser.Options;
const Regexp = regexp_module.Regexp;
const Realm = regexp_module.Realm;

/// Error types for URLPattern construction
pub const ConstructorError = error{
    InvalidPattern,
    InvalidProtocol,
    InvalidHostname,
    InvalidPort,
    InvalidPathname,
    DuplicateName,
    /// The engine cannot compile a regular expression (regexp.zig): the
    /// URLPattern cannot be made. A declared capability gap - the binding
    /// throws a NotSupportedError.
    NotSupported,
    OutOfMemory,
};

/// A compiled URL pattern component
pub const Component = struct {
    /// The pattern string in canonical form
    pattern_string: []const u8,
    /// The component's regular expression: RegExpCreate(regex_string, "v" or
    /// "vi") succeeded for it.
    regexp: Regexp,
    /// The regular expression string "generate a regular expression and
    /// name list" made; `regexp` borrows it.
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
    /// `realm` is the one the regular expressions are compiled in (the
    /// constructor's); BORROWED for the call, never kept.
    pub fn create(allocator: Allocator, realm: Realm, input: Input, options: URLPatternOptions) ConstructorError!Self {
        return createWithBase(allocator, realm, input, null, options);
    }

    pub fn createWithBase(allocator: Allocator, realm: Realm, input: Input, base_url: ?[]const u8, options: URLPatternOptions) ConstructorError!Self {
        // Create, steps 1-3: only string input accepts a separate base URL.
        var init = switch (input) {
            .string => |value| constructor_string_parser.parse(allocator, realm, value) catch |err| return switch (err) {
                error.OutOfMemory => error.OutOfMemory,
                error.NotSupported => error.NotSupported,
                else => error.InvalidPattern,
            },
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

        var protocol = try compileProtocol(allocator, realm, init.protocol.?);
        errdefer protocol.deinit();
        var username = try compileComponent(allocator, realm, init.username.?, .username, false, false);
        errdefer username.deinit();
        var password = try compileComponent(allocator, realm, init.password.?, .password, false, false);
        errdefer password.deinit();
        var hostname = try compileComponent(allocator, realm, init.hostname.?, .hostname, false, false);
        errdefer hostname.deinit();
        var port = try compileComponent(allocator, realm, init.port.?, .port, false, false);
        errdefer port.deinit();
        var pathname = try compileComponent(allocator, realm, init.pathname.?, .pathname, try protocolMatchesSpecialScheme(allocator, realm, &protocol), options.ignore_case);
        errdefer pathname.deinit();
        var search = try compileComponent(allocator, realm, init.search.?, .search, false, options.ignore_case);
        errdefer search.deinit();
        var hash = try compileComponent(allocator, realm, init.hash.?, .hash, false, options.ignore_case);
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
pub fn compileProtocol(allocator: Allocator, realm: Realm, input: []const u8) ConstructorError!Component {
    return compileComponent(allocator, realm, input, .protocol, false, false);
}

/// "Protocol component matches a special scheme": true when
/// RegExpBuiltinExec(the component's regular expression, scheme) is not
/// null for any special scheme (steps 1-3).
pub fn protocolMatchesSpecialScheme(allocator: Allocator, realm: Realm, component: *const Component) ConstructorError!bool {
    // 1. Let special scheme list be a list populated with all of the
    //    special schemes.
    // 2. For each scheme of special scheme list:
    for ([_][]const u8{ "ftp", "file", "http", "https", "ws", "wss" }) |scheme| {
        // 2.1. Let test result be RegExpBuiltinExec(protocol component's
        //      regular expression, scheme).
        // 2.2. If test result is not null, then return true.
        const matched = component.regexp.matches(realm, scheme, allocator) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.NotSupported => error.NotSupported,
            // `create` compiled this string with these flags already.
            error.InvalidPattern => error.InvalidPattern,
        };
        if (matched) return true;
    }
    // 3. Return false.
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
    realm: Realm,
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

    // Steps 3-6: flags "vi" when options' ignore case is true, else "v";
    // RegExpCreate(regular expression string, flags), a throw caught and
    // turned into a TypeError (InvalidPattern, which the binding throws as
    // one). Evaluated now, so an invalid custom regexp fails construction.
    const regexp = Regexp.create(realm, gen_result.regex, ignore_case) catch |err| {
        gen_result.deinit();
        return switch (err) {
            error.InvalidPattern => ConstructorError.InvalidPattern,
            error.NotSupported => ConstructorError.NotSupported,
            error.OutOfMemory => ConstructorError.OutOfMemory,
        };
    };

    // Step 7: Generate pattern string from parts
    const pattern_string = @import("pattern_string.zig").generate(allocator, parse_result.parts, options) catch {
        gen_result.deinit();
        return ConstructorError.OutOfMemory;
    };

    // Steps 8-9: Check for regexp groups
    const has_regexp = hasRegexpGroups(parse_result.parts);

    // Transfer ownership of names
    const owned_names = gen_result.name_list;
    gen_result.name_list = &[_][]u8{};

    // Build group_names slice that points to owned names
    const group_names_ptrs = allocator.alloc([]const u8, owned_names.len) catch {
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
        .regexp = regexp,
        .regex_string = gen_result.regex,
        .group_names = group_names_ptrs,
        .has_regexp_groups = has_regexp,
        ._allocator = allocator,
        ._owned_pattern_string = pattern_string,
        ._owned_regex_string = gen_result.regex,
        ._owned_group_names = owned_names,
    };
}

// Constructing a pattern compiles its regexps in an engine, so the tests
// that construct one live in tests/v8 (urlpattern_constructor_test.zig and
// urlpattern_corpus_test.zig), where there is one.
