//! Validation Errors
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#validation-error
//! Spec Reference: Lines 35-101
//!
//! Validation errors indicate a mismatch between input and valid input.
//! User agents (especially conformance checkers) should report these.
//!
//! A validation error does NOT cause parser termination. The parser continues
//! and may produce a valid URL despite validation errors.

const std = @import("std");
const infra = @import("infra");

/// Validation Error Types (spec lines 35-101)
///
/// Each error type has a specific meaning and location in the spec.
/// Errors are grouped by category (IDNA, Host parsing, URL parsing).
pub const ValidationError = enum {
    // IDNA Errors (spec lines 43-48)

    /// Unicode ToASCII records an error or returns empty string (spec line 43)
    /// Failure: Yes
    domain_to_ascii,

    /// Input's host contains forbidden domain code point (spec line 45)
    /// Failure: Yes
    /// Example: https://exa%23mple.org
    domain_invalid_code_point,

    /// Unicode ToUnicode records an error (spec line 47)
    /// Failure: No (cosmetic)
    domain_to_unicode,

    // Host Parsing Errors (spec lines 49-80)

    /// Opaque host contains forbidden host code point (spec line 49)
    /// Failure: Yes
    /// Example: foo://exa[mple.org
    host_invalid_code_point,

    /// IPv4 address ends with U+002E (.) (spec line 51)
    /// Failure: No (cosmetic)
    /// Example: https://127.0.0.1./
    ipv4_empty_part,

    /// IPv4 address does not consist of exactly 4 parts (spec line 53)
    /// Failure: Yes
    /// Example: https://1.2.3.4.5/
    ipv4_too_many_parts,

    /// IPv4 address part is not numeric (spec line 55)
    /// Failure: Yes
    /// Example: https://test.42
    ipv4_non_numeric_part,

    /// IPv4 address contains hexadecimal or octal digits (spec line 57)
    /// Failure: No (cosmetic)
    /// Example: https://127.0.0x0.1
    ipv4_non_decimal_part,

    /// IPv4 address part exceeds 255 (spec line 59)
    /// Failure: Yes (only if applicable to last part)
    /// Example: https://255.255.4000.1
    ipv4_out_of_range_part,

    /// IPv6 address missing closing U+005D (]) (spec line 61)
    /// Failure: Yes
    /// Example: https://[::1
    ipv6_unclosed,

    /// IPv6 address begins with improper compression (spec line 63)
    /// Failure: Yes
    /// Example: https://[:1]
    ipv6_invalid_compression,

    /// IPv6 address contains more than 8 pieces (spec line 65)
    /// Failure: Yes
    /// Example: https://[1:2:3:4:5:6:7:8:9]
    ipv6_too_many_pieces,

    /// IPv6 address compressed in more than one spot (spec line 67)
    /// Failure: Yes
    /// Example: https://[1::1::1]
    ipv6_multiple_compression,

    /// IPv6 address contains invalid code point or ends unexpectedly (spec line 69)
    /// Failure: Yes
    /// Example: https://[1:2:3!:4]
    ipv6_invalid_code_point,

    /// Uncompressed IPv6 address contains fewer than 8 pieces (spec line 71)
    /// Failure: Yes
    /// Example: https://[1:2:3]
    ipv6_too_few_pieces,

    /// IPv6 with IPv4: IPv6 has more than 6 pieces (spec line 73)
    /// Failure: Yes
    /// Example: https://[1:1:1:1:1:1:1:127.0.0.1]
    ipv4_in_ipv6_too_many_pieces,

    /// IPv6 with IPv4: IPv4 part invalid (spec line 75)
    /// Failure: Yes
    /// Example: https://[ffff::.0.0.1]
    ipv4_in_ipv6_invalid_code_point,

    /// IPv6 with IPv4: IPv4 part exceeds 255 (spec line 77)
    /// Failure: Yes
    /// Example: https://[ffff::127.0.0.4000]
    ipv4_in_ipv6_out_of_range_part,

    /// IPv6 with IPv4: too few IPv4 parts (spec line 79)
    /// Failure: Yes
    /// Example: https://[ffff::127.0.0]
    ipv4_in_ipv6_too_few_parts,

    // URL Parsing Errors (spec lines 81-101)

    /// Code point is not a URL unit (spec line 81)
    /// Failure: No (cosmetic)
    /// Example: https://example.org/>
    invalid_url_unit,

    /// Special scheme not followed by "//" (spec line 83)
    /// Failure: No (cosmetic)
    /// Example: file:c:/my-secret-folder
    special_scheme_missing_following_solidus,

    /// Input missing scheme (spec line 85)
    /// Failure: Yes
    /// Example: new URL("💩") with no base
    missing_scheme_non_relative_url,

    /// URL uses U+005C (\) instead of U+002F (/) (spec line 87)
    /// Failure: No (cosmetic)
    /// Example: https://example.org\path\to\file
    invalid_reverse_solidus,

    /// Input includes credentials (spec line 89)
    /// Failure: No (informational)
    /// Example: https://user@example.org
    invalid_credentials,

    /// Special scheme but no host (spec line 91)
    /// Failure: Yes
    /// Example: https://#fragment
    host_missing,

    /// Port is too big (>65535) (spec line 93)
    /// Failure: Yes
    /// Example: https://example.org:70000
    port_out_of_range,

    /// Port is invalid (spec line 95)
    /// Failure: Yes
    /// Example: https://example.org:7z
    port_invalid,

    /// Relative URL starts with Windows drive letter and base is file: (spec line 97)
    /// Failure: No (cosmetic)
    /// Example: new URL("/c:/path", "file:///c:/")
    file_invalid_windows_drive_letter,

    /// file: URL's host is a Windows drive letter (spec line 99)
    /// Failure: No (cosmetic)
    /// Example: file://c:
    file_invalid_windows_drive_letter_host,

    pub fn isFailure(self: ValidationError) bool {
        return switch (self) {
            // Failures
            .domain_to_ascii,
            .domain_invalid_code_point,
            .host_invalid_code_point,
            .ipv4_too_many_parts,
            .ipv4_non_numeric_part,
            .ipv4_out_of_range_part,
            .ipv6_unclosed,
            .ipv6_invalid_compression,
            .ipv6_too_many_pieces,
            .ipv6_multiple_compression,
            .ipv6_invalid_code_point,
            .ipv6_too_few_pieces,
            .ipv4_in_ipv6_too_many_pieces,
            .ipv4_in_ipv6_invalid_code_point,
            .ipv4_in_ipv6_out_of_range_part,
            .ipv4_in_ipv6_too_few_parts,
            .missing_scheme_non_relative_url,
            .host_missing,
            .port_out_of_range,
            .port_invalid,
            => true,

            // Non-failures (cosmetic/informational)
            .domain_to_unicode,
            .ipv4_empty_part,
            .ipv4_non_decimal_part,
            .invalid_url_unit,
            .special_scheme_missing_following_solidus,
            .invalid_reverse_solidus,
            .invalid_credentials,
            .file_invalid_windows_drive_letter,
            .file_invalid_windows_drive_letter_host,
            => false,
        };
    }

    pub fn description(self: ValidationError) []const u8 {
        return switch (self) {
            .domain_to_ascii => "Unicode ToASCII records an error or returns empty string",
            .domain_invalid_code_point => "Input's host contains a forbidden domain code point",
            .domain_to_unicode => "Unicode ToUnicode records an error",
            .host_invalid_code_point => "An opaque host contains a forbidden host code point",
            .ipv4_empty_part => "An IPv4 address ends with a U+002E (.)",
            .ipv4_too_many_parts => "An IPv4 address does not consist of exactly 4 parts",
            .ipv4_non_numeric_part => "An IPv4 address part is not numeric",
            .ipv4_non_decimal_part => "IPv4 address contains hexadecimal or octal digits",
            .ipv4_out_of_range_part => "An IPv4 address part exceeds 255",
            .ipv6_unclosed => "An IPv6 address is missing the closing U+005D (])",
            .ipv6_invalid_compression => "An IPv6 address begins with improper compression",
            .ipv6_too_many_pieces => "An IPv6 address contains more than 8 pieces",
            .ipv6_multiple_compression => "An IPv6 address is compressed in more than one spot",
            .ipv6_invalid_code_point => "An IPv6 address contains invalid code point or ends unexpectedly",
            .ipv6_too_few_pieces => "An uncompressed IPv6 address contains fewer than 8 pieces",
            .ipv4_in_ipv6_too_many_pieces => "IPv6 address with IPv4: IPv6 has more than 6 pieces",
            .ipv4_in_ipv6_invalid_code_point => "IPv6 address with IPv4: IPv4 part is invalid",
            .ipv4_in_ipv6_out_of_range_part => "IPv6 address with IPv4: IPv4 part exceeds 255",
            .ipv4_in_ipv6_too_few_parts => "IPv6 address with IPv4: too few IPv4 parts",
            .invalid_url_unit => "A code point is found that is not a URL unit",
            .special_scheme_missing_following_solidus => "The input's scheme is not followed by //",
            .missing_scheme_non_relative_url => "Input missing scheme and no usable base URL",
            .invalid_reverse_solidus => "The URL uses U+005C (\\) instead of U+002F (/)",
            .invalid_credentials => "The input includes credentials",
            .host_missing => "Special scheme URL does not contain a host",
            .port_out_of_range => "The input's port is too big",
            .port_invalid => "The input's port is invalid",
            .file_invalid_windows_drive_letter => "Relative URL starts with Windows drive letter and base is file:",
            .file_invalid_windows_drive_letter_host => "A file: URL's host is a Windows drive letter",
        };
    }
};

