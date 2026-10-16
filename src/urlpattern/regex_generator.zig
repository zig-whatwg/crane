//! URLPattern Regex Generator
//!
//! Implements the algorithm to convert part lists to regular expressions
//! from the URLPattern specification.
//! See: https://urlpattern.spec.whatwg.org/#converting-part-lists-to-regular-expressions
//!
//! The output is an ECMAScript regular expression for RegExpCreate with "v" or
//! "vi" (regexp.zig). Its capture groups are positional: group i holds the
//! value of the name list's entry i - 1, as the spec does it (its note: named
//! capture groups were judged too risky, and path-to-regexp does not use
//! them; Chromium's liburlpattern pattern.cc is positional too).

const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
const Part = parser.Part;
const PartType = parser.PartType;
const PartModifier = parser.PartModifier;
const Options = parser.Options;

/// Result of regex generation
pub const RegexGenerationResult = struct {
    /// The generated regular expression string
    regex: []u8,
    /// List of group names in order
    name_list: [][]u8,
    /// Allocator used
    allocator: Allocator,

    pub fn deinit(self: *RegexGenerationResult) void {
        self.allocator.free(self.regex);
        for (self.name_list) |name| {
            self.allocator.free(name);
        }
        self.allocator.free(self.name_list);
    }
};

/// Escape special regex characters in a string
pub fn escapeRegexpString(allocator: Allocator, input: []const u8) ![]u8 {
    // "Escape a regexp string", step 4.3: the characters a backslash precedes.
    const special_chars = ".+*?^${}()[]|\\/";

    // Count how many escape characters we need
    var escape_count: usize = 0;
    for (input) |c| {
        for (special_chars) |sc| {
            if (c == sc) {
                escape_count += 1;
                break;
            }
        }
    }

    // Allocate result
    const result = try allocator.alloc(u8, input.len + escape_count);
    errdefer allocator.free(result);

    var out_idx: usize = 0;
    for (input) |c| {
        var needs_escape = false;
        for (special_chars) |sc| {
            if (c == sc) {
                needs_escape = true;
                break;
            }
        }

        if (needs_escape) {
            result[out_idx] = '\\';
            out_idx += 1;
        }
        result[out_idx] = c;
        out_idx += 1;
    }

    return result;
}

/// Convert a modifier to its regex string representation
fn convertModifierToString(modifier: PartModifier) []const u8 {
    return switch (modifier) {
        .none => "",
        .optional => "?",
        .zero_or_more => "*",
        .one_or_more => "+",
    };
}

/// Generate the segment wildcard regexp for given options
pub fn generateSegmentWildcardRegexp(allocator: Allocator, options: Options) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, "[^");

    // Escape and add delimiter
    const escaped_delimiter = try escapeRegexpString(allocator, options.delimiter_code_point);
    defer allocator.free(escaped_delimiter);
    try result.appendSlice(allocator, escaped_delimiter);

    try result.appendSlice(allocator, "]+?");

    return result.toOwnedSlice(allocator);
}

/// Full wildcard regexp value
pub const full_wildcard_regexp = ".*";

