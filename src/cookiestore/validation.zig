//! Cookie Validation Utilities (RFC 6265bis)
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//! RFC 6265bis: https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
//!
//! This module implements validation rules for cookie names, values, and attributes
//! according to RFC 6265bis and the WHATWG Cookie Store specification.

const std = @import("std");

/// Maximum name/value pair size per RFC 6265bis
/// https://cookiestore.spec.whatwg.org/#cookie-maximum-name-value-pair-size
pub const MAX_NAME_VALUE_SIZE: usize = 4096;

/// Maximum attribute value size per RFC 6265bis
/// https://cookiestore.spec.whatwg.org/#cookie-maximum-attribute-value-size
pub const MAX_ATTRIBUTE_VALUE_SIZE: usize = 1024;

/// Validation error types for cookies
pub const ValidationError = error{
    /// Name contains invalid characters (semicolon, equals, C0 controls, DEL)
    InvalidNameCharacter,
    /// Value contains invalid characters (semicolon, C0 controls, DEL)
    InvalidValueCharacter,
    /// Name is empty but value doesn't meet requirements
    EmptyNameInvalid,
    /// Combined name+value exceeds 4096 bytes
    NameValueTooLarge,
    /// Attribute value exceeds 1024 bytes
    AttributeTooLarge,
    /// __Host- prefix requirements not met
    HostPrefixInvalid,
    /// __Secure- prefix requirements not met
    SecurePrefixInvalid,
    /// Reserved prefix used (__http-, __host-http-)
    ReservedPrefix,
    /// Domain attribute starts with dot
    DomainStartsWithDot,
    /// Path doesn't start with /
    PathNotAbsolute,
    /// Domain is a public suffix (cookie would be too broad)
    DomainIsPublicSuffix,
    /// Domain is not a suffix of the request host
    DomainMismatch,
};

/// Check if a character is a C0 control character (except TAB)
/// https://infra.spec.whatwg.org/#c0-control
fn isC0Control(c: u8) bool {
    // C0 control is 0x00-0x1F, but we allow TAB (0x09)
    return c <= 0x1F and c != 0x09;
}

/// Check if a character is forbidden in cookie names
/// Forbidden: ; = C0 controls (except TAB), DEL
fn isForbiddenInName(c: u8) bool {
    return c == ';' or c == '=' or isC0Control(c) or c == 0x7F;
}

/// Check if a character is forbidden in cookie values
/// Forbidden: ; C0 controls (except TAB), DEL
fn isForbiddenInValue(c: u8) bool {
    return c == ';' or isC0Control(c) or c == 0x7F;
}

/// Validate a cookie name per RFC 6265bis
/// https://cookiestore.spec.whatwg.org/#set-a-cookie step 3-4
pub fn validateName(name: []const u8) ValidationError!void {
    // Check for forbidden characters
    for (name) |c| {
        if (isForbiddenInName(c)) {
            return ValidationError.InvalidNameCharacter;
        }
    }
}

/// Validate a cookie value per RFC 6265bis
/// https://cookiestore.spec.whatwg.org/#set-a-cookie step 3
pub fn validateValue(value: []const u8) ValidationError!void {
    // Check for forbidden characters
    for (value) |c| {
        if (isForbiddenInValue(c)) {
            return ValidationError.InvalidValueCharacter;
        }
    }
}

/// Validate name and value together per spec
/// https://cookiestore.spec.whatwg.org/#set-a-cookie steps 3-6
pub fn validateNameValue(name: []const u8, value: []const u8) ValidationError!void {
    // Step 3: Check for forbidden characters in both
    try validateName(name);
    try validateValue(value);

    // Step 4: If name contains =, fail
    // (already covered by validateName checking for =)

    // Step 5: If name is empty, special validation
    if (name.len == 0) {
        // Step 5.1: If value contains =, fail
        for (value) |c| {
            if (c == '=') {
                return ValidationError.EmptyNameInvalid;
            }
        }

        // Step 5.2: If value is empty, fail
        if (value.len == 0) {
            return ValidationError.EmptyNameInvalid;
        }

        // Step 5.3: Check reserved prefixes in value
        try validatePrefixInValue(value);
    }

    // Step 6: Check reserved prefixes in name
    try validateReservedPrefix(name);

    // Size limit check
    try validateSize(name, value);
}

/// Validate that combined size doesn't exceed limit
pub fn validateSize(name: []const u8, value: []const u8) ValidationError!void {
    if (name.len + value.len > MAX_NAME_VALUE_SIZE) {
        return ValidationError.NameValueTooLarge;
    }
}

/// Validate that an attribute value doesn't exceed limit
pub fn validateAttributeSize(value: []const u8) ValidationError!void {
    if (value.len > MAX_ATTRIBUTE_VALUE_SIZE) {
        return ValidationError.AttributeTooLarge;
    }
}

