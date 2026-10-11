//! WHATWG URL domain parser and UTS #46 nontransitional IDNA processing.
//! https://url.spec.whatwg.org/#concept-domain-to-ascii
//! https://www.unicode.org/reports/tr46/#Processing
const std = @import("std");
const infra = @import("infra");
const validation = @import("validation.zig");
const punycode = @import("punycode.zig");
const normalization = @import("normalization.zig");
const mapping = @import("mapping.zig");
const bidi = @import("bidi.zig");
const context = @import("context.zig");
const data = @import("unicode_data.zig");
const idna_validation = validation;

pub const validation_mod = validation;
pub const punycode_mod = punycode;
pub const normalization_mod = normalization;
pub const mapping_mod = mapping;
pub const bidi_mod = bidi;
pub const context_mod = context;
/// Unicode properties shared with HTML directionality.
pub const unicode_data_mod = data;
pub const IDNAError = error{ InvalidDomain, ForbiddenCodePoint, PunycodeError, MappingError, ValidationError, BidiError, ContextError, OutOfMemory };

/// URL's forbidden domain code points, checked after IDNA normalization.
pub fn isForbiddenDomainCodePoint(cp: u21) bool {
    if (cp <= 0x20 or cp == 0x7f) return true;
    return switch (cp) {
        '#', '%', '/', ':', '<', '>', '?', '@', '[', '\\', ']', '^', '|' => true,
        else => false,
    };
}
fn isASCII(s: []const u8) bool {
    for (s) |byte| if (byte >= 0x80) return false;
    return true;
}

// UTS #46 section 4.1, applied to Unicode labels, never to their ACE spelling.
fn validateUnicodeLabel(allocator: std.mem.Allocator, label: []const u8, strict: bool, decoded: bool) !void {
    if (label.len == 0) return;
    // 1. Ordinary labels were normalized in Processing step 2; decoded ACE
    // labels must already be NFC and must not be mapped again (ICU processLabel).
    if (decoded) {
        const nfc = try normalization.normalize(allocator, label);
        defer allocator.free(nfc);
        if (!std.mem.eql(u8, nfc, label)) return error.ValidationError;
    }
    // 2 and 3. Hyphen restrictions apply only when CheckHyphens is true.
    if (strict) {
        if (label[0] == '-' or label[label.len - 1] == '-') return error.ValidationError;
        var characters = (try std.unicode.Utf8View.init(label)).iterator();
        _ = characters.nextCodepoint();
        _ = characters.nextCodepoint();
        if (characters.nextCodepoint() == '-' and characters.nextCodepoint() == '-') return error.ValidationError;
    } else if (std.mem.startsWith(u8, label, "xn--")) {
        // 4. No nested ACE prefix when CheckHyphens is false.
        return error.ValidationError;
    }
    var it = (std.unicode.Utf8View.init(label) catch return error.ValidationError).iterator();
    var first = true;
    while (it.nextCodepoint()) |cp| {
        // 5 and 6. No dot within a decoded label, nor any initial Mark.
        if (cp == '.' or (first and data.isMark(cp))) return error.ValidationError;
        first = false;
        // 7. Nontransitional processing allows only valid and deviation.
        switch (data.lookupIdnaStatus(cp).status) {
            .valid, .deviation => {},
            else => return error.ValidationError,
        }
        if (strict and cp < 0x80 and cp != '-' and !(cp >= 'a' and cp <= 'z') and !(cp >= '0' and cp <= '9')) return error.ValidationError;
    }
    // 8. CheckJoiners enables ContextJ, not the optional IDNA2008 ContextO.
    context.validateJoiners(label) catch return error.ContextError;
    // 9. Bidi is domain-wide and is checked after every label has been decoded.
}

const Labels = struct {
    list: infra.List([]const u8),
    fn deinit(self: *Labels, allocator: std.mem.Allocator) void {
        for (self.list.items()) |label| allocator.free(label);
        self.list.deinit();
    }
};

