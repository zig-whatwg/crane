//! WebIDL Dictionary Types for WHATWG Streams
//!
//! This module defines Zig struct types corresponding to WebIDL dictionaries
//! used in the Streams Standard. These types are used to parse JavaScript
//! objects passed to stream constructors and methods.
//!
//! Spec: https://streams.spec.whatwg.org/
//! IDL: specs/streams.idl

const std = @import("std");
const webidl = @import("webidl");
const common = @import("common");
const dom = @import("dom");

// ============================================================================
// UnderlyingSource Dictionary (specs/streams.idl lines 47-53)
// ============================================================================

/// UnderlyingSource dictionary
///
/// IDL:
/// ```webidl
/// dictionary UnderlyingSource {
///   UnderlyingSourceStartCallback start;
///   UnderlyingSourcePullCallback pull;
///   UnderlyingSourceCancelCallback cancel;
///   ReadableStreamType type;
///   [EnforceRange] unsigned long long autoAllocateChunkSize;
/// };
/// ```
pub const UnderlyingSource = struct {
    /// Start callback - called immediately during construction
    start: ?webidl.GenericCallback = null,

    /// Pull callback - called when stream needs more data
    pull: ?webidl.GenericCallback = null,

    /// Cancel callback - called when stream is canceled
    cancel: ?webidl.GenericCallback = null,

    /// Stream type - "bytes" for byte streams, undefined for default streams
    type: ?ReadableStreamType = null,

    /// Auto-allocate chunk size for BYOB readers (only valid if type="bytes")
    auto_allocate_chunk_size: ?u64 = null,
};

/// ReadableStreamType enumeration
///
/// IDL: enum ReadableStreamType { "bytes" };
pub const ReadableStreamType = enum {
    bytes,
};

// ============================================================================
// UnderlyingSink Dictionary (specs/streams.idl lines 134-140)
// ============================================================================

/// UnderlyingSink dictionary
///
/// IDL:
/// ```webidl
/// dictionary UnderlyingSink {
///   UnderlyingSinkStartCallback start;
///   UnderlyingSinkWriteCallback write;
///   UnderlyingSinkCloseCallback close;
///   UnderlyingSinkAbortCallback abort;
///   any type;
/// };
/// ```
pub const UnderlyingSink = struct {
    /// Start callback - called immediately during construction
    start: ?webidl.GenericCallback = null,

    /// Write callback - called for each chunk
    write: ?webidl.GenericCallback = null,

    /// Close callback - called when stream is closing
    close: ?webidl.GenericCallback = null,

    /// Abort callback - called when stream is aborted
    abort: ?webidl.GenericCallback = null,

    /// Stream type - reserved for future use, must be undefined
    type: ?common.JSValue = null,
};

// ============================================================================
// Transformer Dictionary (specs/streams.idl lines 177-184)
// ============================================================================

/// Transformer dictionary
///
/// IDL:
/// ```webidl
/// dictionary Transformer {
///   TransformerStartCallback start;
///   TransformerTransformCallback transform;
///   TransformerFlushCallback flush;
///   TransformerCancelCallback cancel;
///   any readableType;
///   any writableType;
/// };
/// ```
pub const Transformer = struct {
    /// Start callback - called immediately during construction
    start: ?webidl.GenericCallback = null,

    /// Transform callback - called for each chunk
    transform: ?webidl.GenericCallback = null,

    /// Flush callback - called when writable side is closing
    flush: ?webidl.GenericCallback = null,

    /// Cancel callback - called when readable side is canceled
    cancel: ?webidl.GenericCallback = null,

    /// Readable type - reserved for future use, must be undefined
    readable_type: ?common.JSValue = null,

    /// Writable type - reserved for future use, must be undefined
    writable_type: ?common.JSValue = null,
};

// ============================================================================
// QueuingStrategy Dictionary (specs/streams.idl lines 200-203)
// ============================================================================