/// Validation error collector
///
/// Collects validation errors during URL parsing. Errors do not stop parsing.
pub const ValidationErrorCollector = struct {
    errors: infra.List(ValidationError),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ValidationErrorCollector {
        return .{
            .errors = infra.List(ValidationError).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ValidationErrorCollector) void {
        self.errors.deinit();
    }

    /// Record a validation error
    pub fn record(self: *ValidationErrorCollector, err: ValidationError) !void {
        try self.errors.append(err);
    }

    /// Check if any validation errors occurred
    pub fn hasErrors(self: *const ValidationErrorCollector) bool {
        return self.errors.len > 0;
    }

    /// Check if any failures occurred (as opposed to cosmetic errors)
    pub fn hasFailures(self: *const ValidationErrorCollector) bool {
        for (self.errors.toSlice()) |err| {
            if (err.isFailure()) return true;
        }
        return false;
    }

    /// Get all errors
    pub fn getErrors(self: *const ValidationErrorCollector) []const ValidationError {
        return self.errors.toSlice();
    }
};

test "validation error - isFailure" {
    try std.testing.expect(ValidationError.domain_to_ascii.isFailure());
    try std.testing.expect(ValidationError.ipv4_too_many_parts.isFailure());
    try std.testing.expect(!ValidationError.ipv4_empty_part.isFailure());
    try std.testing.expect(!ValidationError.invalid_credentials.isFailure());
}

test "validation error collector" {
    const allocator = std.testing.allocator;

    var collector = ValidationErrorCollector.init(allocator);
    defer collector.deinit();

    try std.testing.expect(!collector.hasErrors());
    try std.testing.expect(!collector.hasFailures());

    try collector.record(.ipv4_empty_part); // Cosmetic
    try std.testing.expect(collector.hasErrors());
    try std.testing.expect(!collector.hasFailures());

    try collector.record(.ipv4_too_many_parts); // Failure
    try std.testing.expect(collector.hasFailures());

    const errors = collector.getErrors();
    try std.testing.expectEqual(@as(usize, 2), errors.len);
}
