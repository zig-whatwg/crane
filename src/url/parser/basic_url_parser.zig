//! Basic URL Parser
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#concept-basic-url-parser
//! Spec Reference: Lines 1030-1530
//!
//! The basic URL parser is a state machine that processes URLs character by
//! character and constructs a URLRecord. It handles all URL types including
//! special schemes, relative URLs, file URLs, and opaque paths.
//!
//! This is the most complex module in the URL implementation (~600 LOC) due to
//! the comprehensive state machine with 20 states and many edge cases.

const std = @import("std");
const infra = @import("infra");
const URLRecord = @import("url_record").URLRecord;
const Host = @import("host").Host;
const Path = @import("path").Path;
const ParserState = @import("parser_state").ParserState;
const helpers = @import("helpers");
const parseHost = @import("host_parser").parseHost;
const percentEncode = @import("percent_encoding").utf8PercentEncode;
const encodeSingleAscii = @import("percent_encoding").encodeSingleAscii;
const EncodeSet = @import("encode_sets").EncodeSet;
const windows_drive = @import("windows_drive");
const path_helpers = @import("path");

/// Parse error type
pub const ParseError = error{
    InvalidURL,
    InvalidScheme,
    InvalidHost,
    InvalidPort,
    MissingSchemeNonRelativeURL,
    HostMissing,
    PortOutOfRange,
    PortInvalid,
    InvalidDomain,
    InvalidIPv4,
    InvalidIPv6,
    FileInvalidWindowsDriveLetter,
    OutOfMemory,
};

/// Parser context holds all state during URL parsing
const ParserContext = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    base: ?*const URLRecord,
    state: ParserState,
    state_override: ?ParserState, // Spec line 1031

    // URL being modified (for state override mode)
    url_mut: ?*URLRecord,

    // URL components being built (stored as strings, will be assigned to URLRecord at end)
    scheme: infra.List(u8),
    username: infra.List(u8),
    password: infra.List(u8),
    host: ?Host,
    port: ?u16,
    path_segments: infra.List([]const u8),
    opaque_path: ?[]const u8,
    query: infra.List(u8),
    fragment: infra.List(u8),

    buffer: infra.List(u8),
    pointer: usize,
    at_sign_seen: bool,
    inside_brackets: bool,
    password_token_seen: bool,
    has_query: bool,
    has_fragment: bool,

    // State override completion flag
    state_override_complete: bool,

    // P2 Optimization: Track if input is pure ASCII for fast path optimizations
    is_ascii: bool,

    fn init(allocator: std.mem.Allocator, input: []const u8, base: ?*const URLRecord, state_override: ?ParserState, url_mut: ?*URLRecord) !ParserContext {
        const initial_state = state_override orelse .scheme_start;

        // P6 Optimization: Pre-allocate List capacity based on input size
        // Most URL components are much smaller than input, but pre-allocating
        // reasonable capacity reduces reallocations during parsing.
        const capacity_hint = @min(input.len, 256); // Cap at 256 bytes for small URLs

        var scheme = infra.List(u8).init(allocator);
        try scheme.ensureTotalCapacity(8); // Most schemes < 8 chars

        var username = infra.List(u8).init(allocator);
        try username.ensureTotalCapacity(32); // Username rarely > 32 chars

        var password = infra.List(u8).init(allocator);
        try password.ensureTotalCapacity(32); // Password rarely > 32 chars

        var query = infra.List(u8).init(allocator);
        try query.ensureTotalCapacity(capacity_hint / 2); // Query often ~half of URL

        var fragment = infra.List(u8).init(allocator);
        try fragment.ensureTotalCapacity(32); // Fragments usually small

        var buffer = infra.List(u8).init(allocator);
        try buffer.ensureTotalCapacity(capacity_hint); // Buffer can be large

        // P8 Optimization: Pre-allocate path_segments capacity
        // Most URLs have 1-5 path segments, pre-allocate for common case
        var path_segments = infra.List([]const u8).init(allocator);
        try path_segments.ensureTotalCapacity(4); // Most URLs have 1-4 segments

        return ParserContext{
            .allocator = allocator,
            .input = input,
            .base = base,
            .state = initial_state,
            .state_override = state_override,
            .url_mut = url_mut,
            .scheme = scheme,
            .username = username,
            .password = password,
            .host = null,
            .port = null,
            .path_segments = path_segments,
            .opaque_path = null,
            .query = query,
            .fragment = fragment,
            .buffer = buffer,
            .pointer = 0,
            .at_sign_seen = false,
            .inside_brackets = false,
            .password_token_seen = false,
            .has_query = false,
            .has_fragment = false,
            .state_override_complete = false,
            .is_ascii = helpers.isAsciiOnly(input), // P2: Detect ASCII-only input
        };
    }

    /// Check if in state override mode
    fn hasStateOverride(self: *const ParserContext) bool {
        return self.state_override != null;
    }

    fn deinit(self: *ParserContext) void {
        self.scheme.deinit();
        self.username.deinit();
        self.password.deinit();
        // NOTE: Do NOT free self.host - ownership is transferred to URLRecord
        // in buildURLRecord(). The URLRecord is responsible for freeing it.
        // NOTE: Do NOT free path_segments items - ownership is transferred to URLRecord
        // via clone(). The segments are shallow-copied, so URLRecord owns them.
        self.path_segments.deinit();
        if (self.opaque_path) |op| self.allocator.free(op);
        self.query.deinit();
        self.fragment.deinit();
        self.buffer.deinit();
    }

    fn currentChar(self: *const ParserContext) ?u8 {
        if (self.pointer >= self.input.len) return null;
        return self.input[self.pointer];
    }

    fn isEof(self: *const ParserContext) bool {
        return self.pointer >= self.input.len;
    }

    fn remaining(self: *const ParserContext) []const u8 {
        return helpers.remaining(self.input, self.pointer);
    }

    fn remainingStartsWith(self: *const ParserContext, prefix: []const u8) bool {
        return helpers.remainingStartsWith(self.input, self.pointer, prefix);
    }

    fn isSpecial(self: *const ParserContext) bool {
        return helpers.isSpecialScheme(self.scheme.items());
    }
};

