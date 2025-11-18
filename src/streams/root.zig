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

    pub const structured_clone = @import("structured_clone");
    pub const view_construction = @import("view_construction");

    pub const algorithms = struct {
        pub const queuing = @import("internal/algorithms/queuing_ops.zig");
    };
};

// WebIDL interface definitions (from src/interfaces/)
// These use the runtime system for VTable dispatch and memory management
const interfaces = @import("interfaces");

// Queuing strategy classes
pub const ByteLengthQueuingStrategy = interfaces.ByteLengthQueuingStrategy;
pub const CountQueuingStrategy = interfaces.CountQueuingStrategy;

// Controller classes
pub const ReadableStreamDefaultController = interfaces.ReadableStreamDefaultController;
pub const WritableStreamDefaultController = interfaces.WritableStreamDefaultController;
pub const TransformStreamDefaultController = interfaces.TransformStreamDefaultController;
pub const ReadableStreamBYOBRequest = interfaces.ReadableStreamBYOBRequest;
pub const ReadableByteStreamController = interfaces.ReadableByteStreamController;

// Stream classes
pub const ReadableStream = interfaces.ReadableStream;
// Note: ReadableStreamGenericReader is a mixin, not a public interface - used internally
pub const ReadableStreamDefaultReader = interfaces.ReadableStreamDefaultReader;
pub const ReadableStreamBYOBReader = interfaces.ReadableStreamBYOBReader;
pub const WritableStream = interfaces.WritableStream;
pub const WritableStreamDefaultWriter = interfaces.WritableStreamDefaultWriter;
pub const TransformStream = interfaces.TransformStream;
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
    std.testing.refAllDecls(internal.structured_clone);
    std.testing.refAllDecls(internal.view_construction);
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
