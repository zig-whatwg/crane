//! WebIDL dictionary: IdleOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const IdleOptions = struct {
    threshold: ?u64 = null,
    signal: ?*runtime.Instance = null,
};