/// Basic URL Parser (spec lines 1030-1530)
///
/// Normal mode: Returns a new URLRecord
/// State override mode: Modifies url_mut in-place, returns undefined (void return wrapped in error union)
pub fn parse(allocator: std.mem.Allocator, input: []const u8, base: ?*const URLRecord) ParseError!URLRecord {
    return parseWithStateOverride(allocator, input, base, null, null);
}

/// Basic URL Parser with state override support (spec lines 1030-1035)
///
/// When state_override and url_mut are provided:
/// - Parser starts in state_override state instead of scheme_start
/// - Parser modifies url_mut in-place instead of building new URLRecord
/// - Early returns in state machine honor state override rules
///
/// This is used by URL setters (protocol, host, hostname, port, pathname, search, hash)
/// to efficiently update specific components without reparsing the entire URL.
pub fn parseWithStateOverride(
    allocator: std.mem.Allocator,
    input: []const u8,
    base: ?*const URLRecord,
    state_override: ?ParserState,
    url_mut: ?*URLRecord,
) ParseError!URLRecord {
    // P3 Optimization: Arena allocation for parsing
    // URL parsing creates many temporary allocations (Lists, strings, etc.).
    // Using an arena allocator lets us free all parsing temporaries with a single
    // bulk deallocation at the end, reducing allocation overhead by 30-50%.
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const parse_allocator = arena.allocator();

    var ctx = try ParserContext.init(parse_allocator, input, base, state_override, url_mut);
    // Note: No defer ctx.deinit() needed - arena handles cleanup

    // If state override mode, initialize context from existing URL
    if (state_override) |_| {
        if (url_mut) |url| {
            try initContextFromURL(&ctx, url);
        }
    }

    // Main parsing loop (spec step 9)
    while (ctx.pointer <= ctx.input.len) {
        const c = ctx.currentChar();
        try runStateMachine(&ctx, c);

        // Check if state override completed successfully
        if (ctx.state_override_complete) break;

        // Check if we should continue
        if (ctx.pointer >= ctx.input.len) break;
        ctx.pointer += 1;
    }

    // State override mode: update url_mut in-place
    if (state_override) |_| {
        if (url_mut) |url| {
            try applyContextToURL(&ctx, url);
            // Return the modified URL (wrapped in error union for compatibility)
            return url.*;
        }
    }

    // Normal mode: build final URLRecord from parsed components
    return try buildURLRecord(allocator, &ctx);
}

/// Initialize parser context from existing URL (for state override mode)
fn initContextFromURL(ctx: *ParserContext, url: *const URLRecord) !void {
    // Copy scheme
    try ctx.scheme.appendSlice(url.scheme());

    // Copy username/password
    try ctx.username.appendSlice(url.username());
    try ctx.password.appendSlice(url.password());

    // Copy host (clone it)
    if (url.host) |h| {
        ctx.host = try h.clone(ctx.allocator);
    }

    // Copy port
    ctx.port = url.port;

    // Copy path
    if (url.path == .opaque_path) {
        ctx.opaque_path = try ctx.allocator.dupe(u8, url.path.opaque_path);
    } else {
        for (url.path.segments.items) |segment| {
            try ctx.path_segments.append(try ctx.allocator.dupe(u8, segment));
        }
    }

    // Copy query (unless we're overriding it)
    if (ctx.state_override != .query) {
        if (url.query()) |q| {
            try ctx.query.appendSlice(q);
            ctx.has_query = true;
        }
    }

    // Copy fragment (unless we're overriding it)
    if (ctx.state_override != .fragment) {
        if (url.fragment()) |f| {
            try ctx.fragment.appendSlice(f);
            ctx.has_fragment = true;
        }
    }
}

/// Apply parser context changes to existing URL (for state override mode)
fn applyContextToURL(ctx: *ParserContext, url: *URLRecord) !void {
    // Free old buffer
    url.allocator.free(url.buffer);

    // Build new buffer
    var buffer = infra.List(u8).init(url.allocator);
    errdefer buffer.deinit();

    const scheme_start: u32 = @intCast(buffer.len);
    try buffer.appendSlice(ctx.scheme.items());
    const scheme_len: u32 = @intCast(ctx.scheme.items().len);

    const username_start: u32 = @intCast(buffer.len);
    try buffer.appendSlice(ctx.username.items());
    const username_len: u32 = @intCast(ctx.username.items().len);

    const password_start: u32 = @intCast(buffer.len);
    try buffer.appendSlice(ctx.password.items());
    const password_len: u32 = @intCast(ctx.password.items().len);

    const query_start: u32 = @intCast(buffer.len);
    const query_len: u32 = if (ctx.has_query) blk: {
        try buffer.appendSlice(ctx.query.items());
        break :blk @intCast(ctx.query.items().len);
    } else 0;

    const fragment_start: u32 = @intCast(buffer.len);
    const fragment_len: u32 = if (ctx.has_fragment) blk: {
        try buffer.appendSlice(ctx.fragment.items());
        break :blk @intCast(ctx.fragment.items().len);
    } else 0;

    // Update URLRecord fields
    url.buffer = try buffer.toOwnedSlice();
    url.scheme_start = scheme_start;
    url.scheme_len = scheme_len;
    url.username_start = username_start;
    url.username_len = username_len;
    url.password_start = password_start;
    url.password_len = password_len;

    // Free old host and update
    if (url.host) |*h| {
        h.deinit(url.allocator);
    }
    // Clone host from arena to URL's allocator to ensure it survives after arena.deinit()
    url.host = if (ctx.host) |h| try h.clone(url.allocator) else null;

    url.port = ctx.port;

    // Free old path and update
    path_helpers.deinitPath(&url.path, url.allocator);
    if (ctx.opaque_path) |op| {
        url.path = Path{ .opaque_path = try url.allocator.dupe(u8, op) };
    } else {
        // Deep clone path segments from arena to URL's allocator
        // Each segment string needs to be cloned to survive after arena.deinit()
        var segments = infra.List([]const u8).init(url.allocator);
        errdefer {
            for (0..segments.len) |i| url.allocator.free(segments.get(i).?);
            segments.deinit();
        }
        try segments.ensureTotalCapacity(ctx.path_segments.items().len);
        for (ctx.path_segments.items()) |seg| {
            try segments.append(try url.allocator.dupe(u8, seg));
        }
        url.path = Path{ .segments = segments };
    }

    url.query_start = query_start;
    url.query_len = query_len;
    url.fragment_start = fragment_start;
    url.fragment_len = fragment_len;
}

