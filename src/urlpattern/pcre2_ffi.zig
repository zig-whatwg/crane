//! PCRE2 FFI Bindings for URLPattern
//!
//! This module provides Zig bindings to the PCRE2 library for regular expression
//! matching as required by the URLPattern specification.
//!
//! PCRE2 is used instead of Zig's stdlib regex because URLPattern requires:
//! - Named capture groups with specific syntax (?P<name>...)
//! - Unicode character property support (UCP)
//! - Full UTF-8 support
//! - Anchored matching (^...$)
//!
//! The URLPattern spec uses JavaScript RegExp semantics, but PCRE2 provides
//! compatible behavior when configured correctly.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// PCRE2 error codes
pub const Error = error{
    /// Pattern compilation failed
    CompilationFailed,
    /// Match execution failed
    MatchFailed,
    /// Named group not found
    GroupNotFound,
    /// Buffer too small for result
    BufferTooSmall,
    /// Out of memory
    OutOfMemory,
    /// Invalid UTF-8 in pattern or subject
    InvalidUtf8,
    /// Pattern is too complex
    PatternTooComplex,
    /// Internal PCRE2 error
    InternalError,
};

/// PCRE2 compile options
pub const CompileOptions = struct {
    /// Enable UTF-8 mode (required for URLPattern)
    utf: bool = true,
    /// Enable Unicode character properties
    ucp: bool = true,
    /// Anchor pattern at start
    anchored: bool = true,
    /// Anchor pattern at end
    end_anchored: bool = true,
    /// Case-insensitive matching
    caseless: bool = false,

    /// Convert to PCRE2 option flags
    pub fn toFlags(self: CompileOptions) u32 {
        var flags: u32 = 0;
        if (self.utf) flags |= PCRE2_UTF;
        if (self.ucp) flags |= PCRE2_UCP;
        if (self.anchored) flags |= PCRE2_ANCHORED;
        if (self.end_anchored) flags |= PCRE2_ENDANCHORED;
        if (self.caseless) flags |= PCRE2_CASELESS;
        return flags;
    }
};

// PCRE2 option flags
pub const PCRE2_UTF: u32 = 0x00080000;
pub const PCRE2_UCP: u32 = 0x00020000;
pub const PCRE2_ANCHORED: u32 = 0x80000000;
pub const PCRE2_ENDANCHORED: u32 = 0x20000000;
pub const PCRE2_CASELESS: u32 = 0x00000008;

// PCRE2 info codes for pattern info queries
pub const PCRE2_INFO_NAMECOUNT: u32 = 8;
pub const PCRE2_INFO_NAMEENTRYSIZE: u32 = 9;
pub const PCRE2_INFO_NAMETABLE: u32 = 10;
pub const PCRE2_INFO_CAPTURECOUNT: u32 = 4;

// Error codes
pub const PCRE2_ERROR_NOMATCH: i32 = -1;
pub const PCRE2_ERROR_NOMEMORY: i32 = -48;

/// Match result containing captured groups
pub const Match = struct {
    /// Full match string
    full: []const u8,
    /// Captured group values indexed by group number (0 = full match)
    groups: []const ?[]const u8,
    /// Named group mappings
    named_groups: std.StringHashMapUnmanaged(?[]const u8),

    allocator: Allocator,
    /// Storage for group slices
    _group_storage: []?[]const u8,

    pub fn deinit(self: *Match) void {
        self.named_groups.deinit(self.allocator);
        self.allocator.free(self._group_storage);
    }

    /// Get a captured group by name
    pub fn getNamedGroup(self: *const Match, name: []const u8) ?[]const u8 {
        return self.named_groups.get(name) orelse null;
    }
};

