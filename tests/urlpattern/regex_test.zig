//! URLPattern Regex Generator Tests
//!
//! Comprehensive tests for the URLPattern regex generator module.
//! See: https://urlpattern.spec.whatwg.org/#converting-part-lists-to-regular-expressions

const std = @import("std");
const testing = std.testing;
const urlpattern = @import("urlpattern");

const Part = urlpattern.Part;
const PartType = urlpattern.PartType;
const PartModifier = urlpattern.PartModifier;
const Options = urlpattern.Options;
const generateRegexAndNameList = urlpattern.generateRegexAndNameList;
const escapeRegexpString = urlpattern.escapeRegexpString;
const generateSegmentWildcardRegexp = urlpattern.generateSegmentWildcardRegexp;
const full_wildcard_regexp = urlpattern.full_wildcard_regexp;

// Parser options for common use cases
const default_options = Options{};
const pathname_options = Options{
    .delimiter_code_point = "/",
    .prefix_code_point = "/",
};
const hostname_options = Options{
    .delimiter_code_point = ".",
};

/// Helper to create a Part with a name
fn makeNamedPart(part_type: PartType, value: []const u8, modifier: PartModifier, name: []const u8) Part {
    var part = Part.init(part_type, value, modifier);
    part.name = name;
    return part;
}

/// Helper to create a Part with prefix and/or suffix
fn makePrefixSuffixPart(part_type: PartType, value: []const u8, modifier: PartModifier, name: []const u8, prefix: []const u8, suffix: []const u8) Part {
    var part = Part.init(part_type, value, modifier);
    part.name = name;
    part.prefix = prefix;
    part.suffix = suffix;
    return part;
}

// ============================================================================
// escapeRegexpString Tests
// ============================================================================

test "escapeRegexpString - no special characters" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "hello");
    defer allocator.free(result);
    try testing.expectEqualStrings("hello", result);
}

test "escapeRegexpString - empty string" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "");
    defer allocator.free(result);
    try testing.expectEqualStrings("", result);
}

test "escapeRegexpString - period" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, ".");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\.", result);
}

test "escapeRegexpString - asterisk" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "*");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\*", result);
}

test "escapeRegexpString - plus" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "+");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\+", result);
}

test "escapeRegexpString - question mark" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "?");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\?", result);
}

test "escapeRegexpString - caret" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "^");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\^", result);
}

test "escapeRegexpString - dollar" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "$");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\$", result);
}

test "escapeRegexpString - open brace" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "{");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\{", result);
}

test "escapeRegexpString - close brace" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "}");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\}", result);
}

test "escapeRegexpString - open paren" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "(");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\(", result);
}

test "escapeRegexpString - close paren" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, ")");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\)", result);
}

test "escapeRegexpString - open bracket" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "[");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\[", result);
}

test "escapeRegexpString - close bracket" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "]");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\]", result);
}

test "escapeRegexpString - pipe" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "|");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\|", result);
}

test "escapeRegexpString - backslash" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "\\");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\\\", result);
}

test "escapeRegexpString - forward slash" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "/");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\/", result);
}

test "escapeRegexpString - path with slashes" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "/foo/bar");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\/foo\\/bar", result);
}

test "escapeRegexpString - mixed special and normal" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, "hello.world*");
    defer allocator.free(result);
    try testing.expectEqualStrings("hello\\.world\\*", result);
}

test "escapeRegexpString - all special chars" {
    const allocator = testing.allocator;
    const result = try escapeRegexpString(allocator, ".+*?^${}()[]|\\/");
    defer allocator.free(result);
    try testing.expectEqualStrings("\\.\\+\\*\\?\\^\\$\\{\\}\\(\\)\\[\\]\\|\\\\\\/", result);
}

// ============================================================================
// generateSegmentWildcardRegexp Tests
// ============================================================================

test "generateSegmentWildcardRegexp - pathname" {
    const allocator = testing.allocator;
    const result = try generateSegmentWildcardRegexp(allocator, pathname_options);
    defer allocator.free(result);
    try testing.expectEqualStrings("[^\\/]+?", result);
}

test "generateSegmentWildcardRegexp - hostname" {
    const allocator = testing.allocator;
    const result = try generateSegmentWildcardRegexp(allocator, hostname_options);
    defer allocator.free(result);
    try testing.expectEqualStrings("[^\\.]+?", result);
}

test "generateSegmentWildcardRegexp - default (empty delimiter)" {
    const allocator = testing.allocator;
    const result = try generateSegmentWildcardRegexp(allocator, default_options);
    defer allocator.free(result);
    try testing.expectEqualStrings("[^]+?", result);
}

// ============================================================================
// full_wildcard_regexp Tests
// ============================================================================

test "full_wildcard_regexp value" {
    try testing.expectEqualStrings(".*", full_wildcard_regexp);
}

// ============================================================================
// generateRegexAndNameList - Fixed Text Tests
// ============================================================================

test "generateRegexAndNameList - empty parts" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    try testing.expectEqualStrings("^$", result.regex);
    try testing.expectEqual(@as(usize, 0), result.name_list.len);
}

