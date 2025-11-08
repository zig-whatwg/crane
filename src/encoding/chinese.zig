//! Chinese Encodings (gb18030, GBK, Big5)
//!
//! WHATWG Encoding Standard:
//! - §10 Legacy multi-byte Chinese (simplified) encodings (gb18030, GBK)
//! - §11 Legacy multi-byte Chinese (traditional) encodings (Big5)
//! https://encoding.spec.whatwg.org/

const std = @import("std");
const streaming = @import("streaming.zig");
const gb18030_impl = @import("chinese/gb18030.zig");
const gb18030_streaming = @import("chinese/gb18030_streaming.zig");
const big5_impl = @import("chinese/big5.zig");
const big5_streaming = @import("chinese/big5_streaming.zig");

pub const gb18030 = gb18030_impl;
pub const big5 = big5_impl;
pub const decode = gb18030_streaming.decode;
pub const encode = gb18030_streaming.encode;
pub const big5_streaming_decode = big5_streaming.decode;
pub const big5_streaming_encode = big5_streaming.encode;
