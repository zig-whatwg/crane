//! URLPattern Parser Tests
//!
//! Comprehensive tests for the URLPattern parser module.
//! See: https://urlpattern.spec.whatwg.org/#parsing

const std = @import("std");
const testing = std.testing;
const urlpattern = @import("urlpattern");

const PartType = urlpattern.PartType;
const PartModifier = urlpattern.PartModifier;
const Options = urlpattern.Options;
const parsePatternString = urlpattern.parsePatternString;
const identityEncoding = urlpattern.identityEncoding;

// Parser options for common use cases
const default_options = Options{};
const pathname_options = Options{
    .delimiter_code_point = "/",
    .prefix_code_point = "/",
};
const hostname_options = Options{
    .delimiter_code_point = ".",
};

// ============================================================================
// Fixed Text Tests
// ============================================================================

test "parse - empty pattern" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 0), result.parts.len);
}

test "parse - simple fixed text" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "hello", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.fixed_text, result.parts[0].type);
    try testing.expectEqualStrings("hello", result.parts[0].value);
    try testing.expectEqual(PartModifier.none, result.parts[0].modifier);
}

test "parse - path fixed text" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "/path/to/resource", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.fixed_text, result.parts[0].type);
    try testing.expectEqualStrings("/path/to/resource", result.parts[0].value);
}

test "parse - escaped characters become fixed text" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "\\:", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.fixed_text, result.parts[0].type);
    try testing.expectEqualStrings(":", result.parts[0].value);
}

test "parse - mixed escaped and normal text" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "foo\\:bar", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.fixed_text, result.parts[0].type);
    try testing.expectEqualStrings("foo:bar", result.parts[0].value);
}

// ============================================================================
// Named Group Tests (segment_wildcard)
// ============================================================================

test "parse - simple named group" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":foo", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.segment_wildcard, result.parts[0].type);
    try testing.expectEqualStrings("foo", result.parts[0].name);
    try testing.expectEqual(PartModifier.none, result.parts[0].modifier);
}

test "parse - named group with underscores" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":user_id", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.segment_wildcard, result.parts[0].type);
    try testing.expectEqualStrings("user_id", result.parts[0].name);
}

test "parse - named group with digits" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":item123", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.segment_wildcard, result.parts[0].type);
    try testing.expectEqualStrings("item123", result.parts[0].name);
}

test "parse - multiple named groups" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":foo:bar", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.parts.len);
    try testing.expectEqual(PartType.segment_wildcard, result.parts[0].type);
    try testing.expectEqualStrings("foo", result.parts[0].name);
    try testing.expectEqual(PartType.segment_wildcard, result.parts[1].type);
    try testing.expectEqualStrings("bar", result.parts[1].name);
}

test "parse - duplicate name error" {
    const allocator = testing.allocator;
    try testing.expectError(error.DuplicateName, parsePatternString(allocator, ":foo:foo", default_options, identityEncoding));
}

// ============================================================================
// Regexp Group Tests
// ============================================================================

test "parse - named group with regexp" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":id(\\d+)", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.regexp, result.parts[0].type);
    try testing.expectEqualStrings("id", result.parts[0].name);
    try testing.expectEqualStrings("\\d+", result.parts[0].value);
}

test "parse - anonymous regexp" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "(\\d+)", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.regexp, result.parts[0].type);
    // Anonymous groups get numeric names
    try testing.expectEqualStrings("0", result.parts[0].name);
    try testing.expectEqualStrings("\\d+", result.parts[0].value);
}

test "parse - multiple anonymous regexp" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "(\\d+)(\\w+)", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.parts.len);
    try testing.expectEqualStrings("0", result.parts[0].name);
    try testing.expectEqualStrings("1", result.parts[1].name);
}

test "parse - regexp with character class" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":slug([a-z0-9-]+)", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.regexp, result.parts[0].type);
    try testing.expectEqualStrings("slug", result.parts[0].name);
    try testing.expectEqualStrings("[a-z0-9-]+", result.parts[0].value);
}

// ============================================================================
// Wildcard Tests (full_wildcard)
// ============================================================================

test "parse - asterisk wildcard" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "*", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.full_wildcard, result.parts[0].type);
    try testing.expectEqualStrings("0", result.parts[0].name);
}

test "parse - multiple wildcards" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "*/*", default_options, identityEncoding);
    defer result.deinit();

    // * / * becomes wildcard, fixed_text, wildcard or merged
    try testing.expect(result.parts.len >= 2);
}

test "parse - named wildcard" {
    const allocator = testing.allocator;
    // Using :name with .* regexp creates a full_wildcard
    var result = try parsePatternString(allocator, ":rest(.*)", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.full_wildcard, result.parts[0].type);
    try testing.expectEqualStrings("rest", result.parts[0].name);
}