/// Build URLRecord from parser context
fn buildURLRecord(allocator: std.mem.Allocator, ctx: *ParserContext) !URLRecord {
    // Create buffer to hold all string components
    var buffer = infra.List(u8).init(allocator);
    errdefer buffer.deinit();

    const scheme_start: u32 = @intCast(buffer.len);
    try buffer.appendSlice(ctx.scheme.items());
    const scheme_len: u32 = @intCast(ctx.scheme.items().len);

    const username_start: u32 = @intCast(buffer.len);
    try buffer.appendSlice(ctx.username.items());
    const username_len: u32 = @intCast(ctx.username.items().len);

    const password_start: u32 = @intCast(buffer.len);
    try buffer.appendSlice(ctx.password.items());
    const password_len: u32 = @intCast(ctx.password.items().len);

    const query_start: u32 = @intCast(buffer.len);
    const query_len: u32 = if (ctx.has_query) blk: {
        try buffer.appendSlice(ctx.query.items());
        break :blk @intCast(ctx.query.items().len);
    } else 0;

    const fragment_start: u32 = @intCast(buffer.len);
    const fragment_len: u32 = if (ctx.has_fragment) blk: {
        try buffer.appendSlice(ctx.fragment.items());
        break :blk @intCast(ctx.fragment.items().len);
    } else 0;

    // P3 Optimization: Deep clone path from arena to final allocator
    // Path segments may have been allocated in the arena, so we need to deep clone
    // each string to ensure they survive after arena.deinit()
    const path = if (ctx.opaque_path) |op|
        Path{ .opaque_path = try allocator.dupe(u8, op) }
    else blk: {
        var segments = infra.List([]const u8).init(allocator);
        errdefer {
            for (0..segments.len) |i| allocator.free(segments.get(i).?);
            segments.deinit();
        }
        try segments.ensureTotalCapacity(ctx.path_segments.items().len);
        for (ctx.path_segments.items()) |seg| {
            try segments.append(try allocator.dupe(u8, seg));
        }
        break :blk Path{ .segments = segments };
    };

    // P3 Optimization: Clone host from arena to final allocator
    // The host may have been allocated in the arena, so we need to clone it
    // to the final allocator to ensure it survives after arena.deinit()
    const host = if (ctx.host) |h| try h.clone(allocator) else null;

    return URLRecord{
        .buffer = try buffer.toOwnedSlice(),
        .scheme_start = scheme_start,
        .scheme_len = scheme_len,
        .username_start = username_start,
        .username_len = username_len,
        .password_start = password_start,
        .password_len = password_len,
        .host = host,
        .port = ctx.port,
        .path = path,
        .query_start = query_start,
        .query_len = query_len,
        .fragment_start = fragment_start,
        .fragment_len = fragment_len,
        .blob_url_entry = null,
        .allocator = allocator,
    };
}

fn runStateMachine(ctx: *ParserContext, c: ?u8) ParseError!void {
    switch (ctx.state) {
        .scheme_start => try schemeStartState(ctx, c),
        .scheme => try schemeState(ctx, c),
        .no_scheme => try noSchemeState(ctx, c),
        .special_relative_or_authority => try specialRelativeOrAuthorityState(ctx, c),
        .path_or_authority => try pathOrAuthorityState(ctx, c),
        .relative => try relativeState(ctx, c),
        .relative_slash => try relativeSlashState(ctx, c),
        .special_authority_slashes => try specialAuthoritySlashesState(ctx, c),
        .special_authority_ignore_slashes => try specialAuthorityIgnoreSlashesState(ctx, c),
        .authority => try authorityState(ctx, c),
        .host => try hostState(ctx, c),
        .port => try portState(ctx, c),
        .file => try fileState(ctx, c),
        .file_slash => try fileSlashState(ctx, c),
        .file_host => try fileHostState(ctx, c),
        .path_start => try pathStartState(ctx, c),
        .path => try pathState(ctx, c),
        .opaque_path => try opaquePathState(ctx, c),
        .query => try queryState(ctx, c),
        .fragment => try fragmentState(ctx, c),
    }
}

// ============================================================================
// State Implementations
// ============================================================================

