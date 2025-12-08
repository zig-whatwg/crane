//! URLPattern Constructor String Parser
//!
//! WHATWG URLPattern Standard: https://urlpattern.spec.whatwg.org/#constructor-string-parsing
//! Spec Reference: Section 1.6 Constructor string parsing
//!
//! This module implements the "parse a constructor string" algorithm which parses
//! shorthand URL pattern strings like "https://example.com/:path" into URLPatternInit
//! with individual component patterns.
//!
//! ## Usage
//!
//! ```zig
//! const csp = @import("constructor_string_parser.zig");
//!
//! const init = try csp.parse(allocator, "https://example.com/:path");
//! defer init.deinit(allocator);
//!
//! // init.protocol == "https"
//! // init.hostname == "example.com"
//! // init.pathname == "/:path"
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const tokenizer = @import("tokenizer.zig");
const Token = tokenizer.Token;
const TokenType = tokenizer.TokenType;
const Tokenizer = tokenizer.Tokenizer;
const TokenizePolicy = tokenizer.TokenizePolicy;

// Import canonicalization functions (needed for protocol matching)
const canonicalize = @import("canonicalize.zig");

/// Parser states as defined in the URLPattern spec
pub const State = enum {
    /// Initial state
    init,
    /// Parsing protocol component
    protocol,
    /// Looking for username/password or hostname
    authority,
    /// Parsing username component
    username,
    /// Parsing password component
    password,
    /// Parsing hostname component
    hostname,
    /// Parsing port component
    port,
    /// Parsing pathname component
    pathname,
    /// Parsing search/query component
    search,
    /// Parsing hash/fragment component
    hash,
    /// Parsing complete
    done,
};

/// URLPatternInit dictionary
/// Contains the individual pattern strings for each URL component
pub const URLPatternInit = struct {
    protocol: ?[]const u8 = null,
    username: ?[]const u8 = null,
    password: ?[]const u8 = null,
    hostname: ?[]const u8 = null,
    port: ?[]const u8 = null,
    pathname: ?[]const u8 = null,
    search: ?[]const u8 = null,
    hash: ?[]const u8 = null,
    base_url: ?[]const u8 = null,

    _allocator: ?Allocator = null,

    pub fn deinit(self: *URLPatternInit, allocator: Allocator) void {
        _ = allocator;
        _ = self._allocator;
        // Note: The slices point into the original input string,
        // so we don't need to free them individually.
        // If we had allocated copies, we would free them here.
    }
};