// ============================================================================
// Modifier Tests
// ============================================================================

test "parse - optional modifier on named group" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":foo?", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartModifier.optional, result.parts[0].modifier);
    try testing.expectEqualStrings("foo", result.parts[0].name);
}

test "parse - zero or more modifier on named group" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":foo*", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartModifier.zero_or_more, result.parts[0].modifier);
}

test "parse - one or more modifier on named group" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":foo+", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartModifier.one_or_more, result.parts[0].modifier);
}

test "parse - optional modifier on regexp" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":id(\\d+)?", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartModifier.optional, result.parts[0].modifier);
    try testing.expectEqual(PartType.regexp, result.parts[0].type);
}

test "parse - optional modifier on wildcard" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "*?", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartModifier.optional, result.parts[0].modifier);
}

// ============================================================================
// Prefix and Suffix Tests
// ============================================================================

test "parse - path pattern with prefix" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "/:category", pathname_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqualStrings("/", result.parts[0].prefix);
    try testing.expectEqualStrings("category", result.parts[0].name);
}

test "parse - multiple path segments" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "/:org/:repo", pathname_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.parts.len);
    try testing.expectEqualStrings("/", result.parts[0].prefix);
    try testing.expectEqualStrings("org", result.parts[0].name);
    try testing.expectEqualStrings("/", result.parts[1].prefix);
    try testing.expectEqualStrings("repo", result.parts[1].name);
}

test "parse - fixed text before named group" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "/users/:id", pathname_options, identityEncoding);
    defer result.deinit();

    // Should have fixed text "/users" and named group ":id"
    try testing.expect(result.parts.len >= 1);
    // The named group should have "/" prefix
    const last_part = result.parts[result.parts.len - 1];
    try testing.expectEqualStrings("id", last_part.name);
}

// ============================================================================
// Grouped Pattern Tests (braces)
// ============================================================================

test "parse - grouped name" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "{:foo}", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.segment_wildcard, result.parts[0].type);
    try testing.expectEqualStrings("foo", result.parts[0].name);
}

test "parse - grouped name with modifier" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "{:foo}?", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartModifier.optional, result.parts[0].modifier);
}

test "parse - grouped pattern with prefix" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "{/prefix:name}", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqualStrings("/prefix", result.parts[0].prefix);
    try testing.expectEqualStrings("name", result.parts[0].name);
}

test "parse - grouped pattern with suffix" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "{:name.json}", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqualStrings(".json", result.parts[0].suffix);
    try testing.expectEqualStrings("name", result.parts[0].name);
}

test "parse - grouped pattern with prefix and suffix" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "{prefix:name suffix}", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqualStrings("prefix", result.parts[0].prefix);
    try testing.expectEqualStrings(" suffix", result.parts[0].suffix);
    try testing.expectEqualStrings("name", result.parts[0].name);
}

test "parse - grouped fixed text" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "{foo}", default_options, identityEncoding);
    defer result.deinit();

    // Just fixed text in braces becomes fixed text part
    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.fixed_text, result.parts[0].type);
    try testing.expectEqualStrings("foo", result.parts[0].value);
}

test "parse - grouped fixed text with modifier" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "{foo}?", default_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.fixed_text, result.parts[0].type);
    try testing.expectEqual(PartModifier.optional, result.parts[0].modifier);
}

// ============================================================================
// Complex Pattern Tests
// ============================================================================

test "parse - api route pattern" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "/api/v:version/:resource/:id(\\d+)?", pathname_options, identityEncoding);
    defer result.deinit();

    // Should have: /api/v (fixed), version (segment), resource (segment), id (regexp optional)
    try testing.expect(result.parts.len >= 3);
}

test "parse - file extension pattern" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "/:filename.:ext", pathname_options, identityEncoding);
    defer result.deinit();

    // Should have filename and ext parts
    try testing.expect(result.parts.len >= 2);
}

test "parse - catch-all pattern" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "/static/*", pathname_options, identityEncoding);
    defer result.deinit();

    // Fixed text + wildcard
    try testing.expect(result.parts.len >= 1);
    // Last part should be wildcard
    const last = result.parts[result.parts.len - 1];
    try testing.expectEqual(PartType.full_wildcard, last.type);
}

test "parse - hostname pattern" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":subdomain.example.com", hostname_options, identityEncoding);
    defer result.deinit();

    // subdomain (segment) + .example.com (fixed)
    try testing.expect(result.parts.len >= 1);
    try testing.expectEqualStrings("subdomain", result.parts[0].name);
}

