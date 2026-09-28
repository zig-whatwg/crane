//! WebIDL dictionary: Transformer
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const Transformer = struct {
    start: ?callbacks.TransformerStartCallback = null,
    transform: ?callbacks.TransformerTransformCallback = null,
    flush: ?callbacks.TransformerFlushCallback = null,
    cancel: ?callbacks.TransformerCancelCallback = null,
    readableType: ?runtime.JSValue = null,
    writableType: ?runtime.JSValue = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{ "readableType", "writableType" };
};
