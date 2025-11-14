//! WebIDL ByteString Operations
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-ByteString
//!
//! ByteString represents a sequence of bytes (0x00-0xFF) that can be used
//! for binary protocols like HTTP headers. This module provides operations
//! for ByteString manipulation using WHATWG Infra primitives.
//!
//! ## ByteString vs DOMString
//!
//! - **ByteString**: Sequence of bytes (0x00-0xFF), used for binary protocols
//! - **DOMString**: UTF-16 string, used for text
//!
//! ## Conversion
//!
//! - **Isomorphic encoding**: 1:1 byte ↔ code unit mapping (0x00-0xFF range)
//! - **UTF-8 encoding**: Full Unicode support, variable-length encoding
//!
//! ## Available Operations
//!
//! - **Case operations**: `byteStringToLowerCase`, `byteStringToUpperCase`
//! - **Comparison**: `byteStringEqualsIgnoreCase`, `byteStringStartsWith`, `byteStringLessThan`
//! - **Validation**: `isAsciiByteString`
//! - **Encoding**: `byteStringToUTF16`, `utf16ToByteString`

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const strings = @import("strings.zig");

/// ByteString is a sequence of bytes (0x00-0xFF).
/// Spec: https://webidl.spec.whatwg.org/#idl-ByteString
pub const ByteString = []const u8;

// ============================================================================
// Byte Case Operations
// ============================================================================

/// Convert ByteString to lowercase (byte-level).
///
/// Spec: WHATWG Infra Standard §4.4 - Byte-lowercase
///
/// Converts bytes 0x41-0x5A (A-Z) to 0x61-0x7A (a-z).
///
/// Example:
/// ```zig
/// const str: []const u8 = "Hello WORLD";
/// const lower = try byteStringToLowerCase(allocator, str);
/// defer allocator.free(lower);
/// // lower == "hello world"
/// ```
pub fn byteStringToLowerCase(allocator: Allocator, bytes: ByteString) !ByteString {
    return try infra.bytes.byteLowercase(allocator, bytes);
}

/// Convert ByteString to uppercase (byte-level).
///
/// Spec: WHATWG Infra Standard §4.4 - Byte-uppercase
///
/// Converts bytes 0x61-0x7A (a-z) to 0x41-0x5A (A-Z).
///
/// Example:
/// ```zig
/// const str: []const u8 = "Hello world";
/// const upper = try byteStringToUpperCase(allocator, str);
/// defer allocator.free(upper);
/// // upper == "HELLO WORLD"
/// ```
pub fn byteStringToUpperCase(allocator: Allocator, bytes: ByteString) !ByteString {
    return try infra.bytes.byteUppercase(allocator, bytes);
}

/// Check if two ByteStrings match (case-insensitive byte comparison).
///
/// Spec: WHATWG Infra Standard §4.4 - Byte-case-insensitive match
///
/// Example:
/// ```zig
/// const a: []const u8 = "Content-Type";
/// const b: []const u8 = "content-type";
/// try testing.expect(byteStringEqualsIgnoreCase(a, b)); // true
/// ```
pub fn byteStringEqualsIgnoreCase(a: ByteString, b: ByteString) bool {
    return infra.bytes.byteCaseInsensitiveMatch(a, b);
}

// ============================================================================
// Byte Comparison Operations
// ============================================================================

/// Check if potential_prefix is a prefix of input (byte comparison).
///
/// Spec: WHATWG Infra Standard §4.4 - Prefix
///
/// Example:
/// ```zig
/// const str: []const u8 = "Hello World";
/// const prefix: []const u8 = "Hello";
/// try testing.expect(byteStringStartsWith(str, prefix)); // true
/// ```
pub fn byteStringStartsWith(input: ByteString, potential_prefix: ByteString) bool {
    return infra.bytes.isPrefix(potential_prefix, input);
}

/// Check if a is byte less than b (lexicographic comparison).
///
/// Spec: WHATWG Infra Standard §4.4 - Byte less than
///
/// Example:
/// ```zig
/// const a: []const u8 = "apple";
/// const b: []const u8 = "banana";
/// try testing.expect(byteStringLessThan(a, b)); // true
/// ```
pub fn byteStringLessThan(a: ByteString, b: ByteString) bool {
    return infra.bytes.byteLessThan(a, b);
}

// ============================================================================
// Byte Validation Operations
// ============================================================================

/// Check if ByteString contains only ASCII bytes (0x00-0x7F).
///
/// Spec: WHATWG Infra Standard §4.4 - ASCII byte sequence
///
/// Example:
/// ```zig
/// try testing.expect(isAsciiByteString("Hello")); // true
/// try testing.expect(!isAsciiByteString(&.{0x80})); // false
/// ```
pub fn isAsciiByteString(bytes: ByteString) bool {
    return infra.bytes.isAsciiByteSequence(bytes);
}

// ============================================================================
// Byte Encoding Operations
// ============================================================================

/// Decode ByteString as UTF-8 to DOMString.
///
/// Spec: WHATWG Infra Standard §4.4 - UTF-8 decode
///
/// Decodes UTF-8 byte sequence to UTF-16 DOMString.
/// Handles multi-byte sequences correctly.
///
/// Example:
/// ```zig
/// const bytes: []const u8 = "Hello 世界";
/// const dom_string = try byteStringToUTF16(allocator, bytes);
/// defer allocator.free(dom_string);
/// ```
pub fn byteStringToUTF16(allocator: Allocator, bytes: ByteString) !strings.DOMString {
    return try infra.bytes.decodeAsUtf8(allocator, bytes);
}

/// Encode DOMString to ByteString (UTF-8).
///
/// Spec: WHATWG Infra Standard §4.4 - UTF-8 encode
///
/// Encodes UTF-16 DOMString to UTF-8 byte sequence.
/// Handles surrogate pairs correctly.
///
/// Example:
/// ```zig
/// const dom_string = try infra.string.utf8ToUtf16(allocator, "Hello 世界");
/// defer allocator.free(dom_string);
///
/// const bytes = try utf16ToByteString(allocator, dom_string);
/// defer allocator.free(bytes);
/// // bytes == "Hello 世界" (UTF-8 encoded)
/// ```
pub fn utf16ToByteString(allocator: Allocator, string: strings.DOMString) !ByteString {
    return try infra.bytes.utf8Encode(allocator, string);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;