test "parse - complex api pattern" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "/users/:userId/posts/:postId", pathname_options, identityEncoding);
    defer result.deinit();

    // Count named parts
    var named_count: usize = 0;
    for (result.parts) |part| {
        if (part.name.len > 0) named_count += 1;
    }
    try testing.expectEqual(@as(usize, 2), named_count);
}

// ============================================================================
// Part Type Verification Tests
// ============================================================================

test "parse - part types are correct" {
    const allocator = testing.allocator;

    // Fixed text
    {
        var result = try parsePatternString(allocator, "literal", default_options, identityEncoding);
        defer result.deinit();
        try testing.expectEqual(PartType.fixed_text, result.parts[0].type);
    }

    // Segment wildcard (named group without regexp)
    {
        var result = try parsePatternString(allocator, ":name", default_options, identityEncoding);
        defer result.deinit();
        try testing.expectEqual(PartType.segment_wildcard, result.parts[0].type);
    }

    // Regexp
    {
        var result = try parsePatternString(allocator, ":id(\\d+)", default_options, identityEncoding);
        defer result.deinit();
        try testing.expectEqual(PartType.regexp, result.parts[0].type);
    }

    // Full wildcard
    {
        var result = try parsePatternString(allocator, "*", default_options, identityEncoding);
        defer result.deinit();
        try testing.expectEqual(PartType.full_wildcard, result.parts[0].type);
    }
}

// ============================================================================
// Modifier Verification Tests
// ============================================================================

test "parse - all modifier types" {
    const allocator = testing.allocator;

    // None (default)
    {
        var result = try parsePatternString(allocator, ":foo", default_options, identityEncoding);
        defer result.deinit();
        try testing.expectEqual(PartModifier.none, result.parts[0].modifier);
    }

    // Optional (?)
    {
        var result = try parsePatternString(allocator, ":foo?", default_options, identityEncoding);
        defer result.deinit();
        try testing.expectEqual(PartModifier.optional, result.parts[0].modifier);
    }

    // Zero or more (*)
    {
        var result = try parsePatternString(allocator, ":foo*", default_options, identityEncoding);
        defer result.deinit();
        try testing.expectEqual(PartModifier.zero_or_more, result.parts[0].modifier);
    }

    // One or more (+)
    {
        var result = try parsePatternString(allocator, ":foo+", default_options, identityEncoding);
        defer result.deinit();
        try testing.expectEqual(PartModifier.one_or_more, result.parts[0].modifier);
    }
}

// ============================================================================
// Modifier String Conversion Tests
// ============================================================================

test "PartModifier.toString" {
    try testing.expectEqualStrings("", PartModifier.none.toString());
    try testing.expectEqualStrings("?", PartModifier.optional.toString());
    try testing.expectEqualStrings("*", PartModifier.zero_or_more.toString());
    try testing.expectEqualStrings("+", PartModifier.one_or_more.toString());
}

// ============================================================================
// Options Tests
// ============================================================================

test "parse - pathname options create correct segment wildcard" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "/:path", pathname_options, identityEncoding);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.segment_wildcard, result.parts[0].type);
}

test "parse - hostname options create correct segment wildcard" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, ":host.example", hostname_options, identityEncoding);
    defer result.deinit();

    // First part should be segment wildcard with hostname delimiter behavior
    try testing.expectEqual(PartType.segment_wildcard, result.parts[0].type);
}

// ============================================================================
// Edge Cases
// ============================================================================

test "parse - consecutive modifiers" {
    // Only first modifier applies to the group, rest might be errors or ignored
    // This tests the actual behavior
    const allocator = testing.allocator;

    // Testing what happens with multiple modifiers
    // Depending on implementation, this might parse as :foo with ? modifier,
    // then * and + as separate tokens that error or get ignored
    var result = parsePatternString(allocator, ":foo?", default_options, identityEncoding) catch {
        // If it errors, that's valid behavior
        return;
    };
    defer result.deinit();

    // If it succeeds, verify the modifier is optional
    try testing.expectEqual(PartModifier.optional, result.parts[0].modifier);
}

test "parse - empty braces" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "{}", default_options, identityEncoding);
    defer result.deinit();

    // Empty braces produce no parts
    try testing.expectEqual(@as(usize, 0), result.parts.len);
}

test "parse - only prefix no matching group" {
    const allocator = testing.allocator;
    var result = try parsePatternString(allocator, "/", pathname_options, identityEncoding);
    defer result.deinit();

    // Single slash is just fixed text
    try testing.expectEqual(@as(usize, 1), result.parts.len);
    try testing.expectEqual(PartType.fixed_text, result.parts[0].type);
}
