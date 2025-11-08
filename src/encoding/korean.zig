//! Korean Encodings Module
//!
//! WHATWG Encoding Standard - §13 Legacy multi-byte Korean encodings
//! https://encoding.spec.whatwg.org/#legacy-multi-byte-korean-encodings
//!
//! This module provides EUC-KR encoding.

pub const euc_kr = @import("korean/euc_kr.zig");
pub const euc_kr_streaming = @import("korean/euc_kr_streaming.zig");
