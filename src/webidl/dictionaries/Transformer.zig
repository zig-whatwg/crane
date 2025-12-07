//! WebIDL dictionary: Transformer
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const callbacks = @import("callbacks");

pub const Transformer = struct {
    start: ?callbacks.TransformerStartCallback = null,
    transform: ?callbacks.TransformerTransformCallback = null,
    flush: ?callbacks.TransformerFlushCallback = null,
    cancel: ?callbacks.TransformerCancelCallback = null,
    readableType: ?v8.JSValue = null,
    writableType: ?v8.JSValue = null,
};
