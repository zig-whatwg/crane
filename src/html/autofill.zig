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
    return token.len > "section-".len and
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
/// caller reports as the empty string. "on" and "off" are handled by the
/// caller: they are a separate branch of the attribute's grammar, not field
/// names, and they differ between form (`on` default) and control (`""`).
pub fn parse(value: []const u8) ?Expansion {
    var it = std.mem.tokenizeAny(u8, value, " \t\n\r\x0C");
    var tokens: [MAX_TOKENS + 1][]const u8 = undefined;
    var n: usize = 0;
    while (it.next()) |tok| {
        // More tokens than the grammar can hold means invalid; bail rather than
        // silently truncating into something that looks valid.
        if (n == tokens.len) return null;
        tokens[n] = tok;
        n += 1;
    }
    if (n == 0) return null;

    var out = Expansion{};
    var i = n;

    // Read right to left. Optional trailing credential type.
    if (i > 1 and eqIgnoreCase(tokens[i - 1], "webauthn")) {
        i -= 1;
    }
    if (i == 0) return null;

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

    out.len = n;
    var k: usize = 0;
    while (k < n) : (k += 1) out.tokens[k] = tokens[k];
    return out;
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
    const e = parse("tel").?;
    try std.testing.expectEqual(@as(usize, 1), e.len);
}

test "contact tokens are only legal in front of a contact field" {
    try std.testing.expect(parse("home tel") != null);
    // `country` is a field name but not a contact field, so `home country` is
    // NOT valid - a plain membership test would wrongly accept it.
    try std.testing.expect(parse("home country") == null);
}

test "addressing and section tokens" {
    try std.testing.expect(parse("shipping country") != null);
    try std.testing.expect(parse("section-foo bday") != null);
    try std.testing.expect(parse("section-foo shipping home tel") != null);
}

test "webauthn is a trailing credential type" {
    try std.testing.expect(parse("username webauthn") != null);
    // On its own it is not a field name.
    try std.testing.expect(parse("webauthn") == null);
}

test "unrecognised values are not expansions" {
    try std.testing.expect(parse("foobar") == null);
    try std.testing.expect(parse("") == null);
    try std.testing.expect(parse("   ") == null);
    // Ordering matters: the grammar is section, addressing, contact, field.
    try std.testing.expect(parse("tel home") == null);
}

test "serialize lowercases and normalises whitespace" {
    var buf: [64]u8 = undefined;
    const e = parse("SHIPPING   Country").?;
    try std.testing.expectEqualStrings("shipping country", serialize(e, &buf).?);
}