/// Constructor string parser state machine
pub const ConstructorStringParser = struct {
    /// Input pattern string
    input: []const u8,
    /// Token list from tokenizer (slice into owned array)
    token_list: []const Token,
    /// Owned token array
    _owned_tokens: []Token,
    /// Result URLPatternInit
    result: URLPatternInit,
    /// Start position of current component
    component_start: usize,
    /// Current token index
    token_index: usize,
    /// Token increment (usually 1, sometimes 0)
    token_increment: usize,
    /// Group depth for {...} tracking
    group_depth: usize,
    /// IPv6 bracket depth for hostname
    hostname_ipv6_bracket_depth: usize,
    /// Whether protocol matches a special scheme
    protocol_matches_special_scheme: bool,
    /// Current parser state
    state: State,

    allocator: Allocator,

    const Self = @This();

    /// Initialize a new constructor string parser
    pub fn init(allocator: Allocator, input: []const u8) !Self {
        // Tokenize input with lenient policy
        var tok = Tokenizer.init(allocator, input, .lenient);
        errdefer tok.deinit();
        try tok.tokenize();

        const tokens = try tok.toOwnedSlice();

        return Self{
            .input = input,
            .token_list = tokens,
            ._owned_tokens = tokens,
            .result = URLPatternInit{},
            .component_start = 0,
            .token_index = 0,
            .token_increment = 1,
            .group_depth = 0,
            .hostname_ipv6_bracket_depth = 0,
            .protocol_matches_special_scheme = false,
            .state = .init,
            .allocator = allocator,
        };
    }

    /// Free resources
    pub fn deinit(self: *Self) void {
        self.allocator.free(self._owned_tokens);
    }

    /// Parse the constructor string and return URLPatternInit
    pub fn parse(allocator: Allocator, input: []const u8) !URLPatternInit {
        var parser = try Self.init(allocator, input);
        defer parser.deinit();

        try parser.run();
        return parser.result;
    }

    /// Run the parser state machine
    fn run(self: *Self) !void {
        while (self.token_index < self.token_list.len) {
            // Reset token increment at top of loop
            self.token_increment = 1;

            const current_token = self.token_list[self.token_index];

            // Handle end token
            if (current_token.type == .end) {
                switch (self.state) {
                    .init => {
                        // Failed to find protocol terminator - this is a relative pattern
                        self.rewind();

                        if (self.isHashPrefix()) {
                            self.changeState(.hash, 1);
                        } else if (self.isSearchPrefix()) {
                            self.changeState(.search, 1);
                        } else {
                            self.changeState(.pathname, 0);
                        }
                        self.token_index += self.token_increment;
                        continue;
                    },
                    .authority => {
                        // No @ found, so no username/password
                        self.rewindAndSetState(.hostname);
                        self.token_index += self.token_increment;
                        continue;
                    },
                    else => {
                        self.changeState(.done, 0);
                        break;
                    },
                }
            }

            // Handle group open
            if (self.isGroupOpen()) {
                self.group_depth += 1;
                self.token_index += self.token_increment;
                continue;
            }

            // Handle group depth > 0
            if (self.group_depth > 0) {
                if (self.isGroupClose()) {
                    self.group_depth -= 1;
                } else {
                    self.token_index += self.token_increment;
                    continue;
                }
            }

            // State-specific handling
            switch (self.state) {
                .init => {
                    if (self.isProtocolSuffix()) {
                        self.rewindAndSetState(.protocol);
                    }
                },
                .protocol => {
                    if (self.isProtocolSuffix()) {
                        self.computeProtocolMatchesSpecialScheme();

                        var next_state: State = .pathname;
                        var skip: usize = 1;

                        if (self.nextIsAuthoritySlashes()) {
                            next_state = .authority;
                            skip = 3;
                        } else if (self.protocol_matches_special_scheme) {
                            next_state = .authority;
                        }

                        self.changeState(next_state, skip);
                    }
                },
                .authority => {
                    if (self.isIdentityTerminator()) {
                        self.rewindAndSetState(.username);
                    } else if (self.isPathnameStart() or self.isSearchPrefix() or self.isHashPrefix()) {
                        self.rewindAndSetState(.hostname);
                    }
                },
                .username => {
                    if (self.isPasswordPrefix()) {
                        self.changeState(.password, 1);
                    } else if (self.isIdentityTerminator()) {
                        self.changeState(.hostname, 1);
                    }
                },
                .password => {
                    if (self.isIdentityTerminator()) {
                        self.changeState(.hostname, 1);
                    }
                },
                .hostname => {
                    if (self.isIPv6Open()) {
                        self.hostname_ipv6_bracket_depth += 1;
                    } else if (self.isIPv6Close()) {
                        if (self.hostname_ipv6_bracket_depth > 0) {
                            self.hostname_ipv6_bracket_depth -= 1;
                        }
                    } else if (self.isPortPrefix() and self.hostname_ipv6_bracket_depth == 0) {
                        self.changeState(.port, 1);
                    } else if (self.isPathnameStart()) {
                        self.changeState(.pathname, 0);
                    } else if (self.isSearchPrefix()) {
                        self.changeState(.search, 1);
                    } else if (self.isHashPrefix()) {
                        self.changeState(.hash, 1);
                    }
                },
                .port => {
                    if (self.isPathnameStart()) {
                        self.changeState(.pathname, 0);
                    } else if (self.isSearchPrefix()) {
                        self.changeState(.search, 1);
                    } else if (self.isHashPrefix()) {
                        self.changeState(.hash, 1);
                    }
                },
                .pathname => {
                    if (self.isSearchPrefix()) {
                        self.changeState(.search, 1);
                    } else if (self.isHashPrefix()) {
                        self.changeState(.hash, 1);
                    }
                },
                .search => {
                    if (self.isHashPrefix()) {
                        self.changeState(.hash, 1);
                    }
                },
                .hash => {
                    // Do nothing, stay in hash state
                },
                .done => {
                    unreachable;
                },
            }

            self.token_index += self.token_increment;
        }

        // Step 3: If result contains hostname but not port, set port to empty string
        if (self.result.hostname != null and self.result.port == null) {
            self.result.port = "";
        }
    }

    // ========================================================================
    // State transition helpers
    // ========================================================================

    fn changeState(self: *Self, new_state: State, skip: usize) void {
        // Save component string for current state
        if (self.state != .init and self.state != .authority and self.state != .done) {
            const component_string = self.makeComponentString();
            switch (self.state) {
                .protocol => self.result.protocol = component_string,
                .username => self.result.username = component_string,
                .password => self.result.password = component_string,
                .hostname => self.result.hostname = component_string,
                .port => self.result.port = component_string,
                .pathname => self.result.pathname = component_string,
                .search => self.result.search = component_string,
                .hash => self.result.hash = component_string,
                else => {},
            }
        }

        // Handle implicit component values
        if (self.state != .init and new_state != .done) {
            // Set hostname to empty if skipping from authority-related states to post-hostname states
            if ((self.state == .protocol or self.state == .authority or
                self.state == .username or self.state == .password) and
                (new_state == .port or new_state == .pathname or
                    new_state == .search or new_state == .hash))
            {
                if (self.result.hostname == null) {
                    self.result.hostname = "";
                }
            }

            // Set pathname to "/" or "" if skipping to search or hash
            if ((self.state == .protocol or self.state == .authority or
                self.state == .username or self.state == .password or
                self.state == .hostname or self.state == .port) and
                (new_state == .search or new_state == .hash))
            {
                if (self.result.pathname == null) {
                    if (self.protocol_matches_special_scheme) {
                        self.result.pathname = "/";
                    } else {
                        self.result.pathname = "";
                    }
                }
            }

            // Set search to empty if skipping to hash
            if ((self.state == .protocol or self.state == .authority or
                self.state == .username or self.state == .password or
                self.state == .hostname or self.state == .port or
                self.state == .pathname) and new_state == .hash)
            {
                if (self.result.search == null) {
                    self.result.search = "";
                }
            }
        }

        self.state = new_state;
        self.token_index += skip;
        self.component_start = self.token_index;
        self.token_increment = 0;
    }

    fn rewind(self: *Self) void {
        self.token_index = self.component_start;
        self.token_increment = 0;
    }

    fn rewindAndSetState(self: *Self, new_state: State) void {
        self.rewind();
        self.state = new_state;
    }

    // ========================================================================
    // Token inspection helpers
    // ========================================================================

    fn getSafeToken(self: *Self, index: usize) Token {
        if (index < self.token_list.len) {
            return self.token_list[index];
        }
        // Return end token
        if (self.token_list.len > 0) {
            return self.token_list[self.token_list.len - 1];
        }
        return Token{
            .type = .end,
            .index = 0,
            .value = "",
        };
    }

    fn isNonSpecialPatternChar(self: *Self, index: usize, value: []const u8) bool {
        const token = self.getSafeToken(index);
        if (!std.mem.eql(u8, token.value, value)) {
            return false;
        }
        return token.type == .char or token.type == .escaped_char or token.type == .invalid_char;
    }

    fn isProtocolSuffix(self: *Self) bool {
        return self.isNonSpecialPatternChar(self.token_index, ":");
    }

    fn nextIsAuthoritySlashes(self: *Self) bool {
        if (!self.isNonSpecialPatternChar(self.token_index + 1, "/")) {
            return false;
        }
        return self.isNonSpecialPatternChar(self.token_index + 2, "/");
    }

    fn isIdentityTerminator(self: *Self) bool {
        return self.isNonSpecialPatternChar(self.token_index, "@");
    }

    fn isPasswordPrefix(self: *Self) bool {
        return self.isNonSpecialPatternChar(self.token_index, ":");
    }

    fn isPortPrefix(self: *Self) bool {
        return self.isNonSpecialPatternChar(self.token_index, ":");
    }

    fn isPathnameStart(self: *Self) bool {
        return self.isNonSpecialPatternChar(self.token_index, "/");
    }

    fn isSearchPrefix(self: *Self) bool {
        if (self.isNonSpecialPatternChar(self.token_index, "?")) {
            return true;
        }

        const token = self.getSafeToken(self.token_index);
        if (!std.mem.eql(u8, token.value, "?")) {
            return false;
        }

        // Check previous token
        if (self.token_index == 0) {
            return true;
        }

        const prev_token = self.getSafeToken(self.token_index - 1);
        // If previous is name, regexp, close, or asterisk, return false
        if (prev_token.type == .name or prev_token.type == .regexp or
            prev_token.type == .close or prev_token.type == .asterisk)
        {
            return false;
        }
        return true;
    }

    fn isHashPrefix(self: *Self) bool {
        return self.isNonSpecialPatternChar(self.token_index, "#");
    }

    fn isGroupOpen(self: *Self) bool {
        const token = self.getSafeToken(self.token_index);
        return token.type == .open;
    }

    fn isGroupClose(self: *Self) bool {
        const token = self.getSafeToken(self.token_index);
        return token.type == .close;
    }

    fn isIPv6Open(self: *Self) bool {
        return self.isNonSpecialPatternChar(self.token_index, "[");
    }

    fn isIPv6Close(self: *Self) bool {
        return self.isNonSpecialPatternChar(self.token_index, "]");
    }

    // ========================================================================
    // Component string helpers
    // ========================================================================

    fn makeComponentString(self: *Self) []const u8 {
        if (self.token_index >= self.token_list.len) {
            return "";
        }

        const current_token = self.token_list[self.token_index];
        const component_start_token = self.getSafeToken(self.component_start);

        const start_index = component_start_token.index;
        const end_index = current_token.index;

        if (end_index <= start_index) {
            return "";
        }

        return self.input[start_index..end_index];
    }

    fn computeProtocolMatchesSpecialScheme(self: *Self) void {
        const protocol_string = self.makeComponentString();

        // Try to canonicalize and check if it's a special scheme
        const canon_result = canonicalize.canonicalizeProtocol(self.allocator, protocol_string) catch {
            self.protocol_matches_special_scheme = false;
            return;
        };
        defer self.allocator.free(canon_result);

        // Check against special schemes
        const special_schemes = [_][]const u8{ "http", "https", "ws", "wss", "ftp", "file" };
        for (special_schemes) |scheme| {
            if (std.mem.eql(u8, canon_result, scheme)) {
                self.protocol_matches_special_scheme = true;
                return;
            }
        }
        self.protocol_matches_special_scheme = false;
    }
};