fn process(allocator: std.mem.Allocator, domain: []const u8, strict: bool) !Labels {
    // UTS #46 Processing 1-3: map, normalize the complete domain, then split.
    const mapped = try mapping.mapStringLenient(allocator, domain, false);
    defer allocator.free(mapped);
    const normalized = try normalization.normalize(allocator, mapped);
    defer allocator.free(normalized);
    var labels = Labels{ .list = infra.List([]const u8).init(allocator) };
    errdefer labels.deinit(allocator);
    var is_bidi = false;
    var iter = std.mem.splitScalar(u8, normalized, '.');
    while (iter.next()) |label| {
        // 4. Convert ACE to Unicode without remapping the decoded contents.
        const ace = std.mem.startsWith(u8, label, "xn--");
        const unicode = if (ace) blk: {
            if (!isASCII(label)) return error.PunycodeError;
            const decoded = punycode.decode(allocator, label[4..]) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => return error.PunycodeError,
            };
            if (decoded.len == 0 or isASCII(decoded)) {
                allocator.free(decoded);
                return error.PunycodeError;
            }
            break :blk decoded;
        } else try allocator.dupe(u8, label);
        errdefer allocator.free(unicode);
        try validateUnicodeLabel(allocator, unicode, strict, ace);
        is_bidi = is_bidi or bidi.isBidi(unicode);
        try labels.list.append(unicode);
    }
    if (is_bidi) for (labels.list.items()) |label| {
        bidi.validateBidi(label) catch return error.BidiError;
    };
    return labels;
}

/// URL domain parser. Non-strict ASCII input is lowercased without UTS #46;
/// other input runs ToASCII with CheckBidi/CheckJoiners and nontransitional
/// processing. Hyphen, STD3 and DNS length checks follow be_strict.
/// Caller owns the returned string. All allocation failures propagate.
pub fn domainToASCII(allocator: std.mem.Allocator, domain: []const u8, be_strict: bool) ![]u8 {
    // URL domain parser step 5. This shortcut is domain-wide, before mapping.
    // Chromium url_canon_host.cc and WebKit URLParser::domainToASCII agree.
    // wpt.fyi stable 2026-10-06: Chrome/Safari pass 761/761 ASCII ACE error
    // cases; Firefox passes 4/761 (runs 6218298311311360/5164107446878208/
    // 4877098740350976). Engine designs (no copied code):
    // https://github.com/chromium/chromium/blob/main/url/url_canon_host.cc
    // https://github.com/WebKit/WebKit/blob/main/Source/WTF/wtf/URLParser.cpp
    if (!be_strict and isASCII(domain)) {
        if (domain.len == 0) return error.InvalidDomain;
        const result = try allocator.dupe(u8, domain);
        errdefer allocator.free(result);
        for (result) |*byte| {
            if (isForbiddenDomainCodePoint(byte.*)) return error.ForbiddenCodePoint;
            byte.* = std.ascii.toLower(byte.*);
        }
        return result;
    }
    var labels = try process(allocator, domain, be_strict);
    defer labels.deinit(allocator);
    var output = infra.List(u8).init(allocator);
    defer output.deinit();
    // UTS #46 ToASCII 2-3: encode only labels with non-ASCII characters.
    for (labels.list.items(), 0..) |label, i| {
        if (i != 0) try output.append('.');
        const start = output.len;
        if (isASCII(label)) {
            try output.appendSlice(label);
        } else {
            const encoded = punycode.encode(allocator, label) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => return error.PunycodeError,
            };
            defer allocator.free(encoded);
            try output.appendSlice("xn--");
            try output.appendSlice(encoded);
        }
        // 4. VerifyDnsLength applies to the ASCII output, not Unicode byte length.
        if (be_strict) {
            const length = output.len - start;
            const root = i + 1 == labels.list.len and i != 0;
            if (length > 63 or (length == 0 and !root)) return error.ValidationError;
        }
    }
    if (output.len == 0) return error.InvalidDomain;
    if (be_strict) {
        const length = output.len - @intFromBool(output.items()[output.len - 1] == '.');
        if (length == 0 or length > 253) return error.ValidationError;
    }
    // URL steps 7-8: only the final ASCII result is tested for forbidden points.
    for (output.items()) |byte| if (isForbiddenDomainCodePoint(byte)) return error.ForbiddenCodePoint;
    return output.toOwnedSlice();
}

