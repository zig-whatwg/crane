//! UTF-16 Encodings Module
//!
//! WHATWG Encoding Standard - §14.2-14.4 UTF-16BE/LE
//! https://encoding.spec.whatwg.org/#utf-16be-le
//!
//! This module provides UTF-16BE and UTF-16LE encodings.
//! Both are decode-only (no encoders per WHATWG spec).

pub const shared_decoder = @import("utf16/shared_decoder.zig");
pub const utf16be_streaming = @import("utf16/utf16be_streaming.zig");
pub const utf16le_streaming = @import("utf16/utf16le_streaming.zig");
