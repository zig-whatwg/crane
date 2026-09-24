//! DOM §1.4 "Name validation", including "validate and extract".
//!
//! Spec: https://dom.spec.whatwg.org/#name-validation
//!
//! One copy of these rules, for every API that builds a name out of script
//! input: `setAttribute`, `setAttributeNS`, `toggleAttribute`,
//! `createElementNS`, `createAttributeNS`, `createDocumentType` and friends.
//!
//! Strings are UTF-8. Every byte of the encoding of a code point at or above
//! U+0080 is itself at or above 0x80, and every rule below treats that whole
//! range alike, so the checks run over bytes without decoding.

const std = @import("std");
const infra = @import("infra");

const namespaces = infra.namespaces;

pub const Error = error{ InvalidCharacterError, NamespaceError };

/// ASCII whitespace: U+0009 TAB, U+000A LF, U+000C FF, U+000D CR, U+0020 SPACE.
fn isAsciiWhitespace(c: u8) bool {
    return switch (c) {
        '\t', '\n', 0x0C, '\r', ' ' => true,
        else => false,
    };
}

/// "A string is a valid namespace prefix if its length is at least 1 and it
/// does not contain ASCII whitespace, U+0000 NULL, U+002F (/), or U+003E (>)."
pub fn isValidNamespacePrefix(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |c| {
        if (isAsciiWhitespace(c) or c == 0 or c == '/' or c == '>') return false;
    }
    return true;
}

/// "A string is a valid attribute local name if its length is at least 1 and
/// it does not contain ASCII whitespace, U+0000 NULL, U+002F (/), U+003D (=),
/// or U+003E (>)."
pub fn isValidAttributeLocalName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |c| {
        if (isAsciiWhitespace(c) or c == 0 or c == '/' or c == '=' or c == '>') return false;
    }
    return true;
}

/// "A string name is a valid element local name if the following steps
/// return true".
pub fn isValidElementLocalName(name: []const u8) bool {
    // Step 1: "If name's length is 0, then return false."
    if (name.len == 0) return false;

    // Step 2: "If name's 0th code point is an ASCII alpha": false if it
    // contains ASCII whitespace, U+0000 NULL, U+002F (/), or U+003E (>);
    // otherwise true.
    if (std.ascii.isAlphabetic(name[0])) {
        for (name) |c| {
            if (isAsciiWhitespace(c) or c == 0 or c == '/' or c == '>') return false;
        }
        return true;
    }

    // Step 3: "If name's 0th code point is not U+003A (:), U+005F (_), or in
    // the range U+0080 to U+10FFFF, inclusive, then return false."
    if (!(name[0] == ':' or name[0] == '_' or name[0] >= 0x80)) return false;

    // Step 4: "If name's subsequent code points, if any, are not ASCII alphas,
    // ASCII digits, U+002D (-), U+002E (.), U+003A (:), U+005F (_), or in the
    // range U+0080 to U+10FFFF, inclusive, then return false."
    for (name[1..]) |c| {
        if (c >= 0x80 or std.ascii.isAlphanumeric(c)) continue;
        switch (c) {
            '-', '.', ':', '_' => continue,
            else => return false,
        }
    }

    // Step 5: "Return true."
    return true;
}

/// HTML's "valid custom element name". It sits with the DOM name checks
/// because its first rule is one of them, and because DOM ("valid shadow host
/// name") and HTML (the element interface, `customElements.define()`) both ask
/// it.
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#valid-custom-element-name
pub fn isValidCustomElementName(name: []const u8) bool {
    // "name is a valid element local name;"
    if (!isValidElementLocalName(name)) return false;

    // "name's 0th code point is an ASCII lower alpha;"
    if (!std.ascii.isLower(name[0])) return false;

    // "name does not contain any ASCII upper alphas;" and "name contains a
    // U+002D (-);"
    var has_hyphen = false;
    for (name) |c| {
        if (std.ascii.isUpper(c)) return false;
        if (c == '-') has_hyphen = true;
    }
    if (!has_hyphen) return false;

    // "name is not one of the following" - every hyphenated element name in
    // SVG 2 and MathML.
    const reserved = [_][]const u8{
        "annotation-xml",
        "color-profile",
        "font-face",
        "font-face-src",
        "font-face-uri",
        "font-face-format",
        "font-face-name",
        "missing-glyph",
    };
    for (reserved) |r| {
        if (std.mem.eql(u8, name, r)) return false;
    }
    return true;
}