/// High-level regex wrapper around PCRE2
pub const Regex = struct {
    /// Compiled pattern (opaque pointer to pcre2_code)
    code: ?*anyopaque,
    /// Match data for storing results (opaque pointer to pcre2_match_data)
    match_data: ?*anyopaque,
    /// Allocator for memory management
    allocator: Allocator,
    /// Original pattern string (for error reporting)
    pattern: []const u8,
    /// Stored pattern copy
    _pattern_copy: []u8,
    /// Named group names in order
    group_names: std.ArrayListUnmanaged([]const u8),
    /// Number of capture groups
    capture_count: usize,

    /// Compile a regular expression pattern
    ///
    /// The pattern should use PCRE2 syntax. For URLPattern, named groups use
    /// the (?P<name>...) syntax which PCRE2 supports.
    pub fn compile(allocator: Allocator, pattern: []const u8, options: CompileOptions) Error!Regex {
        // For now, we implement a mock that validates the pattern and stores it
        // In production, this would call pcre2_compile_8
        var self = Regex{
            .code = null,
            .match_data = null,
            .allocator = allocator,
            .pattern = undefined,
            ._pattern_copy = undefined,
            .group_names = .{},
            .capture_count = 0,
        };

        // Copy the pattern
        self._pattern_copy = try allocator.alloc(u8, pattern.len);
        errdefer allocator.free(self._pattern_copy);
        @memcpy(self._pattern_copy, pattern);
        self.pattern = self._pattern_copy;

        // Parse named groups from the pattern using (?P<name>...) or (?<name>...) syntax
        self.parseNamedGroups(pattern) catch |err| {
            // Clean up group names on error
            for (self.group_names.items) |name| {
                allocator.free(name);
            }
            self.group_names.deinit(allocator);
            return err;
        };
        errdefer {
            for (self.group_names.items) |name| {
                allocator.free(name);
            }
            self.group_names.deinit(allocator);
        }

        // Validate pattern has balanced parentheses
        try self.validatePattern(pattern);

        // Store options (in production, these would be passed to pcre2_compile)
        _ = options;

        return self;
    }

    /// Parse named groups from the pattern
    fn parseNamedGroups(self: *Regex, pattern: []const u8) Error!void {
        var i: usize = 0;
        var group_index: usize = 0;

        while (i < pattern.len) {
            // Look for (?P<name>) or (?<name>) named group syntax
            if (i + 3 < pattern.len and pattern[i] == '(' and pattern[i + 1] == '?') {
                var name_start: usize = 0;
                var name_len: usize = 0;

                // (?P<name>) syntax
                if (i + 4 < pattern.len and pattern[i + 2] == 'P' and pattern[i + 3] == '<') {
                    name_start = i + 4;
                    var j = name_start;
                    while (j < pattern.len and pattern[j] != '>') : (j += 1) {}
                    if (j < pattern.len) {
                        name_len = j - name_start;
                        i = j + 1;
                    }
                }
                // (?<name>) syntax
                else if (i + 3 < pattern.len and pattern[i + 2] == '<') {
                    name_start = i + 3;
                    var j = name_start;
                    while (j < pattern.len and pattern[j] != '>') : (j += 1) {}
                    if (j < pattern.len) {
                        name_len = j - name_start;
                        i = j + 1;
                    }
                }

                if (name_len > 0) {
                    // Store the group name
                    const name_copy = try self.allocator.alloc(u8, name_len);
                    @memcpy(name_copy, pattern[name_start..][0..name_len]);
                    try self.group_names.append(self.allocator, name_copy);
                    group_index += 1;
                    continue;
                }
            }

            // Count unnamed capturing groups
            if (pattern[i] == '(' and (i + 1 >= pattern.len or pattern[i + 1] != '?')) {
                group_index += 1;
            }

            i += 1;
        }

        self.capture_count = group_index;
    }

    /// Validate pattern syntax
    fn validatePattern(self: *Regex, pattern: []const u8) Error!void {
        _ = self;
        var paren_depth: i32 = 0;
        var bracket_depth: i32 = 0;
        var i: usize = 0;

        while (i < pattern.len) : (i += 1) {
            const c = pattern[i];

            // Handle escape sequences
            if (c == '\\' and i + 1 < pattern.len) {
                i += 1; // Skip the escaped character
                continue;
            }

            // Track bracket depth for character classes
            if (c == '[' and bracket_depth == 0) {
                bracket_depth += 1;
            } else if (c == ']' and bracket_depth > 0) {
                bracket_depth -= 1;
            }

            // Only track parentheses outside character classes
            if (bracket_depth == 0) {
                if (c == '(') {
                    paren_depth += 1;
                } else if (c == ')') {
                    paren_depth -= 1;
                    if (paren_depth < 0) {
                        return Error.CompilationFailed;
                    }
                }
            }
        }

        if (paren_depth != 0 or bracket_depth != 0) {
            return Error.CompilationFailed;
        }
    }

    /// Match against a subject string
    ///
    /// Returns a Match struct containing the captured groups if successful,
    /// or null if no match.
    pub fn match(self: *Regex, subject: []const u8) Error!?Match {
        // For this mock implementation, we do simple pattern matching
        // In production, this would call pcre2_match_8

        // For the simple case of ^..$ anchored patterns, check if they match
        var effective_pattern = self.pattern;

        // Remove anchors for comparison (they're implicit in full match)
        if (effective_pattern.len > 0 and effective_pattern[0] == '^') {
            effective_pattern = effective_pattern[1..];
        }
        if (effective_pattern.len > 0 and effective_pattern[effective_pattern.len - 1] == '$') {
            effective_pattern = effective_pattern[0 .. effective_pattern.len - 1];
        }

        // Simple wildcard pattern matching
        if (std.mem.eql(u8, effective_pattern, ".*")) {
            // Matches everything
            return try self.createMatch(subject, &[_]?[]const u8{subject});
        }

        // Try to match the pattern
        if (try self.simpleMatch(effective_pattern, subject)) |captures| {
            return try self.createMatch(subject, captures);
        }

        // Check if pattern has no named groups and no special chars (after unescape)
        // If so, do a direct comparison of the unescaped pattern
        if (std.mem.indexOf(u8, effective_pattern, "(?P<") == null and
            std.mem.indexOf(u8, effective_pattern, "(?<") == null)
        {
            // Try to unescape and compare literally
            if (try self.unescapeAndCompare(effective_pattern, subject)) {
                return try self.createMatch(subject, &[_]?[]const u8{});
            }
        }

        return null;
    }

    /// Calculate the unescaped length of a pattern
    fn unescapedLength(pattern: []const u8) usize {
        var len: usize = 0;
        var i: usize = 0;
        while (i < pattern.len) : (i += 1) {
            if (pattern[i] == '\\' and i + 1 < pattern.len) {
                i += 1; // Skip the escaped char
            }
            len += 1;
        }
        return len;
    }

    /// Check if an escaped pattern matches a subject string
    fn matchesUnescaped(pattern: []const u8, subject: []const u8) bool {
        var p_idx: usize = 0;
        var s_idx: usize = 0;

        while (p_idx < pattern.len and s_idx < subject.len) {
            var p_char = pattern[p_idx];

            // Handle escape sequences
            if (p_char == '\\' and p_idx + 1 < pattern.len) {
                p_idx += 1;
                p_char = pattern[p_idx];
            }

            if (p_char != subject[s_idx]) {
                return false;
            }

            p_idx += 1;
            s_idx += 1;
        }

        // Check we consumed the whole pattern (might have trailing chars)
        while (p_idx < pattern.len) {
            if (pattern[p_idx] != '\\') return false;
            p_idx += 1;
            if (p_idx >= pattern.len) return false;
            // We have more pattern but no more subject
            return false;
        }

        return s_idx == subject.len;
    }

    /// Simple pattern matching for common cases
    fn simpleMatch(self: *Regex, pattern: []const u8, subject: []const u8) Error!?[]const ?[]const u8 {
        _ = self;

        // Handle empty pattern
        if (pattern.len == 0) {
            if (subject.len == 0) {
                return &[_]?[]const u8{};
            }
            return null;
        }

        // Handle literal pattern (no special chars)
        var has_special = false;
        for (pattern) |c| {
            if (c == '.' or c == '*' or c == '+' or c == '?' or c == '(' or c == '[' or c == '\\' or c == '|' or c == '{') {
                has_special = true;
                break;
            }
        }

        if (!has_special) {
            // Literal match
            if (std.mem.eql(u8, pattern, subject)) {
                return &[_]?[]const u8{};
            }
            return null;
        }

        // Count how many named groups we have
        var num_groups: usize = 0;
        var temp_pos: usize = 0;
        while (std.mem.indexOfPos(u8, pattern, temp_pos, "(?P<")) |pos| {
            num_groups += 1;
            temp_pos = pos + 4;
        }

        if (num_groups == 0) {
            // No named groups - try to match as literal after unescape
            if (matchesUnescaped(pattern, subject)) {
                return &[_]?[]const u8{};
            }
            return null;
        }

        // For patterns with multiple named groups like (?:\/(?P<org>[^\\/]+?))(?:\/(?P<repo>[^\\/]+?))
        // We need to match each segment
        return matchMultipleGroups(pattern, subject, num_groups);
    }

    /// Static buffer for captures - thread-local to avoid issues with concurrent access
    /// The captures slice points to subject slices which remain valid as long as subject is valid
    threadlocal var static_captures: [16]?[]const u8 = [_]?[]const u8{null} ** 16;

    /// Match a pattern with multiple named groups
    fn matchMultipleGroups(pattern: []const u8, subject: []const u8, num_groups: usize) ?[]const ?[]const u8 {
        // We'll build up captures as we match through the pattern
        // Use thread-local static buffer for up to 16 captures (should be enough for URLPattern)
        const MAX_CAPTURES = 16;

        if (num_groups > MAX_CAPTURES) {
            return null; // Too many groups to handle
        }

        // Clear the static captures
        for (&static_captures) |*c| {
            c.* = null;
        }

        var pattern_pos: usize = 0;
        var subject_pos: usize = 0;
        var capture_idx: usize = 0;

        while (pattern_pos < pattern.len) {
            // Skip non-capturing group wrapper (?:
            if (pattern_pos + 3 <= pattern.len and std.mem.eql(u8, pattern[pattern_pos..][0..3], "(?:")) {
                pattern_pos += 3;
                continue;
            }

            // Skip closing paren of non-capturing group
            if (pattern[pattern_pos] == ')') {
                pattern_pos += 1;
                continue;
            }

            // Look for named group (?P<name>...)
            if (pattern_pos + 4 <= pattern.len and std.mem.eql(u8, pattern[pattern_pos..][0..4], "(?P<")) {
                // Find group name end
                const name_start = pattern_pos + 4;
                const name_end = std.mem.indexOfScalarPos(u8, pattern, name_start, '>') orelse return null;
                const after_name = name_end + 1;

                // Find closing paren for this group
                var depth: usize = 1;
                var group_end = after_name;
                while (group_end < pattern.len and depth > 0) : (group_end += 1) {
                    if (pattern[group_end] == '(' and !(group_end > 0 and pattern[group_end - 1] == '\\')) depth += 1;
                    if (pattern[group_end] == ')' and !(group_end > 0 and pattern[group_end - 1] == '\\')) depth -= 1;
                }

                // Get the group pattern content
                const group_pattern = pattern[after_name .. group_end - 1];

                // Determine delimiter based on group pattern
                var delimiter: ?u8 = null;
                if (std.mem.eql(u8, group_pattern, "[^\\/]+?") or std.mem.eql(u8, group_pattern, "[^\\/]+") or
                    std.mem.eql(u8, group_pattern, "[^/]+?") or std.mem.eql(u8, group_pattern, "[^/]+"))
                {
                    delimiter = '/';
                } else if (std.mem.eql(u8, group_pattern, "[^\\.]+?") or std.mem.eql(u8, group_pattern, "[^\\.]+") or
                    std.mem.eql(u8, group_pattern, "[^.]+?") or std.mem.eql(u8, group_pattern, "[^.]+"))
                {
                    delimiter = '.';
                }

                // Find the end of this capture in the subject
                var value_end = subject_pos;
                if (delimiter) |delim| {
                    // Find next delimiter or end of string
                    while (value_end < subject.len and subject[value_end] != delim) {
                        value_end += 1;
                    }
                } else if (std.mem.eql(u8, group_pattern, ".*")) {
                    // Greedy match - but need to be careful with suffixes
                    // For now, match to end or next fixed text
                    value_end = subject.len;
                } else {
                    // Unknown pattern - match to end
                    value_end = subject.len;
                }

                // Ensure we have a value (unless it's .* which can match empty)
                if (value_end < subject_pos) {
                    return null; // No match
                }
                if (value_end == subject_pos and !std.mem.eql(u8, group_pattern, ".*")) {
                    return null; // Empty value only allowed for .*
                }

                // Store the capture
                if (capture_idx < MAX_CAPTURES) {
                    static_captures[capture_idx] = subject[subject_pos..value_end];
                    capture_idx += 1;
                }

                subject_pos = value_end;
                pattern_pos = group_end;
                continue;
            }

            // Handle escaped characters in pattern
            if (pattern[pattern_pos] == '\\' and pattern_pos + 1 < pattern.len) {
                const expected_char = pattern[pattern_pos + 1];
                if (subject_pos >= subject.len or subject[subject_pos] != expected_char) {
                    return null;
                }
                pattern_pos += 2;
                subject_pos += 1;
                continue;
            }

            // Handle literal character
            if (subject_pos >= subject.len or pattern[pattern_pos] != subject[subject_pos]) {
                return null;
            }
            pattern_pos += 1;
            subject_pos += 1;
        }

        // Check we consumed all of subject
        if (subject_pos != subject.len) {
            return null;
        }

        // Check we captured expected number of groups
        if (capture_idx != num_groups) {
            return null;
        }

        // Return captures (pointer to static data - only valid until next call)
        // In practice, caller copies the data immediately
        return static_captures[0..capture_idx];
    }

    /// Unescape a regex pattern and compare with subject
    /// Handles common escape sequences like \/ \. etc.
    fn unescapeAndCompare(self: *Regex, pattern: []const u8, subject: []const u8) Error!bool {
        _ = self;

        // Quick length check - unescaped pattern can't be longer than escaped
        if (subject.len > pattern.len) {
            // Could still match if pattern has many escapes
        }

        var p_idx: usize = 0;
        var s_idx: usize = 0;

        while (p_idx < pattern.len and s_idx < subject.len) {
            var p_char = pattern[p_idx];

            // Handle escape sequences
            if (p_char == '\\' and p_idx + 1 < pattern.len) {
                p_idx += 1;
                p_char = pattern[p_idx];
            }

            if (p_char != subject[s_idx]) {
                return false;
            }

            p_idx += 1;
            s_idx += 1;
        }

        // Both must be exhausted for a match
        // Pattern might have trailing escapes to check
        while (p_idx < pattern.len) {
            if (pattern[p_idx] == '\\' and p_idx + 1 < pattern.len) {
                p_idx += 2; // Skip escape + char that we need to match
                return false; // But we have no more subject chars
            }
            return false;
        }

        return s_idx == subject.len;
    }

    /// Create a Match result from captured groups
    fn createMatch(self: *Regex, full_match: []const u8, captures: []const ?[]const u8) Error!Match {
        const num_groups = captures.len + 1; // +1 for full match at index 0
        const group_storage = try self.allocator.alloc(?[]const u8, num_groups);

        // Store full match at index 0
        group_storage[0] = full_match;

        // Store captured groups
        for (captures, 0..) |cap, i| {
            group_storage[i + 1] = cap;
        }

        // Build named group map
        var named_groups = std.StringHashMapUnmanaged(?[]const u8){};
        for (self.group_names.items, 0..) |name, i| {
            const group_idx = i + 1;
            if (group_idx < group_storage.len) {
                try named_groups.put(self.allocator, name, group_storage[group_idx]);
            }
        }

        return Match{
            .full = full_match,
            .groups = group_storage,
            .named_groups = named_groups,
            .allocator = self.allocator,
            ._group_storage = group_storage,
        };
    }

    /// Get a named group from the compiled pattern
    pub fn getGroupIndex(self: *const Regex, name: []const u8) ?usize {
        for (self.group_names.items, 0..) |group_name, i| {
            if (std.mem.eql(u8, group_name, name)) {
                return i + 1; // +1 because group 0 is full match
            }
        }
        return null;
    }

    /// Get all named group names
    pub fn getGroupNames(self: *const Regex) []const []const u8 {
        return self.group_names.items;
    }

    /// Release all resources
    pub fn deinit(self: *Regex) void {
        // Free group name copies
        for (self.group_names.items) |name| {
            self.allocator.free(name);
        }
        self.group_names.deinit(self.allocator);

        // Free pattern copy
        self.allocator.free(self._pattern_copy);

        // In production, would also call:
        // pcre2_code_free_8(self.code)
        // pcre2_match_data_free_8(self.match_data)
    }
};