/// Process a single label through UTS46 ToUnicode
fn processLabelToUnicode(
    allocator: std.mem.Allocator,
    label: []const u8,
    be_strict: bool,
) ![]u8 {
    // Empty labels are valid - domains like "." and ".." produce empty labels
    if (label.len == 0) {
        return try allocator.dupe(u8, "");
    }

    // Check if label starts with "xn--" (Punycode)
    if (std.mem.startsWith(u8, label, "xn--") or
        std.mem.startsWith(u8, label, "XN--") or
        std.mem.startsWith(u8, label, "Xn--") or
        std.mem.startsWith(u8, label, "xN--"))
    {
        // Extract Punycode part (after "xn--")
        const punycode_part = label[4..];

        // Decode Punycode
        const decoded = punycode.decode(allocator, punycode_part) catch {
            // If Punycode decode fails, return original label
            return try allocator.dupe(u8, label);
        };
        errdefer allocator.free(decoded);

        // Validate decoded label if strict mode enabled
        // Per UTS46: CheckBidi, CheckJoiners, UseSTD3ASCIIRules
        if (be_strict) {
            // Validate bidi rules
            bidi.validateBidi(decoded) catch {
                return IDNAError.BidiError;
            };

            // Validate contextual rules (joiners)
            context.validateContext(decoded) catch {
                return IDNAError.ContextError;
            };

            // Validate label structure
            idna_validation.validateLabel(decoded, be_strict) catch {
                return IDNAError.ValidationError;
            };
        }

        return decoded;
    }

    // Not Punycode - validate and return as-is
    const result = try allocator.dupe(u8, label);
    errdefer allocator.free(result);

    if (be_strict) {
        // Validate non-Punycode labels in strict mode
        idna_validation.validateLabel(result, be_strict) catch {
            return IDNAError.ValidationError;
        };

        bidi.validateBidi(result) catch {
            return IDNAError.BidiError;
        };

        context.validateContext(result) catch {
            return IDNAError.ContextError;
        };
    }

    return result;
}

/// Domain to Unicode algorithm (spec lines 381-383)
///
/// Implements UTS46 Unicode ToUnicode with:
/// - CheckHyphens: be_strict
/// - CheckBidi: true
/// - CheckJoiners: true
/// - UseSTD3ASCIIRules: be_strict
/// - Transitional_Processing: false
/// - IgnoreInvalidPunycode: false
///
/// Parameters:
/// - `domain`: Input domain string (may be ASCII or Punycode)
/// - `be_strict`: Enable strict validation (per spec)
///
/// Returns: Unicode domain string or error
pub fn domainToUnicode(
    allocator: std.mem.Allocator,
    domain: []const u8,
    be_strict: bool,
) ![]u8 {
    // Step 0: Map the entire domain first to normalize characters like U+3002 (。) to '.'
    const domain_mapped = mapping.mapString(allocator, domain, be_strict) catch {
        // If mapping fails, just use the original domain
        const dup = try allocator.dupe(u8, domain);
        return dup;
    };
    defer allocator.free(domain_mapped);

    // Special case: dot-only domains like "." and ".."
    // These should pass through as-is without IDNA processing
    var all_dots = true;
    for (domain_mapped) |c| {
        if (c != '.') {
            all_dots = false;
            break;
        }
    }
    if (all_dots and domain_mapped.len > 0) {
        return try allocator.dupe(u8, domain_mapped);
    }

    // Step 1: Split mapped domain into labels
    var labels = infra.List([]const u8).init(allocator);
    defer {
        for (labels.items()) |label| {
            allocator.free(label);
        }
        labels.deinit();
    }

    var iter = std.mem.splitScalar(u8, domain_mapped, '.');
    while (iter.next()) |label| {
        // Process each label
        const processed = try processLabelToUnicode(allocator, label, be_strict);
        try labels.append(processed);
    }

    // Step 2: Join labels with dots
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    for (labels.items(), 0..) |label, i| {
        if (i > 0) {
            try result.append('.');
        }
        try result.appendSlice(label);
    }

    return result.toOwnedSlice();
}