test "generateRegexAndNameList - simple fixed text" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = Part.init(.fixed_text, "hello", .none);
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    try testing.expectEqualStrings("^hello$", result.regex);
    try testing.expectEqual(@as(usize, 0), result.name_list.len);
}

test "generateRegexAndNameList - fixed text with special chars" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = Part.init(.fixed_text, "hello.world", .none);
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    try testing.expectEqualStrings("^hello\\.world$", result.regex);
}

test "generateRegexAndNameList - fixed text with modifier" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = Part.init(.fixed_text, "foo", .optional);
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    try testing.expectEqualStrings("^(?:foo)?$", result.regex);
}

// ============================================================================
// generateRegexAndNameList - Named Group Tests
// ============================================================================

test "generateRegexAndNameList - segment wildcard" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makeNamedPart(.segment_wildcard, "", .none, "foo");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    // Should contain named group with (?P<foo>...)
    try testing.expect(std.mem.indexOf(u8, result.regex, "(?P<foo>") != null);
    try testing.expectEqual(@as(usize, 1), result.name_list.len);
    try testing.expectEqualStrings("foo", result.name_list[0]);
}

test "generateRegexAndNameList - segment wildcard pathname" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makeNamedPart(.segment_wildcard, "", .none, "path");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, pathname_options);
    defer result.deinit();

    // Should use [^/]+? as segment wildcard
    try testing.expect(std.mem.indexOf(u8, result.regex, "[^\\/]+?") != null);
}

test "generateRegexAndNameList - multiple named groups" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part1 = makeNamedPart(.segment_wildcard, "", .none, "foo");
    try parts.append(allocator, part1);

    const part2 = makeNamedPart(.segment_wildcard, "", .none, "bar");
    try parts.append(allocator, part2);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    try testing.expect(std.mem.indexOf(u8, result.regex, "(?P<foo>") != null);
    try testing.expect(std.mem.indexOf(u8, result.regex, "(?P<bar>") != null);
    try testing.expectEqual(@as(usize, 2), result.name_list.len);
    try testing.expectEqualStrings("foo", result.name_list[0]);
    try testing.expectEqualStrings("bar", result.name_list[1]);
}

// ============================================================================
// generateRegexAndNameList - Regexp Part Tests
// ============================================================================

test "generateRegexAndNameList - regexp part" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makeNamedPart(.regexp, "\\d+", .none, "id");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    try testing.expect(std.mem.indexOf(u8, result.regex, "(?P<id>") != null);
    try testing.expect(std.mem.indexOf(u8, result.regex, "\\d+") != null);
}

// ============================================================================
// generateRegexAndNameList - Full Wildcard Tests
// ============================================================================

test "generateRegexAndNameList - full wildcard" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makeNamedPart(.full_wildcard, "", .none, "0");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    // Should use .* pattern
    try testing.expect(std.mem.indexOf(u8, result.regex, ".*") != null);
    try testing.expectEqual(@as(usize, 1), result.name_list.len);
}

// ============================================================================
// generateRegexAndNameList - Modifier Tests
// ============================================================================

test "generateRegexAndNameList - optional modifier" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makeNamedPart(.segment_wildcard, "", .optional, "id");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    // Should end with )? for optional
    try testing.expect(std.mem.endsWith(u8, result.regex, ")?$"));
}

test "generateRegexAndNameList - zero or more modifier no prefix" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makeNamedPart(.segment_wildcard, "", .zero_or_more, "path");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    // Should contain * modifier somewhere
    try testing.expect(std.mem.indexOf(u8, result.regex, "*") != null);
}

test "generateRegexAndNameList - one or more modifier no prefix" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makeNamedPart(.segment_wildcard, "", .one_or_more, "path");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    // Should contain + modifier somewhere
    try testing.expect(std.mem.indexOf(u8, result.regex, "+") != null);
}

// ============================================================================
// generateRegexAndNameList - Prefix/Suffix Tests
// ============================================================================

test "generateRegexAndNameList - with prefix" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makePrefixSuffixPart(.segment_wildcard, "", .none, "id", "/", "");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, pathname_options);
    defer result.deinit();

    // Should include escaped prefix
    try testing.expect(std.mem.indexOf(u8, result.regex, "\\/") != null);
}

test "generateRegexAndNameList - with suffix" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makePrefixSuffixPart(.segment_wildcard, "", .none, "file", "", ".json");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    // Should include escaped suffix
    try testing.expect(std.mem.indexOf(u8, result.regex, "\\.json") != null);
}

test "generateRegexAndNameList - with prefix and suffix" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makePrefixSuffixPart(.segment_wildcard, "", .none, "name", "/", ".html");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, pathname_options);
    defer result.deinit();

    try testing.expect(std.mem.indexOf(u8, result.regex, "\\/") != null);
    try testing.expect(std.mem.indexOf(u8, result.regex, "\\.html") != null);
}