// ============================================================================
// Public API
// ============================================================================

/// Parse a constructor string into URLPatternInit
pub fn parse(allocator: Allocator, input: []const u8) !URLPatternInit {
    return ConstructorStringParser.parse(allocator, input);
}

// ============================================================================
// Tests
// ============================================================================

test "parse - simple URL" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "https://example.com/path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
    try std.testing.expectEqualStrings("", result.port.?);
}

test "parse - URL with port" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "https://example.com:8080/path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("8080", result.port.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
}

test "parse - URL with search and hash" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "https://example.com/path?query=1#section");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
    try std.testing.expectEqualStrings("query=1", result.search.?);
    try std.testing.expectEqualStrings("section", result.hash.?);
}

test "parse - relative pathname" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "/api/:version/users/:id");

    try std.testing.expect(result.protocol == null);
    try std.testing.expect(result.hostname == null);
    try std.testing.expectEqualStrings("/api/:version/users/:id", result.pathname.?);
}

test "parse - URL with named parameter" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "https://example.com/:path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("/:path", result.pathname.?);
}

test "parse - URL with username and password" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "https://user:pass@example.com/path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("user", result.username.?);
    try std.testing.expectEqualStrings("pass", result.password.?);
    try std.testing.expectEqualStrings("example.com", result.hostname.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
}

