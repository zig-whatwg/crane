//! USVString - Unicode Scalar Value string
//!
//! WebIDL USVString represents a sequence of Unicode scalar values.
//! In practice, this is a UTF-8 encoded string slice.
//!
//! USVString differs from DOMString in that it guarantees valid Unicode
//! (no unpaired surrogates), but for Zig we can use the same representation
//! since Zig strings are UTF-8 by convention.

/// USVString is a UTF-8 encoded string slice
pub const USVString = []const u8;
