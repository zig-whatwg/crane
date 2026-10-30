//! Autofill field names.
//!
//! https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofill
//!
//! The `autocomplete` IDL attribute on input, select and textarea is not a
//! two-value enumeration. Its content attribute holds an ordered token list,
//! and on getting the element must return that list only when it forms a valid
//! "autofill expansion" - otherwise the empty string.
//!
//!     <input autocomplete="tel">                   -> "tel"
//!     <input autocomplete="home tel">              -> "home tel"
//!     <input autocomplete="shipping country">      -> "shipping country"
//!     <input autocomplete="section-foo bday">      -> "section-foo bday"
//!     <input autocomplete="username webauthn">     -> "username webauthn"
//!     <input autocomplete="foobar">                -> ""
//!     <input autocomplete="home country">          -> ""   (country is not a
//!                                                           contact field)
//!
//! That last case is why this cannot be a membership test: the contact token is
//! only allowed in front of a field name that actually belongs to a contact.
//!
//! Lives here rather than in an impl because input, select and textarea all
//! need it and impls are private to one another (AGENTS.md, "The impls
//! boundary"), so a helper shared between them has to sit outside `impls/`.

const std = @import("std");
const runtime = @import("runtime");

pub const Mantle = enum { expectation, anchor };

/// Grammar, read right to left:
///
///     [ section-* ] [ shipping | billing ]
///     [ home | work | mobile | fax | pager ] field-name [ webauthn ]
///
/// The optional pieces are only legal in this order.
pub const MAX_TOKENS: usize = 5;

/// Field names that may be prefixed by a contact token (home/work/…).
/// https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofill-field
const CONTACT_FIELDS = [_][]const u8{
    "tel",       "tel-country-code", "tel-national",     "tel-area-code",
    "tel-local", "tel-local-prefix", "tel-local-suffix", "tel-extension",
    "email",     "impp",
};

/// Every autofill field name. Order is the spec's, kept so a diff against the
/// table reads straight.
const FIELD_NAMES = [_][]const u8{
    "name",           "honorific-prefix", "given-name",           "additional-name",
    "family-name",    "honorific-suffix", "nickname",             "username",
    "new-password",   "current-password", "one-time-code",        "organization-title",
    "organization",   "street-address",   "address-line1",        "address-line2",
    "address-line3",  "address-level4",   "address-level3",       "address-level2",
    "address-level1", "country",          "country-name",         "postal-code",
    "cc-name",        "cc-given-name",    "cc-additional-name",   "cc-family-name",
    "cc-number",      "cc-exp",           "cc-exp-month",         "cc-exp-year",
    "cc-csc",         "cc-type",          "transaction-currency", "transaction-amount",
    "language",       "bday",             "bday-day",             "bday-month",
    "bday-year",      "sex",              "url",                  "photo",
    "tel",            "tel-country-code", "tel-national",         "tel-area-code",
    "tel-local",      "tel-local-prefix", "tel-local-suffix",     "tel-extension",
    "email",          "impp",
};

const CONTACT_TOKENS = [_][]const u8{ "home", "work", "mobile", "fax", "pager" };
const ADDRESSING_TOKENS = [_][]const u8{ "shipping", "billing" };

fn eqIgnoreCase(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(a, b);
}

fn isIn(list: []const []const u8, token: []const u8) bool {
    for (list) |candidate| {
        if (eqIgnoreCase(token, candidate)) return true;
    }
    return false;
}

fn isFieldName(token: []const u8) bool {
    return isIn(&FIELD_NAMES, token);
}

fn isContactField(token: []const u8) bool {
    return isIn(&CONTACT_FIELDS, token);
}

/// A "section-*" token. The suffix is free-form, so only the prefix is checked.
fn isSectionToken(token: []const u8) bool {
    return token.len >= "section-".len and
        std.ascii.startsWithIgnoreCase(token, "section-");
}

pub const Expansion = struct {
    /// Tokens in their original order, already validated. Slices borrow the
    /// caller's buffer.
    tokens: [MAX_TOKENS][]const u8 = undefined,
    len: usize = 0,

    pub fn slice(self: *const Expansion) []const []const u8 {
        return self.tokens[0..self.len];
    }
};

/// Parse an `autocomplete` attribute value.
///
/// Returns null when the value is not a valid autofill expansion, which the
/// caller reports as the empty IDL value. The anchor mantle (hidden input)
/// excludes on/off. Only the IDL projection is computed here: the default
/// field name can depend on the form, but its IDL value is always empty.
pub fn parse(value: []const u8, mantle: Mantle) ?Expansion {
    var it = std.mem.tokenizeAny(u8, value, " \t\n\r\x0C");
    var out = Expansion{};
    while (it.next()) |tok| {
        // More tokens than the grammar can hold means invalid; bail rather than
        // silently truncating into something that looks valid.
        if (out.len == MAX_TOKENS) return null;
        out.tokens[out.len] = tok;
        out.len += 1;
    }
    if (out.len == 0) return null;
    const tokens = out.slice();
    var i = tokens.len;

    // Autofill processing steps 8–10: only a single on/off token under the
    // expectation mantle has an IDL value.
    if (eqIgnoreCase(tokens[i - 1], "on") or eqIgnoreCase(tokens[i - 1], "off")) {
        return if (i == 1 and mantle == .expectation) out else null;
    }

    // Step 15.2 accepts webauthn by itself. With a prefix, step 15.5 requires
    // a Normal or Contact field before it, not on/off or another credential.
    if (eqIgnoreCase(tokens[i - 1], "webauthn")) {
        if (i == 1) return out;
        i -= 1;
    }

    // The field name is mandatory and sits at the end of what remains.
    const field = tokens[i - 1];
    if (!isFieldName(field)) return null;
    i -= 1;

    // Optional contact token, legal ONLY in front of a contact field.
    if (i > 0 and isIn(&CONTACT_TOKENS, tokens[i - 1])) {
        if (!isContactField(field)) return null;
        i -= 1;
    }

    // Optional addressing token.
    if (i > 0 and isIn(&ADDRESSING_TOKENS, tokens[i - 1])) {
        i -= 1;
    }

    // Optional section token.
    if (i > 0 and isSectionToken(tokens[i - 1])) {
        i -= 1;
    }

    // Anything left over is not part of the grammar.
    if (i != 0) return null;

    return out;
}