/// Generate a regular expression and name list from a part list
///
/// This implements the algorithm from:
/// https://urlpattern.spec.whatwg.org/#generate-a-regular-expression-and-name-list
pub fn generateRegexAndNameList(
    allocator: Allocator,
    part_list: []const Part,
    options: Options,
) !RegexGenerationResult {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);

    var name_list: std.ArrayListUnmanaged([]u8) = .empty;
    errdefer {
        for (name_list.items) |name| {
            allocator.free(name);
        }
        name_list.deinit(allocator);
    }

    // Start anchor
    try result.appendSlice(allocator, "^");

    // Generate segment wildcard regexp for this options set
    const segment_wildcard = try generateSegmentWildcardRegexp(allocator, options);
    defer allocator.free(segment_wildcard);

    for (part_list) |part| {
        if (part.type == .fixed_text) {
            // Fixed text part
            if (part.modifier == .none) {
                // Simple case: just escape and append
                const escaped = try escapeRegexpString(allocator, part.value);
                defer allocator.free(escaped);
                try result.appendSlice(allocator, escaped);
            } else {
                // Fixed text with modifier: (?:<escaped value>)<modifier>
                try result.appendSlice(allocator, "(?:");
                const escaped = try escapeRegexpString(allocator, part.value);
                defer allocator.free(escaped);
                try result.appendSlice(allocator, escaped);
                try result.append(allocator, ')');
                try result.appendSlice(allocator, convertModifierToString(part.modifier));
            }
            continue;
        }

        // Matching group part - add name to list
        const name_copy = try allocator.dupe(u8, part.name);
        name_list.append(allocator, name_copy) catch |err| {
            allocator.free(name_copy);
            return err;
        };

        // Get the regexp value for this part
        var regexp_value: []const u8 = part.value;
        if (part.type == .segment_wildcard) {
            regexp_value = segment_wildcard;
        } else if (part.type == .full_wildcard) {
            regexp_value = full_wildcard_regexp;
        }

        const has_prefix = part.prefix.len > 0;
        const has_suffix = part.suffix.len > 0;

        // 3.7. No prefix or suffix.
        if (!has_prefix and !has_suffix) {
            if (part.modifier == .none or part.modifier == .optional) {
                // 3.7.1. (<regexp value>)<modifier>
                try result.append(allocator, '(');
                try result.appendSlice(allocator, regexp_value);
                try result.append(allocator, ')');
                try result.appendSlice(allocator, convertModifierToString(part.modifier));
            } else {
                // 3.7.2. A repeating modifier: ((?:<regexp value>)<modifier>)
                try result.appendSlice(allocator, "((?:");
                try result.appendSlice(allocator, regexp_value);
                try result.append(allocator, ')');
                try result.appendSlice(allocator, convertModifierToString(part.modifier));
                try result.append(allocator, ')');
            }
            continue;
        }

        // Has prefix and/or suffix
        const escaped_prefix = try escapeRegexpString(allocator, part.prefix);
        defer allocator.free(escaped_prefix);
        const escaped_suffix = try escapeRegexpString(allocator, part.suffix);
        defer allocator.free(escaped_suffix);

        if (part.modifier == .none or part.modifier == .optional) {
            // 3.8. Non-repeating with a prefix or suffix:
            // (?:<prefix>(<regexp value>)<suffix>)<modifier>
            try result.appendSlice(allocator, "(?:");
            try result.appendSlice(allocator, escaped_prefix);
            try result.append(allocator, '(');
            try result.appendSlice(allocator, regexp_value);
            try result.append(allocator, ')');
            try result.appendSlice(allocator, escaped_suffix);
            try result.append(allocator, ')');
            try result.appendSlice(allocator, convertModifierToString(part.modifier));
            continue;
        }

        // 3.9-3.23. Repeating with a prefix or suffix:
        // (?:<prefix>((?:<regexp value>)(?:<suffix><prefix>(?:<regexp value>))*)<suffix>)?
        try result.appendSlice(allocator, "(?:");
        try result.appendSlice(allocator, escaped_prefix);
        try result.appendSlice(allocator, "((?:");
        try result.appendSlice(allocator, regexp_value);
        try result.appendSlice(allocator, ")(?:");
        try result.appendSlice(allocator, escaped_suffix);
        try result.appendSlice(allocator, escaped_prefix);
        try result.appendSlice(allocator, "(?:");
        try result.appendSlice(allocator, regexp_value);
        try result.appendSlice(allocator, "))*)");
        try result.appendSlice(allocator, escaped_suffix);
        try result.append(allocator, ')');

        if (part.modifier == .zero_or_more) {
            try result.append(allocator, '?');
        }
    }

    // End anchor
    try result.appendSlice(allocator, "$");

    // These two ownership transfers can allocate independently.
    const regex = try result.toOwnedSlice(allocator);
    errdefer allocator.free(regex);
    return RegexGenerationResult{
        .regex = regex,
        .name_list = try name_list.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

// Tests

test "escapeRegexpString - no special chars" {
    const allocator = std.testing.allocator;
    const result = try escapeRegexpString(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "escapeRegexpString - with special chars" {
    const allocator = std.testing.allocator;
    const result = try escapeRegexpString(allocator, "hello.world*");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello\\.world\\*", result);
}

test "escapeRegexpString - path separator" {
    const allocator = std.testing.allocator;
    const result = try escapeRegexpString(allocator, "/foo/bar");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("\\/foo\\/bar", result);
}

test "generateSegmentWildcardRegexp - pathname" {
    const allocator = std.testing.allocator;
    const result = try generateSegmentWildcardRegexp(allocator, parser.pathname_options);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("[^\\/]+?", result);
}

test "generateSegmentWildcardRegexp - hostname" {
    const allocator = std.testing.allocator;
    const result = try generateSegmentWildcardRegexp(allocator, parser.hostname_options);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("[^\\.]+?", result);
}

test "generateRegexAndNameList - fixed text" {
    const allocator = std.testing.allocator;

    var parts: std.ArrayListUnmanaged(Part) = .empty;
    defer parts.deinit(allocator);

    const part = Part.init(.fixed_text, "hello", .none);
    try parts.append(allocator, part);

    var gen_result = try generateRegexAndNameList(allocator, parts.items, parser.default_options);
    defer gen_result.deinit();

    try std.testing.expectEqualStrings("^hello$", gen_result.regex);
    try std.testing.expectEqual(@as(usize, 0), gen_result.name_list.len);
}

test "generateRegexAndNameList - named group" {
    const allocator = std.testing.allocator;

    var parts: std.ArrayListUnmanaged(Part) = .empty;
    defer parts.deinit(allocator);

    var part = Part.init(.segment_wildcard, "", .none);
    part.name = "foo";
    try parts.append(allocator, part);

    var gen_result = try generateRegexAndNameList(allocator, parts.items, parser.default_options);
    defer gen_result.deinit();

    // A positional group; the name goes in the name list.
    try std.testing.expectEqualStrings("^([^]+?)$", gen_result.regex);
    try std.testing.expectEqual(@as(usize, 1), gen_result.name_list.len);
    try std.testing.expectEqualStrings("foo", gen_result.name_list[0]);
}

test "generateRegexAndNameList - full wildcard" {
    const allocator = std.testing.allocator;

    var parts: std.ArrayListUnmanaged(Part) = .empty;
    defer parts.deinit(allocator);

    var part = Part.init(.full_wildcard, "", .none);
    part.name = "0";
    try parts.append(allocator, part);

    var gen_result = try generateRegexAndNameList(allocator, parts.items, parser.default_options);
    defer gen_result.deinit();

    // Should have .* pattern
    try std.testing.expect(std.mem.indexOf(u8, gen_result.regex, ".*") != null);
    // Should have name "0" in the name list
    try std.testing.expectEqual(@as(usize, 1), gen_result.name_list.len);
    try std.testing.expectEqualStrings("0", gen_result.name_list[0]);
}

test "generateRegexAndNameList - optional modifier" {
    const allocator = std.testing.allocator;

    var parts: std.ArrayListUnmanaged(Part) = .empty;
    defer parts.deinit(allocator);

    var part = Part.init(.segment_wildcard, "", .optional);
    part.name = "id";
    try parts.append(allocator, part);

    var gen_result = try generateRegexAndNameList(allocator, parts.items, parser.default_options);
    defer gen_result.deinit();

    // Should end with ?$ for optional
    try std.testing.expect(std.mem.endsWith(u8, gen_result.regex, ")?$"));
}

test "generateRegexAndNameList - with prefix" {
    const allocator = std.testing.allocator;

    var parts: std.ArrayListUnmanaged(Part) = .empty;
    defer parts.deinit(allocator);

    var part = Part.init(.segment_wildcard, "", .none);
    part.name = "id";
    part.prefix = "/";
    try parts.append(allocator, part);

    var gen_result = try generateRegexAndNameList(allocator, parts.items, parser.pathname_options);
    defer gen_result.deinit();

    // Should include escaped prefix
    try std.testing.expect(std.mem.indexOf(u8, gen_result.regex, "\\/") != null);
}
