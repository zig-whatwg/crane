//! URL Validation Errors
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#validation-errors
//! Spec Reference: Lines 35-101
//!
//! This module defines all validation error types from the WHATWG URL specification.
//! Validation errors indicate a mismatch between input and valid input. They do not
//! cause parser termination unless explicitly marked as "failure" errors.
//!
//! ## Error Categories
//!
//! 1. **IDNA Errors** - Unicode domain name handling
//! 2. **Host Parsing Errors** - Domain, IPv4, IPv6 parsing
//! 3. **URL Parsing Errors** - General URL syntax errors
//!
//! ## Usage
//!
//! ```zig
//! const validation = @import("validation");
//!
//! // Optional validation error collection
//! var errors = infra.List(validation.ValidationError).init(allocator);
//! defer errors.deinit();
//!
//! // Record error during parsing
//! try errors.append(.{ .type = .invalid_url_unit, .position = 5 });
//! ```

const std = @import("std");

/// Validation error type (spec lines 41-100)
///
/// Each error has:
/// - Type: The specific error that occurred
/// - Position: Character position in input where error occurred (optional)
/// - Message: Human-readable description (optional)
pub const ValidationError = struct {
    type: ErrorType,
    position: ?usize = null,
    message: ?[]const u8 = null,

    /// Check if this error causes parser failure
    pub fn isFailure(self: ValidationError) bool {
        return self.type.isFailure();
    }
};

