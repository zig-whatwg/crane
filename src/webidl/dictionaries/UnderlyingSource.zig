//! WebIDL dictionary: UnderlyingSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const callbacks = @import("callbacks");

pub const UnderlyingSource = struct {
    start: ?callbacks.UnderlyingSourceStartCallback = null,
    pull: ?callbacks.UnderlyingSourcePullCallback = null,
    cancel: ?callbacks.UnderlyingSourceCancelCallback = null,
    @"type": ?enums.ReadableStreamType = null,
    autoAllocateChunkSize: ?u64 = null,
};