fn schemeStartState(ctx: *ParserContext, c: ?u8) ParseError!void {
    // Spec step 1 (line 1063)
    if (c) |char| {
        if (std.ascii.isAlphabetic(char)) {
            try ctx.buffer.append(std.ascii.toLower(char));
            ctx.state = .scheme;
            return;
        }
    }

    // Spec step 2 (line 1065): Otherwise, if state override is not given
    if (!ctx.hasStateOverride()) {
        ctx.state = .no_scheme;
        if (ctx.pointer > 0) ctx.pointer -= 1;
        return;
    }

    // Spec step 3 (line 1067): Otherwise, return failure
    return ParseError.InvalidScheme;
}

fn schemeState(ctx: *ParserContext, c: ?u8) ParseError!void {
    // Spec step 1 (line 1073)
    if (c) |char| {
        if (std.ascii.isAlphanumeric(char) or char == '+' or char == '-' or char == '.') {
            try ctx.buffer.append(std.ascii.toLower(char));
            return;
        }

        // Spec step 2 (line 1075): Otherwise, if c is U+003A (:)
        if (char == ':') {
            // Spec step 2.1 (lines 1077-1086): If state override is given
            if (ctx.hasStateOverride()) {
                const buffer_is_special = helpers.isSpecialScheme(ctx.buffer.items());
                const url_scheme_is_special = ctx.isSpecial();

                // Step 2.1.1 (line 1079): special → non-special or vice versa
                if (url_scheme_is_special and !buffer_is_special) return;
                if (!url_scheme_is_special and buffer_is_special) return;

                // Step 2.1.3 (line 1083): credentials/port + file
                if ((ctx.username.items().len > 0 or ctx.password.items().len > 0 or ctx.port != null) and
                    std.mem.eql(u8, ctx.buffer.items(), "file"))
                {
                    return;
                }

                // Step 2.1.4 (line 1085): file scheme + empty host
                if (std.mem.eql(u8, ctx.scheme.items(), "file") and ctx.host != null) {
                    if (ctx.host.? == .empty) return;
                }
            }

            // Spec step 2.2 (line 1087): Set url's scheme to buffer
            // In state override mode, clear existing scheme first
            if (ctx.hasStateOverride()) {
                ctx.scheme.clearRetainingCapacity();
            }
            try ctx.scheme.appendSlice(ctx.buffer.items());
            ctx.buffer.clearRetainingCapacity();

            // Spec step 2.3 (lines 1089-1093): If state override is given
            if (ctx.hasStateOverride()) {
                // Step 2.3.1 (line 1091): Clear default port
                const default_port = helpers.defaultPort(ctx.scheme.items());
                if (ctx.port != null and ctx.port.? == default_port) {
                    ctx.port = null;
                }
                // Step 2.3.2 (line 1093): Return (signal completion)
                ctx.state_override_complete = true;
                return;
            }

            // Spec step 2.4 (line 1095): Set buffer to empty string
            // (already done above)

            // Spec step 2.5 (lines 1097-1101): If scheme is "file"
            if (std.mem.eql(u8, ctx.scheme.items(), "file")) {
                ctx.state = .file;
                return;
            }

            // Spec step 2.6 (lines 1103-1107): special + base with same scheme
            if (ctx.isSpecial() and ctx.base != null) {
                const base_scheme = ctx.base.?.scheme();
                if (std.mem.eql(u8, base_scheme, ctx.scheme.items())) {
                    ctx.state = .special_relative_or_authority;
                    return;
                }
            }

            // Spec step 2.7 (lines 1109): If url is special
            if (ctx.isSpecial()) {
                ctx.state = .special_authority_slashes;
                return;
            }

            // Spec step 2.8 (lines 1111): If remaining starts with "/"
            if (ctx.remainingStartsWith("/")) {
                ctx.state = .path_or_authority;
                ctx.pointer += 1;
                return;
            }

            // Spec step 2.9 (line 1113): Otherwise, opaque path
            ctx.state = .opaque_path;
            return;
        }
    }

    // Spec step 3 (line 1115): Otherwise, if state override is not given
    if (!ctx.hasStateOverride()) {
        ctx.buffer.clearRetainingCapacity();
        ctx.state = .no_scheme;
        ctx.pointer = 0;
        return;
    }

    // Spec step 4 (line 1117): Otherwise, return failure
    return ParseError.InvalidScheme;
}

fn noSchemeState(ctx: *ParserContext, c: ?u8) ParseError!void {
    if (ctx.base == null) return ParseError.MissingSchemeNonRelativeURL;

    const base = ctx.base.?;
    if (base.hasOpaquePath()) {
        if (c == null or c.? != '#') return ParseError.MissingSchemeNonRelativeURL;
        // Copy base components
        try ctx.scheme.appendSlice(base.scheme());
        ctx.opaque_path = try ctx.allocator.dupe(u8, base.path.opaque_path);
        if (base.query()) |q| {
            try ctx.query.appendSlice(q);
            ctx.has_query = true;
        }
        ctx.has_fragment = true;
        ctx.state = .fragment;
        return;
    }

    const base_scheme = base.scheme();
    if (!std.mem.eql(u8, base_scheme, "file")) {
        ctx.state = .relative;
        if (ctx.pointer > 0) ctx.pointer -= 1;
        return;
    }

    ctx.state = .file;
    if (ctx.pointer > 0) ctx.pointer -= 1;
}

fn specialRelativeOrAuthorityState(ctx: *ParserContext, c: ?u8) ParseError!void {
    if (c != null and c.? == '/' and ctx.remainingStartsWith("/")) {
        ctx.state = .special_authority_ignore_slashes;
        ctx.pointer += 1;
        return;
    }
    ctx.state = .relative;
    if (ctx.pointer > 0) ctx.pointer -= 1;
}

