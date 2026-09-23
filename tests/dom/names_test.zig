//! Tests for DOM §1.4 name validation and "validate and extract".
//!
//! Spec: https://dom.spec.whatwg.org/#name-validation
//!
//! The cases mirror WPT dom/nodes/name-validation.html, which derives its
//! expectations from the same four definitions plus the spec's own regular
//! expression for a valid element local name.

const std = @import("std");
const dom = @import("dom");

const names = dom.names;

test "valid namespace prefix: non-empty, no whitespace, NULL, / or >" {
    try std.testing.expect(names.isValidNamespacePrefix("svg"));
    try std.testing.expect(names.isValidNamespacePrefix("="));
    try std.testing.expect(names.isValidNamespacePrefix("smallEmoji\u{1F196}"));
    try std.testing.expect(!names.isValidNamespacePrefix(""));
    for ([_][]const u8{ " ", "\t", "\n", "\x0C", "\r", "\x00", "/", ">" }) |bad| {
        try std.testing.expect(!names.isValidNamespacePrefix(bad));
    }
}

test "valid attribute local name also excludes =" {
    try std.testing.expect(names.isValidAttributeLocalName("attr"));
    try std.testing.expect(names.isValidAttributeLocalName(":"));
    try std.testing.expect(names.isValidAttributeLocalName("\""));
    try std.testing.expect(names.isValidAttributeLocalName("latin1d"));
    try std.testing.expect(!names.isValidAttributeLocalName(""));
    try std.testing.expect(!names.isValidAttributeLocalName("space "));
    try std.testing.expect(!names.isValidAttributeLocalName("a=b"));
    try std.testing.expect(!names.isValidAttributeLocalName("null\x00"));
}

test "valid element local name: the ASCII-alpha branch is permissive" {
    try std.testing.expect(names.isValidElementLocalName("div"));
    try std.testing.expect(names.isValidElementLocalName("a!"));
    try std.testing.expect(names.isValidElementLocalName("a\u{0001}"));
    try std.testing.expect(!names.isValidElementLocalName("a "));
    try std.testing.expect(!names.isValidElementLocalName("a/"));
    try std.testing.expect(!names.isValidElementLocalName("a>"));
    try std.testing.expect(!names.isValidElementLocalName("a\x00"));
}

test "valid element local name: the other branch is restrictive" {
    try std.testing.expect(names.isValidElementLocalName(":a"));
    try std.testing.expect(names.isValidElementLocalName("_-.:9"));
    try std.testing.expect(names.isValidElementLocalName("\u{00E9}t\u{00E9}"));
    try std.testing.expect(!names.isValidElementLocalName(""));
    try std.testing.expect(!names.isValidElementLocalName("5"));
    try std.testing.expect(!names.isValidElementLocalName("-a"));
    try std.testing.expect(!names.isValidElementLocalName(":!"));
    try std.testing.expect(!names.isValidElementLocalName(":soh\u{0001}"));
}

test "valid doctype name allows the empty string" {
    try std.testing.expect(names.isValidDoctypeName(""));
    try std.testing.expect(names.isValidDoctypeName("html"));
    try std.testing.expect(!names.isValidDoctypeName("a b"));
    try std.testing.expect(!names.isValidDoctypeName("a>"));
}

test "validate and extract: splits on the first colon and keeps piece 1" {
    const r = try names.validateAndExtract("http://example.com/", "f:o:o", .element);
    try std.testing.expectEqualStrings("http://example.com/", r.namespace.?);
    try std.testing.expectEqualStrings("f", r.prefix.?);
    try std.testing.expectEqualStrings("o", r.local_name);
}

test "validate and extract: the empty namespace is null" {
    const r = try names.validateAndExtract("", "x", .attribute);
    try std.testing.expect(r.namespace == null);
    try std.testing.expect(r.prefix == null);
    try std.testing.expectEqualStrings("x", r.local_name);
}

test "validate and extract: InvalidCharacterError before NamespaceError" {
    // An empty prefix is not a valid namespace prefix (step 4.4)...
    try std.testing.expectError(error.InvalidCharacterError, names.validateAndExtract("urn:x", ":a", .element));
    // ...nor is an empty local name a valid one (steps 6 and 7).
    try std.testing.expectError(error.InvalidCharacterError, names.validateAndExtract("urn:x", "a:", .attribute));
    try std.testing.expectError(error.InvalidCharacterError, names.validateAndExtract(null, "a b", .attribute));
    // Checked before the namespace is: a prefix with no namespace but a bad
    // local name is still an InvalidCharacterError.
    try std.testing.expectError(error.InvalidCharacterError, names.validateAndExtract(null, "p:a=b", .attribute));
}

test "validate and extract: the namespace rules of steps 8 to 11" {
    try std.testing.expectError(error.NamespaceError, names.validateAndExtract(null, "f:o", .element));
    try std.testing.expectError(error.NamespaceError, names.validateAndExtract("urn:x", "xml:a", .attribute));
    _ = try names.validateAndExtract("http://www.w3.org/XML/1998/namespace", "xml:a", .attribute);
    try std.testing.expectError(error.NamespaceError, names.validateAndExtract("urn:x", "xmlns", .attribute));
    try std.testing.expectError(error.NamespaceError, names.validateAndExtract("urn:x", "xmlns:a", .attribute));
    _ = try names.validateAndExtract("http://www.w3.org/2000/xmlns/", "xmlns", .attribute);
    _ = try names.validateAndExtract("http://www.w3.org/2000/xmlns/", "xmlns:a", .attribute);
    try std.testing.expectError(error.NamespaceError, names.validateAndExtract("http://www.w3.org/2000/xmlns/", "a", .attribute));
}