test "generateRegexAndNameList - optional with prefix" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makePrefixSuffixPart(.segment_wildcard, "", .optional, "id", "/", "");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, pathname_options);
    defer result.deinit();

    // The whole group (prefix + capture) should be optional
    try testing.expect(std.mem.endsWith(u8, result.regex, ")?$"));
}

// ============================================================================
// generateRegexAndNameList - Anchor Tests
// ============================================================================

test "generateRegexAndNameList - has start anchor" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = Part.init(.fixed_text, "test", .none);
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    try testing.expect(std.mem.startsWith(u8, result.regex, "^"));
}

test "generateRegexAndNameList - has end anchor" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = Part.init(.fixed_text, "test", .none);
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    try testing.expect(std.mem.endsWith(u8, result.regex, "$"));
}

// ============================================================================
// generateRegexAndNameList - Name List Order Tests
// ============================================================================

test "generateRegexAndNameList - name list order matches parts order" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part1 = makeNamedPart(.segment_wildcard, "", .none, "first");
    try parts.append(allocator, part1);

    const part2 = makeNamedPart(.regexp, "\\d+", .none, "second");
    try parts.append(allocator, part2);

    const part3 = makeNamedPart(.full_wildcard, "", .none, "third");
    try parts.append(allocator, part3);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.name_list.len);
    try testing.expectEqualStrings("first", result.name_list[0]);
    try testing.expectEqualStrings("second", result.name_list[1]);
    try testing.expectEqualStrings("third", result.name_list[2]);
}

test "generateRegexAndNameList - fixed text not in name list" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part1 = Part.init(.fixed_text, "prefix", .none);
    try parts.append(allocator, part1);

    const part2 = makeNamedPart(.segment_wildcard, "", .none, "capture");
    try parts.append(allocator, part2);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    // Only "capture" should be in name list, not fixed_text
    try testing.expectEqual(@as(usize, 1), result.name_list.len);
    try testing.expectEqualStrings("capture", result.name_list[0]);
}

// ============================================================================
// generateRegexAndNameList - Complex Pattern Tests
// ============================================================================

test "generateRegexAndNameList - api route pattern" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    // /api/v
    const fixed_part = Part.init(.fixed_text, "/api/v", .none);
    try parts.append(allocator, fixed_part);

    // :version
    const version_part = makeNamedPart(.segment_wildcard, "", .none, "version");
    try parts.append(allocator, version_part);

    // /users/
    const users_part = Part.init(.fixed_text, "/users/", .none);
    try parts.append(allocator, users_part);

    // :id(\d+)
    const id_part = makeNamedPart(.regexp, "\\d+", .none, "id");
    try parts.append(allocator, id_part);

    var result = try generateRegexAndNameList(allocator, parts.items, default_options);
    defer result.deinit();

    // Verify structure
    try testing.expect(std.mem.startsWith(u8, result.regex, "^"));
    try testing.expect(std.mem.endsWith(u8, result.regex, "$"));
    try testing.expect(std.mem.indexOf(u8, result.regex, "(?P<version>") != null);
    try testing.expect(std.mem.indexOf(u8, result.regex, "(?P<id>") != null);

    try testing.expectEqual(@as(usize, 2), result.name_list.len);
    try testing.expectEqualStrings("version", result.name_list[0]);
    try testing.expectEqualStrings("id", result.name_list[1]);
}

test "generateRegexAndNameList - catch-all route" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    // /static
    const fixed_part = Part.init(.fixed_text, "/static", .none);
    try parts.append(allocator, fixed_part);

    // /*
    const wildcard_part = makePrefixSuffixPart(.full_wildcard, "", .none, "0", "/", "");
    try parts.append(allocator, wildcard_part);

    var result = try generateRegexAndNameList(allocator, parts.items, pathname_options);
    defer result.deinit();

    try testing.expect(std.mem.indexOf(u8, result.regex, "\\/static") != null);
    try testing.expect(std.mem.indexOf(u8, result.regex, ".*") != null);
}

// ============================================================================
// generateRegexAndNameList - Repeating Modifier with Prefix Tests
// ============================================================================

test "generateRegexAndNameList - zero or more with prefix" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makePrefixSuffixPart(.segment_wildcard, "", .zero_or_more, "segments", "/", "");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, pathname_options);
    defer result.deinit();

    // Complex repeating pattern with prefix
    try testing.expect(std.mem.startsWith(u8, result.regex, "^"));
    try testing.expect(std.mem.endsWith(u8, result.regex, "$"));
}

test "generateRegexAndNameList - one or more with prefix and suffix" {
    const allocator = testing.allocator;
    var parts: std.ArrayListUnmanaged(Part) = .{};
    defer parts.deinit(allocator);

    const part = makePrefixSuffixPart(.segment_wildcard, "", .one_or_more, "files", "/", ".txt");
    try parts.append(allocator, part);

    var result = try generateRegexAndNameList(allocator, parts.items, pathname_options);
    defer result.deinit();

    // Should handle complex repeating pattern
    try testing.expect(result.regex.len > 0);
    try testing.expectEqual(@as(usize, 1), result.name_list.len);
}
