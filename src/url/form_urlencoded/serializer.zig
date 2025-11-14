//! application/x-www-form-urlencoded Serializer
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#urlencoded-serializing
//! Spec Reference: Lines 1706-1724
//!
//! Serializes a list of name-value tuples into application/x-www-form-urlencoded format.

const std = @import("std");
const infra = @import("infra");
const Tuple = @import("form_parser").Tuple;
const percentEncodeAfterEncoding = @import("percent_encoding").percentEncodeAfterEncoding;
const EncodeSet = @import("encode_sets").EncodeSet;

/// application/x-www-form-urlencoded serializing (spec lines 1706-1724)
///
/// Takes a list of name-value tuples and returns an ASCII string.
///
/// Steps:
/// 1. Get output encoding (UTF-8)
/// 2. Create empty output string
/// 3. For each tuple:
///    - Percent-encode name with form_urlencoded encode set and space_as_plus=true
///    - Percent-encode value with form_urlencoded encode set and space_as_plus=true
///    - Append "&" if output not empty
///    - Append "name=value"
/// 4. Return output
///
/// Example:
/// ```
/// [("key", "value")] → "key=value"
/// [("a", "b c")] → "a=b+c"  // space becomes +
/// ```
pub fn serialize(allocator: std.mem.Allocator, tuples: []const Tuple) ![]u8 {
    // Step 2: Empty output
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    // Step 3: For each tuple
    for (tuples) |tuple| {
        // Step 3.1: Assert name and value are scalar value strings (strings in Zig are UTF-8)
        // (no assertion needed in Zig)

        // Step 3.2-3.3: Percent-encode name and value
        const name = try percentEncodeWithPlus(allocator, tuple.name);
        defer allocator.free(name);

        const value = try percentEncodeWithPlus(allocator, tuple.value);
        defer allocator.free(value);

        // Step 3.4: Append "&" if output not empty
        if (output.len > 0) {
            try output.append('&');
        }

        // Step 3.5: Append name=value
        try output.appendSlice(name);
        try output.append('=');
        try output.appendSlice(value);
    }

    // Step 4: Return output
    return output.toOwnedSlice();
}

/// Percent-encode string with form_urlencoded encode set and space_as_plus=true
///
/// This is a simplified version that handles the form encoding directly.
/// For now, we'll use a basic implementation that handles common cases.
fn percentEncodeWithPlus(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    for (input) |byte| {
        // Space becomes +
        if (byte == ' ') {
            try output.append('+');
            continue;
        }

        // Check if needs encoding per form_urlencoded encode set
        if (shouldEncodeForForm(byte)) {
            // Percent-encode
            const hex = "0123456789ABCDEF";
            try output.append('%');
            try output.append(hex[byte >> 4]);
            try output.append(hex[byte & 0x0F]);
        } else {
            try output.append(byte);
        }
    }

    return output.toOwnedSlice();
}

/// Check if byte should be percent-encoded for form_urlencoded
///
/// form_urlencoded percent-encode set (spec line 174):
/// - component percent-encode set (line 170)
/// - Plus: !, ', (, ), ~
///
/// For simplicity, we encode everything except:
/// - ASCII alphanumeric
/// - * - . _ (unreserved characters commonly allowed)
fn shouldEncodeForForm(byte: u8) bool {
    return switch (byte) {
        'A'...'Z', 'a'...'z', '0'...'9' => false,
        '*', '-', '.', '_' => false,
        else => true,
    };
}

// ============================================================================
// Tests
// ============================================================================









