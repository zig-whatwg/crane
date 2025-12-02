//! Structured Clone Algorithm
//!
//! Spec: HTML Standard §2.7 "Safe passing of structured data"
//! https://html.spec.whatwg.org/#safe-passing-of-structured-data
//!
//! ## Overview
//!
//! This module implements the structured clone algorithm which enables:
//! - Deep copying of JavaScript values across realm boundaries
//! - Serialization to realm-independent form for storage or IPC
//! - Transfer of certain objects (ArrayBuffer, MessagePort, streams, etc.)
//!
//! ## Key Concepts
//!
//! ### Serializable Objects
//!
//! Objects that can be serialized and later deserialized:
//! - Primitives (undefined, null, boolean, number, bigint, string)
//! - Boxed primitives (Boolean, Number, BigInt, String objects)
//! - Date, RegExp
//! - ArrayBuffer and TypedArrays
//! - Map, Set
//! - Error objects
//! - Plain objects and arrays
//! - Platform objects with [Serializable] (Blob, File, ImageData, etc.)
//!
//! ### Transferable Objects
//!
//! Objects that can be transferred (moved, not copied):
//! - ArrayBuffer
//! - MessagePort
//! - ReadableStream, WritableStream, TransformStream
//! - ImageBitmap
//! - OffscreenCanvas
//! - AudioData, VideoFrame (WebCodecs)
//!
//! ### Non-Cloneable Types
//!
//! These throw DataCloneError:
//! - Functions
//! - Symbols
//! - DOM nodes
//! - WeakMap, WeakSet
//! - Promises
//!
//! ## Usage
//!
//! ```zig
//! const structured_clone = @import("structured_clone");
//!
//! // Simple clone
//! const original = JSValue{ .string = "hello" };
//! const cloned = try structured_clone.structuredClone(allocator, &original, null);
//! defer structured_clone.freeJSValue(allocator, cloned);
//!
//! // Clone with transfer
//! var buffer = TransferableArrayBuffer{ .data = data, .detached = false };
//! var transfer_list = [_]Transferable{.{ .array_buffer = &buffer }};
//! const cloned = try structured_clone.structuredClone(allocator, &value, &transfer_list);
//! // buffer is now detached
//! ```
//!
//! ## Algorithms
//!
//! - **StructuredSerialize**: Converts value to realm-independent Record
//! - **StructuredSerializeForStorage**: Like StructuredSerialize but for storage
//! - **StructuredDeserialize**: Recreates value from serialized Record
//! - **StructuredSerializeWithTransfer**: Serialize with transfer list
//! - **StructuredDeserializeWithTransfer**: Deserialize with transferred objects
//! - **structuredClone()**: High-level API combining serialize + deserialize

const std = @import("std");

// Re-export submodules
pub const types = @import("types.zig");
pub const serialize = @import("serialize.zig");
pub const deserialize = @import("deserialize.zig");
pub const transfer = @import("transfer.zig");
pub const clone = @import("clone.zig");

// Re-export common types
pub const SerializedValue = types.SerializedValue;
pub const SerializationType = types.SerializationType;
pub const CloneError = types.CloneError;
pub const ErrorName = types.ErrorName;
pub const TypedArrayConstructor = types.TypedArrayConstructor;
pub const PrimitiveValue = types.PrimitiveValue;
pub const TransferDataHolder = types.TransferDataHolder;
pub const SerializeWithTransferResult = types.SerializeWithTransferResult;
pub const DeserializeWithTransferResult = types.DeserializeWithTransferResult;

// Re-export JSValue for use by consumers
pub const JSValue = serialize.JSValue;

// Re-export transferable types
pub const Transferable = transfer.Transferable;
pub const TransferableArrayBuffer = transfer.TransferableArrayBuffer;
pub const TransferableMessagePort = transfer.TransferableMessagePort;
pub const TransferableReadableStream = transfer.TransferableReadableStream;
pub const TransferableWritableStream = transfer.TransferableWritableStream;
pub const TransferableTransformStream = transfer.TransferableTransformStream;
pub const TransferableImageBitmap = transfer.TransferableImageBitmap;
pub const TransferableOffscreenCanvas = transfer.TransferableOffscreenCanvas;

// Re-export main algorithm functions
pub const structuredSerialize = serialize.structuredSerialize;
pub const structuredSerializeForStorage = serialize.structuredSerializeForStorage;
pub const structuredSerializeInternal = serialize.structuredSerializeInternal;
pub const structuredDeserialize = deserialize.structuredDeserialize;
pub const structuredSerializeWithTransfer = transfer.structuredSerializeWithTransfer;
pub const structuredDeserializeWithTransfer = transfer.structuredDeserializeWithTransfer;

// Re-export high-level API
pub const structuredClone = clone.structuredClone;
pub const structuredCloneWithOptions = clone.structuredCloneWithOptions;
pub const StructuredCloneOptions = clone.StructuredCloneOptions;
pub const isCloneable = clone.isCloneable;
pub const isTransferable = clone.isTransferable;
pub const clonePrimitive = clone.clonePrimitive;
pub const cloneObject = clone.cloneObject;

// Re-export memory management
pub const freeJSValue = deserialize.freeJSValue;

test {
    std.testing.refAllDecls(@This());
}
