//! WHATWG Streams Standard implementation in Zig
//!
//! This library implements the WHATWG Streams Standard, providing streaming
//! data primitives for incremental data processing.
//!
//! Spec: https://streams.spec.whatwg.org/
//!
//! Current Status: Phases 1-6 & 8 Complete, Phase 5 & 7 In Progress
//!
//! Phase 1 - Foundational Types (Complete):
//! - Queue-with-sizes (§8.1) ✅
//! - Internal record types (ReadRequest, ReadIntoRequest, PullIntoDescriptor, WriteRequest) ✅
//! - Queuing strategy operations (ExtractHighWaterMark, ExtractSizeAlgorithm, etc.) ✅
//! - ByteLengthQueuingStrategy class ✅
//! - CountQueuingStrategy class ✅
//!
//! Phase 2 - Controllers (Complete):
//! - ReadableStreamDefaultController ✅
//! - WritableStreamDefaultController ✅
//! - TransformStreamDefaultController ✅
//! - ReadableStreamBYOBRequest ✅
//! - Note: ReadableByteStreamController deferred to Phase 7 (BYOB Streams)
//!
//! Phase 3 - ReadableStream + DefaultReader (Complete):
//! - ReadableStreamDefaultReader (with GenericReader mixin) ✅
//! - ReadableStream class (constructor, basic operations) ✅
//!
//! Phase 4 - WritableStream + Writer (Complete):
//! - WritableStreamDefaultWriter ✅
//! - WritableStream class (constructor, write/close/abort operations) ✅
//!
//! Phase 5 - TransformStream (In Progress):
//! - TransformStream class (constructor, transform operations) 🚧
//!
//! Phase 6 - Piping Operations (Complete):
//! - pipeTo() with error/close propagation ✅
//! - pipeThrough() for stream composition ✅
//! - PipeState coordinator with backpressure handling ✅
//!
//! Phase 7 - BYOB (Bring Your Own Buffer) Streams (In Progress):
//! - ReadableByteStreamController 🚧
//! - ReadableStreamBYOBReader 🚧
//! - Byte stream integration 🚧
//!
//! Phase 8 - Async Iteration (Complete):
//! - ReadableStream.values() ✅
//! - ReadableStream[@@asyncIterator]() ✅
//! - ReadableStreamAsyncIterator protocol ✅
//!
//! Phase 9 - Transfer/Serialization (Not Implemented):
//! - Transfer steps ❌
//! - Transfer-receiving steps ❌
//! - Requires: HTML Standard's MessagePort infrastructure

const std = @import("std");

// Internal modules - imported via module system to avoid file ownership conflicts
pub const internal = struct {
    pub const common = @import("common");

    pub const QueueWithSizes = @import("queue_with_sizes").QueueWithSizes;
    pub const ValueWithSize = @import("queue_with_sizes").ValueWithSize;
    pub const Value = @import("queue_with_sizes").Value;

    pub const ReadRequest = @import("read_request").ReadRequest;
    pub const ReadIntoRequest = @import("read_into_request").ReadIntoRequest;
    pub const PullIntoDescriptor = @import("pull_into_descriptor").PullIntoDescriptor;
    pub const WriteRequest = @import("write_request").WriteRequest;

    pub const AbortSignal = @import("internal/abort_signal.zig").AbortSignal;
    pub const AbortController = @import("internal/abort_signal.zig").AbortController;

    pub const algorithms = struct {
        pub const queuing = @import("internal/algorithms/queuing_ops.zig");
    };
};

// Queuing strategy classes (from interfaces/)
pub const ByteLengthQueuingStrategy = @import("byte_length_queuing_strategy").ByteLengthQueuingStrategy;
pub const CountQueuingStrategy = @import("count_queuing_strategy").CountQueuingStrategy;

// Controller classes (from interfaces/)
pub const ReadableStreamDefaultController = @import("readable_stream_default_controller").ReadableStreamDefaultController;
pub const WritableStreamDefaultController = @import("writable_stream_default_controller").WritableStreamDefaultController;
pub const TransformStreamDefaultController = @import("transform_stream_default_controller").TransformStreamDefaultController;
pub const ReadableStreamBYOBRequest = @import("readable_stream_byob_request").ReadableStreamBYOBRequest;
pub const ReadableByteStreamController = @import("readable_byte_stream_controller").ReadableByteStreamController;

// Stream classes (from interfaces/)
pub const ReadableStream = @import("readable_stream").ReadableStream;
// Note: ReadableStreamGenericReader is a mixin, not a public interface - used internally
pub const ReadableStreamDefaultReader = @import("readable_stream_default_reader").ReadableStreamDefaultReader;
pub const ReadableStreamBYOBReader = @import("readable_stream_byob_reader").ReadableStreamBYOBReader;
pub const ReadableStreamIterator = @import("readable_stream").ReadableStreamIterator;
pub const WritableStream = @import("writable_stream").WritableStream;
pub const WritableStreamDefaultWriter = @import("writable_stream_default_writer").WritableStreamDefaultWriter;
pub const TransformStream = @import("transform_stream").TransformStream;
// Note: GenericTransformStream is a mixin, not a public interface - used by other specs

// Re-export commonly used types
pub const QueueWithSizes = internal.QueueWithSizes;
pub const Value = internal.Value;
pub const JSValue = internal.common.JSValue;
pub const Promise = internal.common.Promise;

test {
    // Run all tests from imported modules
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(internal.common);
    std.testing.refAllDecls(internal.QueueWithSizes);
    std.testing.refAllDecls(internal.ReadRequest);
    std.testing.refAllDecls(internal.ReadIntoRequest);
    std.testing.refAllDecls(internal.PullIntoDescriptor);
    std.testing.refAllDecls(internal.WriteRequest);
    std.testing.refAllDecls(internal.algorithms.queuing);
    std.testing.refAllDecls(ByteLengthQueuingStrategy);
    std.testing.refAllDecls(CountQueuingStrategy);
    std.testing.refAllDecls(ReadableStreamDefaultController);
    std.testing.refAllDecls(WritableStreamDefaultController);
    std.testing.refAllDecls(TransformStreamDefaultController);
    std.testing.refAllDecls(ReadableStreamBYOBRequest);
    std.testing.refAllDecls(ReadableByteStreamController);
    std.testing.refAllDecls(ReadableStream);
    // Note: ReadableStreamGenericReader is a mixin - tested via interfaces that use it
    std.testing.refAllDecls(ReadableStreamDefaultReader);
    std.testing.refAllDecls(ReadableStreamBYOBReader);
    std.testing.refAllDecls(WritableStream);
    std.testing.refAllDecls(WritableStreamDefaultWriter);
    std.testing.refAllDecls(TransformStream);
    // Note: GenericTransformStream is a mixin - tested via interfaces that use it
}