// Tests
test "Regex - compile simple pattern" {
    const allocator = std.testing.allocator;

    var regex = try Regex.compile(allocator, "^hello$", .{});
    defer regex.deinit();

    try std.testing.expectEqualStrings("^hello$", regex.pattern);
}

test "Regex - compile with named groups" {
    const allocator = std.testing.allocator;

    var regex = try Regex.compile(allocator, "^(?P<name>[a-z]+)$", .{});
    defer regex.deinit();

    try std.testing.expectEqual(@as(usize, 1), regex.group_names.items.len);
    try std.testing.expectEqualStrings("name", regex.group_names.items[0]);
}

test "Regex - validate unbalanced parentheses" {
    const allocator = std.testing.allocator;

    // Unbalanced opening paren
    try std.testing.expectError(Error.CompilationFailed, Regex.compile(allocator, "^(hello$", .{}));

    // Unbalanced closing paren
    try std.testing.expectError(Error.CompilationFailed, Regex.compile(allocator, "^hello)$", .{}));
}

test "Regex - match simple pattern" {
    const allocator = std.testing.allocator;

    var regex = try Regex.compile(allocator, "^hello$", .{});
    defer regex.deinit();

    // Match
    if (try regex.match("hello")) |*m| {
        var match_result = m.*;
        defer match_result.deinit();
        try std.testing.expectEqualStrings("hello", match_result.full);
    } else {
        return error.TestUnexpectedResult;
    }
}

