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
/// - Label length is <= 63 characters
/// - (if check_hyphens) Label doesn't start or end with hyphen
/// - (if check_hyphens) Label doesn't have hyphen in positions 3-4 (unless xn--)
///
/// Parameters:
/// - `label`: The label to validate
/// - `check_hyphens`: If true, enforce UseSTD3ASCIIRules hyphen restrictions
pub fn validateLabel(label: []const u8, check_hyphens: bool) !void {
    // Empty label
    if (label.len == 0) {
        return ValidationError.EmptyLabel;
    }

    // Label too long
    if (label.len > 63) {
        return ValidationError.LabelTooLong;
    }

    // Skip hyphen checks if not strict
    if (!check_hyphens) {
        return;
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











