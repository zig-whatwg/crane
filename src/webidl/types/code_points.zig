//! WebIDL Code Point Operations
//!
//! This module re-exports Infra code point predicates for WebIDL type validation
//! and string processing.
//!
//! Spec: WHATWG Infra Standard §4.5 - Code points
//!
//! ## Code Point Predicates
//!
//! All predicates are re-exported from the WHATWG Infra library to ensure
//! consistent Unicode handling across Web API implementations.
//!
//! ### Surrogate Predicates
//! - `isSurrogate` - Check if code point is a surrogate (U+D800 to U+DFFF)
//! - `isScalarValue` - Check if code point is a scalar value (not a surrogate)
//! - `isLeadSurrogate` - Check if code point is a lead surrogate (U+D800 to U+DBFF)
//! - `isTrailSurrogate` - Check if code point is a trail surrogate (U+DC00 to U+DFFF)
//!
//! ### ASCII Predicates
//! - `isAsciiCodePoint` - Check if code point is in ASCII range (U+0000 to U+007F)
//! - `isAsciiTabOrNewline` - Check if code point is tab, LF, or CR
//! - `isAsciiWhitespaceCodePoint` - Check if code point is ASCII whitespace
//! - `isAsciiDigit` - Check if code point is ASCII digit (0-9)
//! - `isAsciiHexDigit` - Check if code point is ASCII hex digit (0-9, A-F, a-f)
//! - `isAsciiUpperHexDigit` - Check if code point is uppercase hex digit (0-9, A-F)
//! - `isAsciiLowerHexDigit` - Check if code point is lowercase hex digit (0-9, a-f)
//! - `isAsciiAlpha` - Check if code point is ASCII letter (A-Z, a-z)
//! - `isAsciiUpperAlpha` - Check if code point is uppercase ASCII letter (A-Z)
//! - `isAsciiLowerAlpha` - Check if code point is lowercase ASCII letter (a-z)
//! - `isAsciiAlphanumeric` - Check if code point is ASCII alphanumeric (A-Z, a-z, 0-9)
//!
//! ### Control Character Predicates
//! - `isC0Control` - Check if code point is a C0 control (U+0000 to U+001F)
//! - `isC0ControlOrSpace` - Check if code point is a C0 control or space (U+0020)
//! - `isControl` - Check if code point is a control character
//! - `isNoncharacter` - Check if code point is a noncharacter
//!
//! ### Surrogate Pair Operations
//! - `encodeSurrogatePair` - Encode code point as surrogate pair
//! - `decodeSurrogatePair` - Decode surrogate pair to code point
//! - `SurrogatePair` - Surrogate pair type (lead/trail)
//!
//! ## Example
//!
//! ```zig
//! const code_points = @import("webidl").code_points;
//!
//! const c: u21 = 0x1F600; // 😀
//! if (code_points.isScalarValue(c)) {
//!     // Valid scalar value
//! }
//!
//! if (code_points.isAsciiDigit('5')) {
//!     // Is a digit
//! }
//! ```

const infra = @import("infra");

pub const CodePoint = infra.CodePoint;

pub const isSurrogate = infra.code_point.isSurrogate;
pub const isScalarValue = infra.code_point.isScalarValue;
pub const isNoncharacter = infra.code_point.isNoncharacter;
pub const isLeadSurrogate = infra.code_point.isLeadSurrogate;
pub const isTrailSurrogate = infra.code_point.isTrailSurrogate;

pub const isAsciiCodePoint = infra.code_point.isAsciiCodePoint;
pub const isAsciiTabOrNewline = infra.code_point.isAsciiTabOrNewline;
pub const isAsciiWhitespaceCodePoint = infra.code_point.isAsciiWhitespaceCodePoint;
pub const isC0Control = infra.code_point.isC0Control;
pub const isC0ControlOrSpace = infra.code_point.isC0ControlOrSpace;
pub const isControl = infra.code_point.isControl;

pub const isAsciiDigit = infra.code_point.isAsciiDigit;
pub const isAsciiUpperHexDigit = infra.code_point.isAsciiUpperHexDigit;
pub const isAsciiLowerHexDigit = infra.code_point.isAsciiLowerHexDigit;
pub const isAsciiHexDigit = infra.code_point.isAsciiHexDigit;

pub const isAsciiUpperAlpha = infra.code_point.isAsciiUpperAlpha;
pub const isAsciiLowerAlpha = infra.code_point.isAsciiLowerAlpha;
pub const isAsciiAlpha = infra.code_point.isAsciiAlpha;
pub const isAsciiAlphanumeric = infra.code_point.isAsciiAlphanumeric;

pub const encodeSurrogatePair = infra.code_point.encodeSurrogatePair;
pub const decodeSurrogatePair = infra.code_point.decodeSurrogatePair;
pub const SurrogatePair = infra.code_point.SurrogatePair;
pub const CodePointError = infra.code_point.CodePointError;
