//! WebIDL dictionary: StreamPipeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const StreamPipeOptions = struct {
    preventClose: ?bool = null,
    preventAbort: ?bool = null,
    preventCancel: ?bool = null,
    signal: ?*runtime.Instance = null,
};
