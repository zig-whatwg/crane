//! UTF-8 encoding module
//!
//! Exports UTF-8 encoder and decoder implementations

pub const ascii = @import("utf8/ascii.zig");
pub const decoder = @import("utf8/decoder.zig");
pub const encoder = @import("utf8/encoder.zig");

// Re-export main functions
pub const decode = decoder.decode;
pub const encode = encoder.encode;
