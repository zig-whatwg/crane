//! WHATWG Encoding Standard Implementation for Zig

const std = @import("std");

// Core modules
pub const encoding = @import("encoding.zig");
pub const streaming = @import("streaming.zig");
pub const error_mode = @import("error_mode.zig");
pub const bom = @import("bom.zig");
pub const hooks = @import("hooks.zig");
pub const api = @import("api.zig");
pub const comptime_encoding = @import("comptime.zig");
pub const inline_string = @import("inline_string.zig");
pub const buffer_pool = @import("buffer_pool.zig");

// I/O Queue support (WHATWG Infra-based)
pub const io_queue = @import("io_queue.zig");
pub const processing = @import("processing.zig");
pub const serialize_io_queue = @import("serialize_io_queue.zig");
pub const html_encoding = @import("html_encoding.zig");
pub const wrappers = @import("wrappers.zig");

// Queue-based implementations
pub const utf8_decoder_queue = @import("utf8/decoder_queue.zig");
pub const utf8_encoder_queue = @import("utf8/encoder_queue.zig");
pub const single_byte_decoder_queue = @import("single_byte/decoder_queue.zig");
pub const single_byte_encoder_queue = @import("single_byte/encoder_queue.zig");

// Re-export commonly used types
pub const Encoding = encoding.Encoding;
pub const Decoder = encoding.Decoder;
pub const Encoder = encoding.Encoder;
pub const DecodeResult = streaming.DecodeResult;
pub const EncodeResult = streaming.EncodeResult;
pub const DecodeQueueResult = streaming.DecodeQueueResult;
pub const EncodeQueueResult = streaming.EncodeQueueResult;
pub const ErrorMode = error_mode.ErrorMode;
pub const BomEncoding = bom.BomEncoding;

// Re-export I/O queue types
pub const ByteQueue = io_queue.ByteQueue;
pub const ScalarQueue = io_queue.ScalarQueue;

// Re-export static encoding instances
pub const UTF_8 = &encoding.UTF_8;

// Re-export utility functions
pub const getEncoding = encoding.getEncoding;
pub const getOutputEncoding = encoding.getOutputEncoding;

// Re-export WHATWG hooks
pub const utf8Decode = hooks.utf8Decode;
pub const utf8DecodeWithoutBom = hooks.utf8DecodeWithoutBom;
pub const utf8DecodeWithoutBomOrFail = hooks.utf8DecodeWithoutBomOrFail;
pub const utf8Encode = hooks.utf8Encode;

// Re-export high-level API
pub const decodeUtf8 = api.decodeUtf8;
pub const decodeUtf8ToBuffer = api.decodeUtf8ToBuffer;
pub const encodeUtf8 = api.encodeUtf8;
pub const encodeUtf8ToBuffer = api.encodeUtf8ToBuffer;

// Re-export arena allocator helpers (for batch operations)
pub const decodeUtf8Arena = api.decodeUtf8Arena;
pub const encodeUtf8Arena = api.encodeUtf8Arena;
pub const decodeUtf8Batch = api.decodeUtf8Batch;
pub const encodeUtf8Batch = api.encodeUtf8Batch;

// Re-export comptime encoding (zero runtime cost)
pub const decodeUtf8Comptime = comptime_encoding.decodeUtf8Comptime;

// Re-export inline string optimization (10-100x speedup for small strings)
pub const InlineDecodeResult = inline_string.InlineDecodeResult;
pub const InlineEncodeResult = inline_string.InlineEncodeResult;

// Re-export buffer pooling (3-5x speedup for repeated operations)
pub const DecodeBufferPool = buffer_pool.DecodeBufferPool;
pub const EncodeBufferPool = buffer_pool.EncodeBufferPool;

// Re-export optimization modules (new in 2025-10-29)
pub const fast_decoder = @import("fast_decoder.zig");
pub const decode_result = @import("decode_result.zig");

// Re-export optimization types
pub const FastDecoder = fast_decoder.FastDecoder;
pub const FastEncoding = fast_decoder.FastEncoding;
pub const ZeroCopyDecodeResult = decode_result.DecodeResult;

test {
    std.testing.refAllDecls(@This());
}

// WebIDL API exports (§7) - from interfaces/
// TODO: Re-implement TextEncoder and TextDecoder using the runtime system
// These were previously in webidl/generated/ but have been removed during cleanup
// const text_encoder_mod = @import("text_encoder");
// pub const TextEncoder = text_encoder_mod.TextEncoder;
// pub const TextEncoderEncodeIntoResult = text_encoder_mod.TextEncoderEncodeIntoResult;
//
// const text_decoder_mod = @import("text_decoder");
// pub const TextDecoder = text_decoder_mod.TextDecoder;
// pub const TextDecoderOptions = text_decoder_mod.TextDecoderOptions;
// pub const TextDecodeOptions = text_decoder_mod.TextDecodeOptions;

// Test generated interfaces with mixin composition
