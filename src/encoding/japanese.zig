//! Japanese Encodings Module
//!
//! WHATWG Encoding Standard - §12 Legacy multi-byte Japanese encodings
//! https://encoding.spec.whatwg.org/#legacy-multi-byte-japanese-encodings
//!
//! This module provides EUC-JP, ISO-2022-JP, and Shift_JIS encodings.

pub const euc_jp = @import("japanese/euc_jp.zig");
pub const euc_jp_streaming = @import("japanese/euc_jp_streaming.zig");
pub const iso_2022_jp = @import("japanese/iso_2022_jp.zig");
pub const iso_2022_jp_streaming = @import("japanese/iso_2022_jp_streaming.zig");
pub const shift_jis = @import("japanese/shift_jis.zig");
pub const shift_jis_streaming = @import("japanese/shift_jis_streaming.zig");