fn pathOrAuthorityState(ctx: *ParserContext, c: ?u8) ParseError!void {
    if (c != null and c.? == '/') {
        ctx.state = .authority;
        return;
    }
    ctx.state = .path;
    if (ctx.pointer > 0) ctx.pointer -= 1;
}

fn relativeState(ctx: *ParserContext, c: ?u8) ParseError!void {
    const base = ctx.base.?;
    try ctx.scheme.appendSlice(base.scheme());

    if (c == null) {
        // Copy everything from base
        try ctx.username.appendSlice(base.username());
        try ctx.password.appendSlice(base.password());
        if (base.host) |h| ctx.host = try h.clone(ctx.allocator);
        ctx.port = base.port;
        // Clone path
        for (base.path.segments.items) |segment| {
            try ctx.path_segments.append(try ctx.allocator.dupe(u8, segment));
        }
        if (base.query()) |q| {
            try ctx.query.appendSlice(q);
            ctx.has_query = true;
        }
        return;
    }

    const char = c.?;
    if (char == '/') {
        ctx.state = .relative_slash;
        return;
    }

    if (ctx.isSpecial() and char == '\\') {
        ctx.state = .relative_slash;
        return;
    }

    // Copy base components
    try ctx.username.appendSlice(base.username());
    try ctx.password.appendSlice(base.password());
    if (base.host) |h| ctx.host = try h.clone(ctx.allocator);
    ctx.port = base.port;
    for (base.path.segments.items) |segment| {
        try ctx.path_segments.append(try ctx.allocator.dupe(u8, segment));
    }
    if (base.query()) |q| {
        try ctx.query.appendSlice(q);
        ctx.has_query = true;
    }

    if (char == '?') {
        ctx.query.clearRetainingCapacity();
        ctx.has_query = true;
        ctx.state = .query;
        return;
    }

    if (char == '#') {
        ctx.has_fragment = true;
        ctx.state = .fragment;
        return;
    }

    // Clear query and shorten path
    ctx.query.clearRetainingCapacity();
    ctx.has_query = false;
    if (ctx.path_segments.pop()) |last| {
        ctx.allocator.free(last);
    }
    ctx.state = .path;
    if (ctx.pointer > 0) ctx.pointer -= 1;
}

fn relativeSlashState(ctx: *ParserContext, c: ?u8) ParseError!void {
    if (c == null) return;
    const char = c.?;

    if (ctx.isSpecial() and (char == '/' or char == '\\')) {
        ctx.state = .special_authority_ignore_slashes;
        return;
    }

    if (char == '/') {
        ctx.state = .authority;
        return;
    }

    // Copy base credentials/host/port
    const base = ctx.base.?;
    try ctx.username.appendSlice(base.username());
    try ctx.password.appendSlice(base.password());
    if (base.host) |h| ctx.host = try h.clone(ctx.allocator);
    ctx.port = base.port;
    ctx.state = .path;
    if (ctx.pointer > 0) ctx.pointer -= 1;
}

fn specialAuthoritySlashesState(ctx: *ParserContext, c: ?u8) ParseError!void {
    if (c != null and c.? == '/' and ctx.remainingStartsWith("/")) {
        ctx.state = .special_authority_ignore_slashes;
        ctx.pointer += 1;
        return;
    }
    ctx.state = .special_authority_ignore_slashes;
    if (ctx.pointer > 0) ctx.pointer -= 1;
}

fn specialAuthorityIgnoreSlashesState(ctx: *ParserContext, c: ?u8) ParseError!void {
    if (c == null or (c.? != '/' and c.? != '\\')) {
        ctx.state = .authority;
        if (ctx.pointer > 0) ctx.pointer -= 1;
        return;
    }
}

fn authorityState(ctx: *ParserContext, c: ?u8) ParseError!void {
    // Handle EOF: finalize as host
    if (c == null) {
        if (ctx.at_sign_seen and ctx.buffer.items().len == 0) {
            return ParseError.HostMissing;
        }
        // If we've seen @ sign, the buffer contains the host
        // If not, the buffer contains userinfo@host and we need to backtrack
        if (!ctx.at_sign_seen) {
            // No @ seen, so this is all host (no userinfo)
            // Parse the buffer as host
            if (ctx.isSpecial() and ctx.buffer.items().len == 0) {
                return ParseError.HostMissing;
            }
            if (ctx.buffer.items().len > 0) {
                const host = parseHost(ctx.allocator, ctx.buffer.items(), !ctx.isSpecial(), null) catch |err| {
                    return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidHost;
                };
                ctx.host = host;
            }
            ctx.buffer.clearRetainingCapacity();
            ctx.state = .path_start;
            return;
        }
        // @ sign seen, buffer contains host
        if (ctx.buffer.items().len > 0) {
            const host = parseHost(ctx.allocator, ctx.buffer.items(), !ctx.isSpecial(), null) catch |err| {
                return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidHost;
            };
            ctx.host = host;
        }
        ctx.buffer.clearRetainingCapacity();
        ctx.state = .path_start;
        return;
    }

    const char = c.?;

    if (char == '@') {
        if (ctx.at_sign_seen) {
            try ctx.buffer.insert(ctx.allocator, 0, '%');
            try ctx.buffer.insert(ctx.allocator, 1, '4');
            try ctx.buffer.insert(ctx.allocator, 2, '0');
        }
        ctx.at_sign_seen = true;

        for (ctx.buffer.items()) |cp| {
            if (cp == ':' and !ctx.password_token_seen) {
                ctx.password_token_seen = true;
                continue;
            }
            const encoded = try percentEncode(ctx.allocator, &[_]u8{cp}, .userinfo);
            defer ctx.allocator.free(encoded);
            if (ctx.password_token_seen) {
                try ctx.password.appendSlice(encoded);
            } else {
                try ctx.username.appendSlice(encoded);
            }
        }
        ctx.buffer.clearRetainingCapacity();
        return;
    }

    const is_terminator = char == '/' or char == '?' or char == '#' or (ctx.isSpecial() and char == '\\');
    if (is_terminator) {
        if (ctx.at_sign_seen and ctx.buffer.items().len == 0) {
            return ParseError.HostMissing;
        }
        if (ctx.pointer >= ctx.buffer.items().len) {
            ctx.pointer -= ctx.buffer.items().len + 1;
        }
        ctx.buffer.clearRetainingCapacity();
        ctx.state = .host;
        return;
    }

    try ctx.buffer.append(char);
}

