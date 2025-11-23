//! WebIDL typedef: ArrayBufferView
//!
//! Spec: Union of all typed array types (Int8Array, Uint8Array, etc.) and DataView
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//!
//! Uses the rich implementation from webidl/types/buffer_sources.zig
//! which provides proper union type with 14 typed array variants and full API:
//! - getViewedArrayBuffer(), getByteOffset(), getByteLength()
//! - getTypedArrayName(), getElementSize(), getArrayLength()
//! - isDetached(), asBytes(), and more

const webidl = @import("webidl");

pub const ArrayBufferView = webidl.buffer_sources.ArrayBufferView;
