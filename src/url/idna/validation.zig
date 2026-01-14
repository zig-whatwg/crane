//! IDNA Domain Validation
//!
//! Validates domain labels according to IDNA rules.

const std = @import("std");

pub const ValidationError = error{
    EmptyLabel,
    LabelTooLong,
    InvalidHyphen,
    InvalidCharacter,
};

/// Validate a domain label
///
/// Checks:
/// - Label is not empty
/// - (if be_strict) Label length is <= 63 characters (A4_2 / VerifyDnsLength)
/// - (if be_strict) Label doesn't start or end with hyphen (CheckHyphens)
/// - (if be_strict) Label doesn't have hyphen in positions 3-4 (unless xn--) (V3)
///
/// Per WHATWG URL Standard:
/// - CheckHyphens: be_strict (V3, V4 errors ignored when false)
/// - VerifyDnsLength: be_strict (A4_1, A4_2 errors ignored when false)
///
/// Parameters:
/// - `label`: The label to validate
/// - `be_strict`: If true, enforce hyphen and DNS length restrictions
pub fn validateLabel(label: []const u8, be_strict: bool) !void {
    // Empty label
    if (label.len == 0) {
        return ValidationError.EmptyLabel;
    }

    // Skip all checks if not strict
    // Per URL Standard: CheckHyphens=false and VerifyDnsLength=false when be_strict=false
    if (!be_strict) {
        return;
    }

    // Label too long (A4_2 - only when VerifyDnsLength=true)
    if (label.len > 63) {
        return ValidationError.LabelTooLong;
    }

    // Label starts with hyphen
    if (label[0] == '-') {
        return ValidationError.InvalidHyphen;
    }

    // Label ends with hyphen
    if (label[label.len - 1] == '-') {
        return ValidationError.InvalidHyphen;
    }

    // Check for hyphen in positions 3-4 (unless it's xn--)
    if (label.len >= 4 and label[2] == '-' and label[3] == '-') {
        // Exception: xn-- prefix is allowed (Punycode)
        if (!(label.len >= 4 and
            (label[0] == 'x' or label[0] == 'X') and
            (label[1] == 'n' or label[1] == 'N')))
        {
            return ValidationError.InvalidHyphen;
        }
    }
}

/// Validate a complete domain
///
/// Splits on '.' and validates each label
///
/// Parameters:
/// - `domain`: The domain to validate
/// - `check_hyphens`: If true, enforce UseSTD3ASCIIRules hyphen restrictions
pub fn validateDomain(domain: []const u8, check_hyphens: bool) !void {
    var iter = std.mem.splitScalar(u8, domain, '.');

    while (iter.next()) |label| {
        // Skip empty labels at the end (trailing dot)
        if (label.len == 0 and iter.peek() == null) {
            continue;
        }

        try validateLabel(label, check_hyphens);
    }
}