test "parse - URL with wildcard" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "*://*/*.js");

    try std.testing.expectEqualStrings("*", result.protocol.?);
    try std.testing.expectEqualStrings("*", result.hostname.?);
    try std.testing.expectEqualStrings("/*.js", result.pathname.?);
}

test "parse - search only" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "?foo=bar");

    try std.testing.expect(result.protocol == null);
    try std.testing.expectEqualStrings("foo=bar", result.search.?);
}

test "parse - hash only" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "#section");

    try std.testing.expect(result.protocol == null);
    try std.testing.expectEqualStrings("section", result.hash.?);
}

test "parse - IPv6 hostname" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "https://[::1]:8080/path");

    try std.testing.expectEqualStrings("https", result.protocol.?);
    try std.testing.expectEqualStrings("[::1]", result.hostname.?);
    try std.testing.expectEqualStrings("8080", result.port.?);
    try std.testing.expectEqualStrings("/path", result.pathname.?);
}

test "parse - non-special scheme (opaque URL)" {
    const allocator = std.testing.allocator;

    const result = try parse(allocator, "data:text/plain,hello");

    try std.testing.expectEqualStrings("data", result.protocol.?);
    // Non-special schemes go directly to pathname
    try std.testing.expectEqualStrings("text/plain,hello", result.pathname.?);
}
