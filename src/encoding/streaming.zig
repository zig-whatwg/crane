//! Streaming API for Encoding/Decoding
//!
//! This module defines result types for both:
//! - Slice-based streaming (original, high-performance)
//! - I/O queue-based streaming (WHATWG spec-compliant)
//!
//! The slice-based API is used by existing decoders/encoders.
//! The I/O queue API is used by new spec-compliant implementations.

const std = @import("std");

/// Result of a decoding operation (slice-based API)
pub const DecodeResult = struct {
    /// Status of the decode operation
    status: Status,

    /// Number of input bytes consumed
    bytes_consumed: usize,

    /// Number of UTF-16 code units written to output
    code_units_written: usize,

    /// For malformed status: number of bad bytes (1-4 for UTF-8)
    error_length: u8 = 0,

    pub const Status = enum {
        /// All input consumed successfully
        input_empty,

        /// Output buffer is full, need more space
        output_full,

        /// Encountered malformed/unmappable sequence
        malformed,
    };
};

/// Result of a decoding operation using I/O queues (spec-compliant)
pub const DecodeQueueResult = struct {
    /// Status of the decode operation
    status: Status,

    /// For malformed status: number of bad bytes (1-4 for UTF-8)
    error_length: u8 = 0,

    pub const Status = enum {
        /// Successfully processed, reached end-of-queue or queue empty
        finished,

        /// Encountered malformed/unmappable sequence
        /// Decoder has emitted replacement character (replacement mode)
        /// or will return error (fatal mode)
        malformed,

        /// Operation returned error (fatal mode only)
        error_,
    };
};

/// Result of an encoding operation (slice-based API)
pub const EncodeResult = struct {
    /// Status of the encode operation
    status: Status,

    /// Number of UTF-16 code units consumed from input
    code_units_consumed: usize,

    /// Number of bytes written to output
    bytes_written: usize,

    /// For unmappable status: the code point that couldn't be encoded
    error_code_point: u21 = 0,

    pub const Status = enum {
        /// All input consumed successfully
        input_empty,

        /// Output buffer is full, need more space
        output_full,

        /// Encountered unmappable code point
        unmappable,
    };
};

/// Result of an encoding operation using I/O queues (spec-compliant)
pub const EncodeQueueResult = struct {
    /// Status of the encode operation
    status: Status,

    /// For unmappable status: the code point that couldn't be encoded
    error_code_point: u21 = 0,

    pub const Status = enum {
        /// Successfully processed, reached end-of-queue or queue empty
        finished,

        /// Encountered unmappable code point
        /// Encoder has emitted replacement character (replacement mode)
        /// or HTML entity (html mode) or will return error (fatal mode)
        unmappable,

        /// Operation returned error (fatal mode only)
        error_,
    };
};
