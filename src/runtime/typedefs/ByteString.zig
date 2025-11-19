//! ByteString - Sequence of bytes (0-255)
//!
//! WebIDL ByteString is a sequence of bytes where each byte is 0-255.
//! This is used for binary data and ASCII strings.

/// ByteString is a byte slice
pub const ByteString = []const u8;
