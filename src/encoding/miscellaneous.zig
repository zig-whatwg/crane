//! Miscellaneous Encodings Module
//!
//! WHATWG Encoding Standard - §14 Legacy miscellaneous encodings
//! https://encoding.spec.whatwg.org/#legacy-miscellaneous-encodings
//!
//! This module provides:
//! - replacement encoding (decode-only, security feature)
//! - x-user-defined encoding

pub const replacement = @import("miscellaneous/replacement.zig");
pub const replacement_streaming = @import("miscellaneous/replacement_streaming.zig");
pub const x_user_defined = @import("miscellaneous/x_user_defined.zig");
pub const x_user_defined_streaming = @import("miscellaneous/x_user_defined_streaming.zig");
