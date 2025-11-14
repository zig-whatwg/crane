//! Windows Drive Letter Detection
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#windows-drive-letter
//! Spec Reference: Lines 870-887
//!
//! Windows drive letters are special two-character sequences used in file URLs
//! on Windows systems. They consist of an ASCII alpha character followed by either
//! U+003A (:) or U+007C (|).
//!
//! ## Examples
//!
//! - `c:` - Windows drive letter
//! - `C:` - Windows drive letter (uppercase)
//! - `c|` - Windows drive letter (legacy pipe syntax)
//! - `c:/path` - Starts with Windows drive letter
//! - `c:x` - Does NOT start with Windows drive letter
//!
//! ## Decision 11
//!
//! Support both ':' and '|' as second character for backward compatibility.
//!
//! ## Usage
//!
//! ```zig
//! const windows_drive = @import("internal/windows_drive.zig");
//!
//! if (windows_drive.isWindowsDriveLetter("c:")) {
//!     // Handle drive letter
//! }
//!
//! if (windows_drive.startsWithWindowsDriveLetter("c:/path")) {
//!     // Handle path starting with drive letter
//! }
//! ```

const std = @import("std");
const infra = @import("infra");

/// Check if a string is a Windows drive letter (spec line 870)
///
/// A Windows drive letter is two code points:
/// 1. First: ASCII alpha (A-Z, a-z)
/// 2. Second: U+003A (:) or U+007C (|)
///
/// Decision 11: Support both ':' and '|' (backward compatibility)
pub fn isWindowsDriveLetter(s: []const u8) bool {
    if (s.len != 2) return false;

    const first = s[0];
    const second = s[1];

    // First character must be ASCII alpha
    if (!infra.code_point.isAsciiAlpha(first)) return false;

    // Second character must be ':' or '|'
    return second == ':' or second == '|';
}

/// Check if a string is a normalized Windows drive letter (spec line 872)
///
/// A normalized Windows drive letter uses U+003A (:) as the second character,
/// not U+007C (|).
///
/// Only normalized Windows drive letters are conforming (spec line 874).
pub fn isNormalizedWindowsDriveLetter(s: []const u8) bool {
    if (s.len != 2) return false;

    const first = s[0];
    const second = s[1];

    // First must be ASCII alpha, second must be ':' (not '|')
    return infra.code_point.isAsciiAlpha(first) and second == ':';
}

/// Check if a string starts with a Windows drive letter (spec lines 876-880)
///
/// A string starts with a Windows drive letter if ALL of the following are true:
/// 1. Length >= 2
/// 2. First two code points are a Windows drive letter
/// 3. Length == 2 OR third code point is '/', '\', '?', or '#'
///
/// Examples:
/// - `c:` ✅ (length == 2)
/// - `c:/` ✅ (third is '/')
/// - `c:\` ✅ (third is '\')
/// - `c:?` ✅ (third is '?')
/// - `c:#` ✅ (third is '#')
/// - `c:a` ❌ (third is 'a', not separator)
pub fn startsWithWindowsDriveLetter(s: []const u8) bool {
    // 1. Length >= 2
    if (s.len < 2) return false;

    // 2. First two code points are a Windows drive letter
    if (!isWindowsDriveLetter(s[0..2])) return false;

    // 3. Length == 2 OR third code point is '/', '\', '?', or '#'
    if (s.len == 2) return true;

    const third = s[2];
    return third == '/' or third == '\\' or third == '?' or third == '#';
}




