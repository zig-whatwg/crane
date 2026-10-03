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
    type: ?enums.ReadableStreamType = null,
    autoAllocateChunkSize: ?u64 = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"autoAllocateChunkSize"};
};