/// The control's IDL-exposed autofill value, evaluated from its current
/// attribute/mantle on each read (as WebKit AutofillData does). No token byte
/// limit: section-* is opaque and arbitrarily long. The attribute is borrowed;
/// the returned DOMString owns exactly its normalized serialization.
pub fn idlValue(instance: *runtime.Instance, mantle: Mantle) !runtime.DOMString {
    const dom = @import("dom");
    const data = dom.element_data.of(instance) orelse return error.InvalidState;
    const entry = dom.element_data.getAttributeByNamespaceAndLocalName(data, null, "autocomplete") orelse return .empty;
    const expansion = parse(entry.value, mantle) orelse return .empty;
    return runtime.DOMString.initOwned(try serializeAlloc(instance.ctx.allocator, expansion));
}

pub fn serializeAlloc(allocator: std.mem.Allocator, expansion: Expansion) ![]u8 {
    var size: usize = expansion.len - 1;
    for (expansion.slice()) |token| size += token.len;
    const bytes = try allocator.alloc(u8, size);
    _ = serialize(expansion, bytes).?;
    return bytes;
}

/// Write the expansion back out, lowercased and single-space separated, into
/// `buf`. Returns the written slice, or null if it does not fit.
pub fn serialize(expansion: Expansion, buf: []u8) ?[]const u8 {
    var written: usize = 0;
    for (expansion.slice(), 0..) |token, index| {
        if (index != 0) {
            if (written == buf.len) return null;
            buf[written] = ' ';
            written += 1;
        }
        if (written + token.len > buf.len) return null;
        for (token) |c| {
            buf[written] = std.ascii.toLower(c);
            written += 1;
        }
    }
    return buf[0..written];
}

test "a bare field name is a valid expansion" {
    const e = parse("tel", .expectation).?;
    try std.testing.expectEqual(@as(usize, 1), e.len);
}

test "contact tokens are only legal in front of a contact field" {
    try std.testing.expect(parse("home tel", .expectation) != null);
    // `country` is a field name but not a contact field, so `home country` is
    // NOT valid - a plain membership test would wrongly accept it.
    try std.testing.expect(parse("home country", .expectation) == null);
}

test "addressing and section tokens" {
    try std.testing.expect(parse("shipping country", .expectation) != null);
    try std.testing.expect(parse("section-foo bday", .expectation) != null);
    try std.testing.expect(parse("section-foo shipping home tel", .expectation) != null);
    try std.testing.expect(parse("section- bday", .expectation) != null);
}

test "webauthn is a trailing credential type" {
    try std.testing.expect(parse("username webauthn", .expectation) != null);
    try std.testing.expect(parse("webauthn", .expectation) != null);
    try std.testing.expect(parse("webauthn", .anchor) != null);
    try std.testing.expect(parse("section-login billing work email webauthn", .expectation) != null);
    try std.testing.expect(parse("on webauthn", .expectation) == null);
    try std.testing.expect(parse("section-login webauthn", .expectation) == null);
    try std.testing.expect(parse("webauthn username", .expectation) == null);
    try std.testing.expect(parse("section-login billing home work email webauthn", .expectation) == null);
}

test "unrecognised values are not expansions" {
    try std.testing.expect(parse("foobar", .expectation) == null);
    try std.testing.expect(parse("", .expectation) == null);
    try std.testing.expect(parse("   ", .expectation) == null);
    // Ordering matters: the grammar is section, addressing, contact, field.
    try std.testing.expect(parse("tel home", .expectation) == null);
    try std.testing.expect(parse("home\xc2\xa0tel", .expectation) == null);
}

test "serialize lowercases and normalises whitespace" {
    var buf: [64]u8 = undefined;
    const e = parse("SHIPPING   Country", .expectation).?;
    try std.testing.expectEqualStrings("shipping country", serialize(e, &buf).?);
}

test "on and off use ASCII whitespace and require the expectation mantle" {
    inline for (.{ " \tON\n", "\x0cOFF\r " }) |value| {
        try std.testing.expect(parse(value, .expectation) != null);
        try std.testing.expect(parse(value, .anchor) == null);
    }
    try std.testing.expect(parse("on off", .expectation) == null);
    try std.testing.expect(parse("section-x on", .expectation) == null);
}

test "section tokens are serialized without a fixed byte limit" {
    const value = "SECTION-" ++ &@as([600:0]u8, @splat('A')) ++ "\tSHIPPING\nNAME";
    const expected = "section-" ++ &@as([600:0]u8, @splat('a')) ++ " shipping name";
    const serialized = try serializeAlloc(std.testing.allocator, parse(value, .expectation).?);
    defer std.testing.allocator.free(serialized);
    try std.testing.expectEqualStrings(expected, serialized);
}