/// "A string is a valid doctype name if it does not contain ASCII whitespace,
/// U+0000 NULL, or U+003E (>)." The empty string is one.
pub fn isValidDoctypeName(name: []const u8) bool {
    for (name) |c| {
        if (isAsciiWhitespace(c) or c == 0 or c == '>') return false;
    }
    return true;
}

pub const Context = enum { attribute, element };

/// The (namespace, prefix, localName) triple "validate and extract" returns.
/// Every slice borrows from the arguments it was extracted from.
pub const Extracted = struct {
    namespace: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
};

/// DOM "validate and extract" a namespace and qualifiedName, given a context.
///
/// Spec: https://dom.spec.whatwg.org/#validate-and-extract
pub fn validateAndExtract(namespace_arg: ?[]const u8, qualified_name: []const u8, context: Context) Error!Extracted {
    // Step 1: "If namespace is the empty string, then set it to null."
    const namespace: ?[]const u8 = if (namespace_arg) |ns| (if (ns.len == 0) null else ns) else null;

    // Step 2: "Let prefix be null."
    var prefix: ?[]const u8 = null;

    // Step 3: "Let localName be qualifiedName."
    var local_name = qualified_name;

    // Step 4: "If qualifiedName contains a U+003A (:)": strictly split it on
    // U+003A (:), take piece 0 as the prefix and piece 1 as the local name.
    // Pieces past the second are dropped - "f:o:o" extracts ("f", "o").
    if (std.mem.indexOfScalar(u8, qualified_name, ':')) |first| {
        prefix = qualified_name[0..first];
        const rest = qualified_name[first + 1 ..];
        local_name = if (std.mem.indexOfScalar(u8, rest, ':')) |second| rest[0..second] else rest;

        // Step 4.4: "If prefix is not a valid namespace prefix, then throw an
        // "InvalidCharacterError" DOMException."
        if (!isValidNamespacePrefix(prefix.?)) return error.InvalidCharacterError;
    }

    // Step 5 asserts what step 4.4 just established.

    // Step 6: "If context is "attribute" and localName is not a valid
    // attribute local name, then throw an "InvalidCharacterError"."
    // Step 7: the same for "element" and a valid element local name.
    const valid = switch (context) {
        .attribute => isValidAttributeLocalName(local_name),
        .element => isValidElementLocalName(local_name),
    };
    if (!valid) return error.InvalidCharacterError;

    // Step 8: "If prefix is non-null and namespace is null, then throw a
    // "NamespaceError" DOMException."
    if (prefix != null and namespace == null) return error.NamespaceError;

    // Step 9: "If prefix is "xml" and namespace is not the XML namespace, then
    // throw a "NamespaceError" DOMException."
    if (prefix) |p| {
        if (std.mem.eql(u8, p, "xml") and !eqlOpt(namespace, namespaces.XML_NAMESPACE)) return error.NamespaceError;
    }

    // Step 10: "If either qualifiedName or prefix is "xmlns" and namespace is
    // not the XMLNS namespace, then throw a "NamespaceError" DOMException."
    const names_xmlns = std.mem.eql(u8, qualified_name, "xmlns") or
        (if (prefix) |p| std.mem.eql(u8, p, "xmlns") else false);
    if (names_xmlns and !eqlOpt(namespace, namespaces.XMLNS_NAMESPACE)) return error.NamespaceError;

    // Step 11: "If namespace is the XMLNS namespace and neither qualifiedName
    // nor prefix is "xmlns", then throw a "NamespaceError" DOMException."
    if (eqlOpt(namespace, namespaces.XMLNS_NAMESPACE) and !names_xmlns) return error.NamespaceError;

    // Step 12: "Return (namespace, prefix, localName)."
    return .{ .namespace = namespace, .prefix = prefix, .local_name = local_name };
}

fn eqlOpt(a: ?[]const u8, b: []const u8) bool {
    return if (a) |x| std.mem.eql(u8, x, b) else false;
}

test "valid custom element name" {
    const valid = [_][]const u8{ "my-element", "x-foo", "a-", "a-b.c_d", "math-\u{3b1}", "emotion-\u{1f60d}", "annotation-xml-custom" };
    for (valid) |name| try std.testing.expect(isValidCustomElementName(name));

    const invalid = [_][]const u8{
        "", // not a valid element local name
        "myelement", // no hyphen
        "My-element", // 0th code point is not an ASCII lower alpha
        "1-element",
        "-element",
        "my-Element", // an ASCII upper alpha
        "a- b", // ASCII whitespace: not a valid element local name
        "a-\x00",
        "a-/",
        "a->",
        "annotation-xml", // reserved
        "font-face-name",
        "missing-glyph",
    };
    for (invalid) |name| try std.testing.expect(!isValidCustomElementName(name));
}
