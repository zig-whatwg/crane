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

test "validation - valid label" {
    try validateLabel("example", true);
    try validateLabel("ex-ample", true);
    try validateLabel("example123", true);
}

test "validation - valid label without hyphen checks" {
    try validateLabel("example", false);
    try validateLabel("ex-ample", false);
    try validateLabel("-example", false); // OK when not strict
    try validateLabel("example-", false); // OK when not strict
    try validateLabel("ab--cd", false); // OK when not strict
}

test "validation - empty label" {
    try std.testing.expectError(ValidationError.EmptyLabel, validateLabel("", true));
    try std.testing.expectError(ValidationError.EmptyLabel, validateLabel("", false));
}

test "validation - label too long" {
    const long_label = "a" ** 64;
    try std.testing.expectError(ValidationError.LabelTooLong, validateLabel(long_label, true));
    try std.testing.expectError(ValidationError.LabelTooLong, validateLabel(long_label, false));
}

test "validation - starts with hyphen (strict)" {
    try std.testing.expectError(ValidationError.InvalidHyphen, validateLabel("-example", true));
}

test "validation - ends with hyphen (strict)" {
    try std.testing.expectError(ValidationError.InvalidHyphen, validateLabel("example-", true));
}

test "validation - hyphen in positions 3-4 (strict)" {
    try std.testing.expectError(ValidationError.InvalidHyphen, validateLabel("ab--cd", true));
}

test "validation - xn-- prefix allowed" {
    try validateLabel("xn--example", true);
    try validateLabel("XN--example", true);
}

test "validation - complete domain" {
    try validateDomain("example.com", true);
    try validateDomain("sub.example.com", true);
    try validateDomain("example.com.", true); // Trailing dot OK
}

test "validation - invalid domain labels (strict)" {
    try std.testing.expectError(ValidationError.InvalidHyphen, validateDomain("-invalid.com", true));
    try std.testing.expectError(ValidationError.EmptyLabel, validateDomain("example..com", true));
}

test "validation - lenient domain labels (not strict)" {
    try validateDomain("a.b-.c", false); // OK when not strict
    try validateDomain("a.-.c", false); // OK when not strict
}