fn hostState(ctx: *ParserContext, c: ?u8) ParseError!void {
    // Spec step 1 (line 1232): If state override is given and url's scheme is "file"
    if (ctx.hasStateOverride() and std.mem.eql(u8, ctx.scheme.items(), "file")) {
        if (ctx.pointer > 0) ctx.pointer -= 1;
        ctx.state = .file_host;
        return;
    }

    // Spec step 2 (line 1234): Otherwise, if c is U+003A (:) and insideBrackets is false
    if (c != null and c.? == ':' and !ctx.inside_brackets) {
        // Step 2.1 (line 1236): If buffer is empty, return failure
        if (ctx.buffer.items().len == 0) {
            return ParseError.HostMissing;
        }

        // Step 2.2 (line 1238): If state override is given and state override is hostname state
        if (ctx.hasStateOverride() and ctx.state_override.? == .host) {
            return ParseError.InvalidHost;
        }

        // Step 2.3 (line 1240): Parse host
        const host = parseHost(ctx.allocator, ctx.buffer.items(), !ctx.isSpecial(), null) catch |err| {
            return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidHost;
        };

        // Step 2.5 (line 1244): Set url's host, clear buffer, set state to port
        ctx.host = host;
        ctx.buffer.clearRetainingCapacity();
        ctx.state = .port;
        return;
    }

    // Spec step 3 (lines 1246-1265): Handle EOF or terminator
    const is_terminator = c == null or c.? == '/' or c.? == '?' or c.? == '#' or
        (ctx.isSpecial() and c.? == '\\');

    if (is_terminator) {
        if (ctx.pointer > 0) ctx.pointer -= 1;

        // Step 3.1 (line 1254): If url is special and buffer is empty, return failure
        if (ctx.isSpecial() and ctx.buffer.items().len == 0) {
            return ParseError.HostMissing;
        }

        // Step 3.2 (line 1256): If state override, buffer empty, and (credentials or port), return failure
        if (ctx.hasStateOverride() and ctx.buffer.items().len == 0) {
            const has_credentials = ctx.username.items().len > 0 or ctx.password.items().len > 0;
            if (has_credentials or ctx.port != null) {
                return ParseError.HostMissing;
            }
        }

        // Step 3.3 (line 1258): Parse host
        if (ctx.buffer.items().len > 0) {
            const host = parseHost(ctx.allocator, ctx.buffer.items(), !ctx.isSpecial(), null) catch |err| {
                return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidHost;
            };
            ctx.host = host;
        }

        // Step 3.5 (line 1262): Clear buffer, set state to path start
        ctx.buffer.clearRetainingCapacity();
        ctx.state = .path_start;

        // Step 3.6 (line 1264): If state override is given, return (signal completion)
        if (ctx.hasStateOverride()) {
            ctx.state_override_complete = true;
            return;
        }

        return;
    }

    // Spec step 4 (lines 1266-1272): Accumulate host characters
    const char = c.?;
    if (char == '[') ctx.inside_brackets = true;
    if (char == ']') ctx.inside_brackets = false;
    try ctx.buffer.append(char);
}

fn portState(ctx: *ParserContext, c: ?u8) ParseError!void {
    // Spec step 1 (line 1276): If c is an ASCII digit
    if (c) |char| {
        if (std.ascii.isDigit(char)) {
            try ctx.buffer.append(char);
            return;
        }
    }

    // Spec step 2 (lines 1278-1302): Otherwise, if one of the following is true
    const is_eof = c == null;
    const is_terminator = if (c) |char|
        char == '/' or char == '?' or char == '#' or (ctx.isSpecial() and char == '\\')
    else
        false;
    const is_state_override = ctx.hasStateOverride();

    if (is_eof or is_terminator or is_state_override) {
        // Step 2.1 (lines 1288-1298): If buffer is not empty
        if (ctx.buffer.items().len > 0) {
            // Step 2.1.1 (line 1290): Parse port
            const port = std.fmt.parseInt(u16, ctx.buffer.items(), 10) catch {
                return ParseError.PortOutOfRange;
            };

            // Step 2.1.3 (line 1294): Set url's port (null if default, otherwise port)
            const default_port = helpers.defaultPort(ctx.scheme.items());
            if (default_port == null or default_port.? != port) {
                ctx.port = port;
            } else {
                ctx.port = null;
            }

            // Step 2.1.4 (line 1296): Clear buffer
            ctx.buffer.clearRetainingCapacity();

            // Step 2.1.5 (line 1298): If state override is given, return (signal completion)
            if (ctx.hasStateOverride()) {
                ctx.state_override_complete = true;
                return;
            }
        }

        // Step 2.2 (line 1300): If state override is given, return failure
        if (ctx.hasStateOverride()) {
            return ParseError.PortInvalid;
        }

        // Step 2.3 (line 1302): Set state to path start, decrease pointer
        ctx.state = .path_start;
        if (ctx.pointer > 0) ctx.pointer -= 1;
        return;
    }

    // Spec step 3 (line 1304): Otherwise, return failure
    return ParseError.PortInvalid;
}