/// Check for reserved prefixes that are always rejected
/// https://cookiestore.spec.whatwg.org/#set-a-cookie step 6
pub fn validateReservedPrefix(name: []const u8) ValidationError!void {
    var lower_buf: [32]u8 = undefined;
    const name_lower = toLowerPrefix(name, &lower_buf);

    // __host-http- and __http- are reserved
    if (std.mem.startsWith(u8, name_lower, "__host-http-") or
        std.mem.startsWith(u8, name_lower, "__http-"))
    {
        return ValidationError.ReservedPrefix;
    }
}

/// Check reserved prefixes when name is empty (value becomes the name)
/// https://cookiestore.spec.whatwg.org/#set-a-cookie step 5.3
fn validatePrefixInValue(value: []const u8) ValidationError!void {
    var lower_buf: [32]u8 = undefined;
    const value_lower = toLowerPrefix(value, &lower_buf);

    if (std.mem.startsWith(u8, value_lower, "__host-") or
        std.mem.startsWith(u8, value_lower, "__host-http-") or
        std.mem.startsWith(u8, value_lower, "__http-") or
        std.mem.startsWith(u8, value_lower, "__secure-"))
    {
        return ValidationError.ReservedPrefix;
    }
}

/// Validate __Host- prefix requirements
/// https://cookiestore.spec.whatwg.org/#set-a-cookie step 11
/// __Host- cookies must have: Secure=true, Path="/", Domain=null
pub fn validateHostPrefix(
    name: []const u8,
    secure: bool,
    path: []const u8,
    domain: ?[]const u8,
) ValidationError!void {
    var lower_buf: [32]u8 = undefined;
    const name_lower = toLowerPrefix(name, &lower_buf);

    if (std.mem.startsWith(u8, name_lower, "__host-")) {
        // Must be secure
        if (!secure) {
            return ValidationError.HostPrefixInvalid;
        }
        // Path must be "/"
        if (!std.mem.eql(u8, path, "/")) {
            return ValidationError.HostPrefixInvalid;
        }
        // Domain must not be set
        if (domain != null) {
            return ValidationError.HostPrefixInvalid;
        }
    }
}

/// Validate __Secure- prefix requirements
/// https://cookiestore.spec.whatwg.org/#set-a-cookie (implied by Secure-only access)
/// __Secure- cookies must have: Secure=true
pub fn validateSecurePrefix(name: []const u8, secure: bool) ValidationError!void {
    var lower_buf: [32]u8 = undefined;
    const name_lower = toLowerPrefix(name, &lower_buf);

    if (std.mem.startsWith(u8, name_lower, "__secure-")) {
        if (!secure) {
            return ValidationError.SecurePrefixInvalid;
        }
    }
}

/// Validate all prefix requirements for a cookie
pub fn validatePrefixes(
    name: []const u8,
    secure: bool,
    path: []const u8,
    domain: ?[]const u8,
) ValidationError!void {
    try validateReservedPrefix(name);
    try validateHostPrefix(name, secure, path, domain);
    try validateSecurePrefix(name, secure);
}

/// Validate domain attribute
/// https://cookiestore.spec.whatwg.org/#set-a-cookie step 11
pub fn validateDomain(domain: []const u8) ValidationError!void {
    // Domain must not start with dot
    if (domain.len > 0 and domain[0] == '.') {
        return ValidationError.DomainStartsWithDot;
    }

    // Check attribute size
    try validateAttributeSize(domain);
}

/// Validate path attribute
/// https://cookiestore.spec.whatwg.org/#set-a-cookie step 14-15
pub fn validatePath(path: []const u8) ValidationError!void {
    // Path must start with /
    if (path.len == 0 or path[0] != '/') {
        return ValidationError.PathNotAbsolute;
    }

    // Check attribute size
    try validateAttributeSize(path);
}

/// Helper to lowercase a prefix for comparison (up to buffer size)
fn toLowerPrefix(s: []const u8, buf: []u8) []const u8 {
    const len = @min(s.len, buf.len);
    for (0..len) |i| {
        buf[i] = std.ascii.toLower(s[i]);
    }
    return buf[0..len];
}

/// Check if a name has the __Host- prefix (case-insensitive)
pub fn hasHostPrefix(name: []const u8) bool {
    if (name.len < 7) return false;
    var lower_buf: [7]u8 = undefined;
    const prefix = toLowerPrefix(name[0..7], &lower_buf);
    return std.mem.eql(u8, prefix, "__host-");
}

/// Check if a name has the __Secure- prefix (case-insensitive)
pub fn hasSecurePrefix(name: []const u8) bool {
    if (name.len < 9) return false;
    var lower_buf: [9]u8 = undefined;
    const prefix = toLowerPrefix(name[0..9], &lower_buf);
    return std.mem.eql(u8, prefix, "__secure-");
}

// ============================================================================
// Tests
// ============================================================================

test "validateName - valid names" {
    try validateName("session_id");
    try validateName("token");
    try validateName("123");
    try validateName("a-b_c.d");
    try validateName(""); // empty name is valid (checked elsewhere)
}