/// Validation error types from spec (lines 41-100)
///
/// Format: error_name corresponds to spec's "error-name"
pub const ErrorType = enum {
    // IDNA errors (lines 43-48)
    /// Unicode ToASCII records an error or returns empty string (FAILURE)
    domain_to_ascii,
    /// Host contains a forbidden domain code point (FAILURE)
    domain_invalid_code_point,
    /// Unicode ToUnicode records an error (non-failure)
    domain_to_unicode,

    // Host parsing errors (lines 49-80)
    /// Opaque host contains a forbidden host code point (FAILURE)
    host_invalid_code_point,
    /// IPv4 address ends with U+002E (.) (non-failure)
    ipv4_empty_part,
    /// IPv4 address does not consist of exactly 4 parts (FAILURE)
    ipv4_too_many_parts,
    /// IPv4 address part is not numeric (FAILURE)
    ipv4_non_numeric_part,
    /// IPv4 address contains hex or octal digits (non-failure)
    ipv4_non_decimal_part,
    /// IPv4 address part exceeds 255 (FAILURE if last part)
    ipv4_out_of_range_part,
    /// IPv6 address missing closing U+005D (]) (FAILURE)
    ipv6_unclosed,
    /// IPv6 address begins with improper compression (FAILURE)
    ipv6_invalid_compression,
    /// IPv6 address contains more than 8 pieces (FAILURE)
    ipv6_too_many_pieces,
    /// IPv6 address compressed in more than one spot (FAILURE)
    ipv6_multiple_compression,
    /// IPv6 address contains invalid code point (FAILURE)
    ipv6_invalid_code_point,
    /// Uncompressed IPv6 address contains fewer than 8 pieces (FAILURE)
    ipv6_too_few_pieces,
    /// IPv6 address with IPv4: more than 6 pieces (FAILURE)
    ipv4_in_ipv6_too_many_pieces,
    /// IPv6 address with IPv4: invalid IPv4 part (FAILURE)
    ipv4_in_ipv6_invalid_code_point,
    /// IPv6 address with IPv4: IPv4 part exceeds 255 (FAILURE)
    ipv4_in_ipv6_out_of_range_part,
    /// IPv6 address with IPv4: too few IPv4 parts (FAILURE)
    ipv4_in_ipv6_too_few_parts,

    // URL parsing errors (lines 81-100)
    /// Code point is not a URL unit (non-failure)
    invalid_url_unit,
    /// Special scheme not followed by "//" (non-failure)
    special_scheme_missing_following_solidus,
    /// Input missing scheme and no valid base URL (FAILURE)
    missing_scheme_non_relative_url,
    /// Special scheme uses \ instead of / (non-failure)
    invalid_reverse_solidus,
    /// Input includes credentials (non-failure)
    invalid_credentials,
    /// Special scheme but no host (FAILURE)
    host_missing,
    /// Port is too big (FAILURE)
    port_out_of_range,
    /// Port is invalid (FAILURE)
    port_invalid,
    /// Relative URL starts with Windows drive letter (non-failure)
    file_invalid_windows_drive_letter,
    /// file: URL's host is a Windows drive letter (non-failure)
    file_invalid_windows_drive_letter_host,

    /// Check if this error type causes parser failure
    ///
    /// Failure errors:
    /// - All IDNA errors except domain-to-Unicode
    /// - Most host parsing errors
    /// - URL parsing: missing-scheme-non-relative-URL, host-missing, port errors
    ///
    /// Non-failure errors (parser continues):
    /// - domain-to-Unicode
    /// - IPv4-empty-part, IPv4-non-decimal-part
    /// - invalid-URL-unit, special-scheme-missing-following-solidus
    /// - invalid-reverse-solidus, invalid-credentials
    /// - file-invalid-Windows-drive-letter*
    pub fn isFailure(self: ErrorType) bool {
        return switch (self) {
            // IDNA failures
            .domain_to_ascii,
            .domain_invalid_code_point,
            // Host parsing failures
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
            // URL parsing failures
            .missing_scheme_non_relative_url,
            .host_missing,
            .port_out_of_range,
            .port_invalid,
            => true,

            // Non-failures
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

    /// Get human-readable error description
    pub fn description(self: ErrorType) []const u8 {
        return switch (self) {
            .domain_to_ascii => "Unicode ToASCII records an error or returns empty string",
            .domain_invalid_code_point => "Host contains a forbidden domain code point",
            .domain_to_unicode => "Unicode ToUnicode records an error",
            .host_invalid_code_point => "Opaque host contains a forbidden host code point",
            .ipv4_empty_part => "IPv4 address ends with U+002E (.)",
            .ipv4_too_many_parts => "IPv4 address does not consist of exactly 4 parts",
            .ipv4_non_numeric_part => "IPv4 address part is not numeric",
            .ipv4_non_decimal_part => "IPv4 address contains hexadecimal or octal digits",
            .ipv4_out_of_range_part => "IPv4 address part exceeds 255",
            .ipv6_unclosed => "IPv6 address missing closing U+005D (])",
            .ipv6_invalid_compression => "IPv6 address begins with improper compression",
            .ipv6_too_many_pieces => "IPv6 address contains more than 8 pieces",
            .ipv6_multiple_compression => "IPv6 address compressed in more than one spot",
            .ipv6_invalid_code_point => "IPv6 address contains invalid code point or unexpectedly ends",
            .ipv6_too_few_pieces => "Uncompressed IPv6 address contains fewer than 8 pieces",
            .ipv4_in_ipv6_too_many_pieces => "IPv6 address with IPv4: more than 6 pieces",
            .ipv4_in_ipv6_invalid_code_point => "IPv6 address with IPv4: invalid IPv4 part",
            .ipv4_in_ipv6_out_of_range_part => "IPv6 address with IPv4: IPv4 part exceeds 255",
            .ipv4_in_ipv6_too_few_parts => "IPv6 address with IPv4: too few IPv4 parts",
            .invalid_url_unit => "Code point is not a URL unit",
            .special_scheme_missing_following_solidus => "Special scheme not followed by \"//\"",
            .missing_scheme_non_relative_url => "Input missing scheme and no valid base URL",
            .invalid_reverse_solidus => "Special scheme uses \\ instead of /",
            .invalid_credentials => "Input includes credentials",
            .host_missing => "Special scheme but no host",
            .port_out_of_range => "Port is too big",
            .port_invalid => "Port is invalid",
            .file_invalid_windows_drive_letter => "Relative URL starts with Windows drive letter",
            .file_invalid_windows_drive_letter_host => "file: URL's host is a Windows drive letter",
        };
    }
};