/// QueuingStrategy dictionary
///
/// IDL:
/// ```webidl
/// dictionary QueuingStrategy {
///   unrestricted double highWaterMark;
///   QueuingStrategySize size;
/// };
/// ```
pub const QueuingStrategy = struct {
    /// High water mark - threshold for backpressure
    high_water_mark: ?f64 = null,

    /// Size function - calculates chunk size
    size: ?webidl.GenericCallback = null,
};

// ============================================================================
// StreamPipeOptions Dictionary (specs/streams.idl lines 40-45)
// ============================================================================

/// StreamPipeOptions dictionary
///
/// IDL:
/// ```webidl
/// dictionary StreamPipeOptions {
///   boolean preventClose = false;
///   boolean preventAbort = false;
///   boolean preventCancel = false;
///   AbortSignal signal;
/// };
/// ```
pub const StreamPipeOptions = struct {
    /// Prevent closing the destination when source closes
    prevent_close: bool = false,

    /// Prevent aborting the destination on error
    prevent_abort: bool = false,

    /// Prevent canceling the source on error
    prevent_cancel: bool = false,

    /// Abort signal to abort the pipe operation
    signal: ?*dom.AbortSignal = null,
};

// ============================================================================
// ReadableWritablePair Dictionary (specs/streams.idl lines 35-38)
// ============================================================================

/// ReadableWritablePair dictionary
///
/// IDL:
/// ```webidl
/// dictionary ReadableWritablePair {
///   required ReadableStream readable;
///   required WritableStream writable;
/// };
/// ```
pub const ReadableWritablePair = struct {
    /// The readable side of the pair
    readable: *anyopaque, // *ReadableStream (avoid circular dependency)

    /// The writable side of the pair
    writable: *anyopaque, // *WritableStream (avoid circular dependency)
};

// ============================================================================
// ReadableStreamGetReaderOptions Dictionary (specs/streams.idl lines 27-29)
// ============================================================================

/// ReadableStreamGetReaderOptions dictionary
///
/// IDL:
/// ```webidl
/// dictionary ReadableStreamGetReaderOptions {
///   ReadableStreamReaderMode mode;
/// };
/// ```
pub const ReadableStreamGetReaderOptions = struct {
    /// Reader mode - "byob" for BYOB reader, undefined for default reader
    mode: ?ReaderMode = null,
};

/// ReadableStreamReaderMode enumeration
///
/// IDL: enum ReadableStreamReaderMode { "byob" };
pub const ReaderMode = enum {
    byob,
};

// ============================================================================
// ReadableStreamIteratorOptions Dictionary (specs/streams.idl lines 31-33)
// ============================================================================

/// ReadableStreamIteratorOptions dictionary
///
/// IDL:
/// ```webidl
/// dictionary ReadableStreamIteratorOptions {
///   boolean preventCancel = false;
/// };
/// ```
pub const ReadableStreamIteratorOptions = struct {
    /// Prevent canceling the stream when iterator is done
    prevent_cancel: bool = false,
};

// ============================================================================
// ReadableStreamBYOBReaderReadOptions Dictionary (specs/streams.idl lines 92-94)
// ============================================================================

/// ReadableStreamBYOBReaderReadOptions dictionary
///
/// IDL:
/// ```webidl
/// dictionary ReadableStreamBYOBReaderReadOptions {
///   [EnforceRange] unsigned long long min = 1;
/// };
/// ```
pub const ReadableStreamBYOBReaderReadOptions = struct {
    /// Minimum number of bytes to read
    min: u64 = 1,
};

// ============================================================================
// QueuingStrategyInit Dictionary (specs/streams.idl lines 207-209)
// ============================================================================

/// QueuingStrategyInit dictionary
///
/// IDL:
/// ```webidl
/// dictionary QueuingStrategyInit {
///   required unrestricted double highWaterMark;
/// };
/// ```
pub const QueuingStrategyInit = struct {
    /// High water mark - required field
    high_water_mark: f64,
};