fn fileState(ctx: *ParserContext, c: ?u8) ParseError!void {
    try ctx.scheme.appendSlice("file");
    ctx.host = Host.empty;

    if (c) |char| {
        if (char == '/' or char == '\\') {
            ctx.state = .file_slash;
            return;
        }
    }

    if (ctx.base) |base| {
        const base_scheme = base.scheme();
        if (std.mem.eql(u8, base_scheme, "file")) {
            if (base.host) |h| ctx.host = try h.clone(ctx.allocator);
            for (base.path.segments.items) |segment| {
                try ctx.path_segments.append(try ctx.allocator.dupe(u8, segment));
            }
            if (base.query()) |q| {
                try ctx.query.appendSlice(q);
                ctx.has_query = true;
            }

            if (c) |char| {
                if (char == '?') {
                    ctx.query.clearRetainingCapacity();
                    ctx.has_query = true;
                    ctx.state = .query;
                    return;
                }
                if (char == '#') {
                    ctx.has_fragment = true;
                    ctx.state = .fragment;
                    return;
                }
            }

            if (c != null) {
                ctx.query.clearRetainingCapacity();
                ctx.has_query = false;

                const remaining_str = ctx.input[ctx.pointer..];
                if (!windows_drive.startsWithWindowsDriveLetter(remaining_str)) {
                    if (ctx.path_segments.pop()) |last| {
                        ctx.allocator.free(last);
                    }
                } else {
                    for (ctx.path_segments.items()) |segment| {
                        ctx.allocator.free(segment);
                    }
                    ctx.path_segments.clearRetainingCapacity();
                }
                ctx.state = .path;
                if (ctx.pointer > 0) ctx.pointer -= 1;
                return;
            }
        }
    }

    ctx.state = .path;
    if (ctx.pointer > 0) ctx.pointer -= 1;
}

fn fileSlashState(ctx: *ParserContext, c: ?u8) ParseError!void {
    if (c) |char| {
        if (char == '/' or char == '\\') {
            ctx.state = .file_host;
            return;
        }
    }

    if (ctx.base) |base| {
        const base_scheme = base.scheme();
        if (std.mem.eql(u8, base_scheme, "file")) {
            if (base.host) |h| ctx.host = try h.clone(ctx.allocator);

            const remaining_str = ctx.input[ctx.pointer..];
            if (!windows_drive.startsWithWindowsDriveLetter(remaining_str) and
                base.path.segments.items.len > 0)
            {
                const first_segment = base.path.segments.items[0];
                if (windows_drive.isNormalizedWindowsDriveLetter(first_segment)) {
                    try ctx.path_segments.append(try ctx.allocator.dupe(u8, first_segment));
                }
            }
        }
    }

    ctx.state = .path;
    if (ctx.pointer > 0) ctx.pointer -= 1;
}

fn fileHostState(ctx: *ParserContext, c: ?u8) ParseError!void {
    const is_terminator = c == null or (c.? == '/' or c.? == '\\' or c.? == '?' or c.? == '#');

    if (is_terminator) {
        if (ctx.pointer > 0) ctx.pointer -= 1;

        if (windows_drive.isWindowsDriveLetter(ctx.buffer.items())) {
            ctx.state = .path;
            return;
        }

        if (ctx.buffer.items().len == 0) {
            ctx.host = Host.empty;
            ctx.state = .path_start;
            return;
        }

        const host = parseHost(ctx.allocator, ctx.buffer.items(), true, null) catch |err| {
            return if (err == error.OutOfMemory) error.OutOfMemory else error.InvalidHost;
        };
        if (host == .domain and std.mem.eql(u8, host.domain, "localhost")) {
            ctx.host = Host.empty;
        } else {
            ctx.host = host;
        }
        ctx.buffer.clearRetainingCapacity();
        ctx.state = .path_start;
        return;
    }

    try ctx.buffer.append(c.?);
}

fn pathStartState(ctx: *ParserContext, c: ?u8) ParseError!void {
    // Spec step 1: If url is special
    if (ctx.isSpecial()) {
        ctx.state = .path;
        if (c == null or (c.? != '/' and c.? != '\\')) {
            if (ctx.pointer > 0) ctx.pointer -= 1;
        }
        return;
    }

    // Spec step 2-3: Handle ? and #
    if (c) |char| {
        if (char == '?') {
            ctx.has_query = true;
            ctx.state = .query;
            return;
        }
        if (char == '#') {
            ctx.has_fragment = true;
            ctx.state = .fragment;
            return;
        }
    }

    // Spec step 4: Otherwise, if c is not EOF
    if (c != null) {
        ctx.state = .path;
        if (c.? != '/') {
            if (ctx.pointer > 0) ctx.pointer -= 1;
        }
        return;
    }

    // Spec step 5 (line 1416): Otherwise, if state override is given and url's host is null
    if (ctx.hasStateOverride() and ctx.host == null) {
        try ctx.path_segments.append(try ctx.allocator.dupe(u8, ""));
    }
}