test "validateName - invalid characters" {
    try std.testing.expectError(ValidationError.InvalidNameCharacter, validateName("a;b"));
    try std.testing.expectError(ValidationError.InvalidNameCharacter, validateName("a=b"));
    try std.testing.expectError(ValidationError.InvalidNameCharacter, validateName("a\x00b"));
    try std.testing.expectError(ValidationError.InvalidNameCharacter, validateName("a\x1Fb"));
    try std.testing.expectError(ValidationError.InvalidNameCharacter, validateName("a\x7Fb")); // DEL
}

test "validateName - tab is allowed" {
    try validateName("a\tb"); // TAB (0x09) is allowed
}

test "validateValue - valid values" {
    try validateValue("abc123");
    try validateValue("hello world");
    try validateValue("with=equals");
    try validateValue("");
}

test "validateValue - invalid characters" {
    try std.testing.expectError(ValidationError.InvalidValueCharacter, validateValue("a;b"));
    try std.testing.expectError(ValidationError.InvalidValueCharacter, validateValue("a\x00b"));
    try std.testing.expectError(ValidationError.InvalidValueCharacter, validateValue("a\x7Fb"));
}

test "validateNameValue - size limit" {
    const big_name = "x" ** 2500;
    const big_value = "y" ** 2500;
    try std.testing.expectError(ValidationError.NameValueTooLarge, validateNameValue(big_name, big_value));

    // Just under limit should work
    const ok_name = "x" ** 2000;
    const ok_value = "y" ** 2000;
    try validateNameValue(ok_name, ok_value);
}

test "validateNameValue - empty name rules" {
    // Empty name with empty value fails
    try std.testing.expectError(ValidationError.EmptyNameInvalid, validateNameValue("", ""));

    // Empty name with value containing = fails
    try std.testing.expectError(ValidationError.EmptyNameInvalid, validateNameValue("", "a=b"));

    // Empty name with valid value works
    try validateNameValue("", "validvalue");
}

test "validateReservedPrefix" {
    try std.testing.expectError(ValidationError.ReservedPrefix, validateReservedPrefix("__http-test"));
    try std.testing.expectError(ValidationError.ReservedPrefix, validateReservedPrefix("__HTTP-test"));
    try std.testing.expectError(ValidationError.ReservedPrefix, validateReservedPrefix("__host-http-test"));

    // These are NOT reserved (they have specific rules, not rejected outright)
    try validateReservedPrefix("__Host-test");
    try validateReservedPrefix("__Secure-test");
    try validateReservedPrefix("normal");
}

test "validateHostPrefix" {
    // Valid __Host- cookie
    try validateHostPrefix("__Host-token", true, "/", null);

    // Invalid: not secure
    try std.testing.expectError(
        ValidationError.HostPrefixInvalid,
        validateHostPrefix("__Host-token", false, "/", null),
    );

    // Invalid: path not /
    try std.testing.expectError(
        ValidationError.HostPrefixInvalid,
        validateHostPrefix("__Host-token", true, "/app", null),
    );

    // Invalid: domain is set
    try std.testing.expectError(
        ValidationError.HostPrefixInvalid,
        validateHostPrefix("__Host-token", true, "/", "example.com"),
    );

    // Non __Host- prefix doesn't apply rules
    try validateHostPrefix("session", false, "/app", "example.com");
}

test "validateSecurePrefix" {
    // Valid __Secure- cookie
    try validateSecurePrefix("__Secure-token", true);

    // Invalid: not secure
    try std.testing.expectError(
        ValidationError.SecurePrefixInvalid,
        validateSecurePrefix("__Secure-token", false),
    );

    // Non __Secure- prefix doesn't apply rules
    try validateSecurePrefix("session", false);
}

test "validateDomain" {
    try validateDomain("example.com");
    try validateDomain("sub.example.com");

    // Leading dot is invalid
    try std.testing.expectError(ValidationError.DomainStartsWithDot, validateDomain(".example.com"));
}

test "validatePath" {
    try validatePath("/");
    try validatePath("/app");
    try validatePath("/app/sub");

    // Must start with /
    try std.testing.expectError(ValidationError.PathNotAbsolute, validatePath(""));
    try std.testing.expectError(ValidationError.PathNotAbsolute, validatePath("app"));
}

test "hasHostPrefix and hasSecurePrefix" {
    try std.testing.expect(hasHostPrefix("__Host-token"));
    try std.testing.expect(hasHostPrefix("__HOST-TOKEN"));
    try std.testing.expect(!hasHostPrefix("__Secure-token"));
    try std.testing.expect(!hasHostPrefix("normal"));

    try std.testing.expect(hasSecurePrefix("__Secure-token"));
    try std.testing.expect(hasSecurePrefix("__SECURE-TOKEN"));
    try std.testing.expect(!hasSecurePrefix("__Host-token"));
    try std.testing.expect(!hasSecurePrefix("normal"));
}