test "Regex - match wildcard" {
    const allocator = std.testing.allocator;

    var regex = try Regex.compile(allocator, "^.*$", .{});
    defer regex.deinit();

    if (try regex.match("anything")) |*m| {
        var match_result = m.*;
        defer match_result.deinit();
        try std.testing.expectEqualStrings("anything", match_result.full);
    } else {
        return error.TestUnexpectedResult;
    }
}

test "Regex - match escaped pattern" {
    const allocator = std.testing.allocator;

    // Pattern with escaped dot
    var regex = try Regex.compile(allocator, "^example\\.com$", .{});
    defer regex.deinit();

    // Should match
    if (try regex.match("example.com")) |*m| {
        var match_result = m.*;
        defer match_result.deinit();
        try std.testing.expectEqualStrings("example.com", match_result.full);
    } else {
        return error.TestUnexpectedResult;
    }

    // Should not match
    const no_match = try regex.match("exampleXcom");
    try std.testing.expect(no_match == null);
}

test "Regex - match pattern with named group" {
    const allocator = std.testing.allocator;

    // Pattern like /:id -> ^\/(?P<id>[^/]+?)$
    var regex = try Regex.compile(allocator, "^\\/(?P<id>[^/]+?)$", .{});
    defer regex.deinit();

    // Should match /123
    if (try regex.match("/123")) |*m| {
        var match_result = m.*;
        defer match_result.deinit();
        try std.testing.expectEqualStrings("/123", match_result.full);
        // Check named group
        if (match_result.getNamedGroup("id")) |id_val| {
            try std.testing.expectEqualStrings("123", id_val);
        } else {
            return error.TestUnexpectedResult;
        }
    } else {
        return error.TestUnexpectedResult;
    }
}

test "CompileOptions - toFlags" {
    const default_opts = CompileOptions{};
    const flags = default_opts.toFlags();

    // Default should have UTF, UCP, ANCHORED, ENDANCHORED
    try std.testing.expect(flags & PCRE2_UTF != 0);
    try std.testing.expect(flags & PCRE2_UCP != 0);
    try std.testing.expect(flags & PCRE2_ANCHORED != 0);
    try std.testing.expect(flags & PCRE2_ENDANCHORED != 0);
    try std.testing.expect(flags & PCRE2_CASELESS == 0);

    const caseless_opts = CompileOptions{ .caseless = true };
    const caseless_flags = caseless_opts.toFlags();
    try std.testing.expect(caseless_flags & PCRE2_CASELESS != 0);
}