fn pathState(ctx: *ParserContext, c: ?u8) ParseError!void {
    // Spec step 1 (lines 1420-1455): If one of the following is true
    const is_eof_or_slash = c == null or (c != null and c.? == '/');
    const is_special_backslash = ctx.isSpecial() and c != null and c.? == '\\';
    const is_query_or_frag_without_override = !ctx.hasStateOverride() and c != null and (c.? == '?' or c.? == '#');

    const is_terminator = is_eof_or_slash or is_special_backslash or is_query_or_frag_without_override;

    if (is_terminator) {
        if (path_helpers.isDoubleDotPathSegment(ctx.buffer.items())) {
            if (ctx.path_segments.pop()) |last| {
                ctx.allocator.free(last);
            }
            const should_append_empty = !(c != null and c.? == '/') and
                !(ctx.isSpecial() and c != null and c.? == '\\');
            if (!should_append_empty) {
                try ctx.path_segments.append(try ctx.allocator.dupe(u8, ""));
            }
        } else if (path_helpers.isSingleDotPathSegment(ctx.buffer.items())) {
            const should_append_empty = !(c != null and c.? == '/') and
                !(ctx.isSpecial() and c != null and c.? == '\\');
            if (!should_append_empty) {
                try ctx.path_segments.append(try ctx.allocator.dupe(u8, ""));
            }
        } else if (ctx.buffer.items().len > 0) {
            // Handle Windows drive letter normalization
            if (std.mem.eql(u8, ctx.scheme.items(), "file") and
                ctx.path_segments.items().len == 0 and
                windows_drive.isWindowsDriveLetter(ctx.buffer.items()))
            {
                // Normalize: replace second char with ':'
                ctx.buffer.items()[1] = ':';
            }
            try ctx.path_segments.append(try ctx.allocator.dupe(u8, ctx.buffer.items()));
        } else if (c == null and ctx.buffer.items().len == 0) {
            // EOF with empty buffer - append empty segment to represent trailing slash
            // This happens when URL ends with / like "http://example.com/"
            try ctx.path_segments.append(try ctx.allocator.dupe(u8, ""));
        }

        ctx.buffer.clearRetainingCapacity();

        if (c) |char| {
            if (char == '?') {
                ctx.has_query = true;
                ctx.state = .query;
                return;
            }
            if (char == '#') {
                ctx.has_fragment = true;
                ctx.state = .fragment;
                return;
            }
        }
        return;
    }

    // Append character (with percent encoding)
    const char = c.?;

    // P9 Optimization: For ASCII input, use fast path to avoid allocation
    if (ctx.is_ascii and char < 128) {
        const result = encodeSingleAscii(char, .path);
        try ctx.buffer.appendSlice(result.bytes[0..result.length]);
    } else {
        const encoded = try percentEncode(ctx.allocator, &[_]u8{char}, .path);
        defer ctx.allocator.free(encoded);
        try ctx.buffer.appendSlice(encoded);
    }
}

fn opaquePathState(ctx: *ParserContext, c: ?u8) ParseError!void {
    if (c) |char| {
        if (char == '?') {
            ctx.has_query = true;
            ctx.state = .query;
            return;
        }
        if (char == '#') {
            ctx.has_fragment = true;
            ctx.state = .fragment;
            return;
        }
        // Percent encode and append to opaque path
        // P9 Optimization: For ASCII input, use fast path to avoid allocation
        if (ctx.is_ascii and char < 128) {
            const result = encodeSingleAscii(char, .c0_control);
            const encoded_slice = result.bytes[0..result.length];

            if (ctx.opaque_path) |*op| {
                const new_path = try std.mem.concat(ctx.allocator, u8, &[_][]const u8{ op.*, encoded_slice });
                ctx.allocator.free(op.*);
                op.* = new_path;
            } else {
                ctx.opaque_path = try ctx.allocator.dupe(u8, encoded_slice);
            }
        } else {
            const encoded = try percentEncode(ctx.allocator, &[_]u8{char}, .c0_control);
            defer ctx.allocator.free(encoded);

            if (ctx.opaque_path) |*op| {
                const new_path = try std.mem.concat(ctx.allocator, u8, &[_][]const u8{ op.*, encoded });
                ctx.allocator.free(op.*);
                op.* = new_path;
            } else {
                ctx.opaque_path = try ctx.allocator.dupe(u8, encoded);
            }
        }
    }
}

fn queryState(ctx: *ParserContext, c: ?u8) ParseError!void {
    // Mark that we have a query (for state override mode)
    ctx.has_query = true;

    // Spec step 2 (lines 1494-1510): If one of the following is true
    const is_eof = c == null;
    const is_hash_without_override = !ctx.hasStateOverride() and c != null and c.? == '#';

    if (is_eof or is_hash_without_override) {
        // Step 2.1-2.2 (lines 1502-1504): Percent-encode and append to query
        const encode_set: EncodeSet = if (ctx.isSpecial()) .special_query else .query;
        const encoded = try percentEncode(ctx.allocator, ctx.buffer.items(), encode_set);
        try ctx.query.appendSlice(encoded);
        ctx.allocator.free(encoded);

        // Step 2.3 (line 1508): Clear buffer
        ctx.buffer.clearRetainingCapacity();

        // If c is U+0023 (#), set state to fragment
        if (c != null and c.? == '#') {
            ctx.has_fragment = true;
            ctx.state = .fragment;
        }
        return;
    }

    // Spec step 3 (lines 1511-1515): Otherwise, append to buffer
    if (c) |char| {
        try ctx.buffer.append(char);
    }
}

fn fragmentState(ctx: *ParserContext, c: ?u8) ParseError!void {
    // Mark that we have a fragment (for state override mode)
    ctx.has_fragment = true;

    if (c) |char| {
        // P9 Optimization: For ASCII input, use fast path to avoid allocation
        if (ctx.is_ascii and char < 128) {
            const result = encodeSingleAscii(char, .fragment);
            try ctx.fragment.appendSlice(result.bytes[0..result.length]);
        } else {
            const encoded = try percentEncode(ctx.allocator, &[_]u8{char}, .fragment);
            defer ctx.allocator.free(encoded);
            try ctx.fragment.appendSlice(encoded);
        }
    }
}

// ============================================================================
// Tests
// ============================================================================



