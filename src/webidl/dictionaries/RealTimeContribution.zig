//! WebIDL dictionary: RealTimeContribution
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const RealTimeContribution = struct {
    bucket: i32,
    priorityWeight: f64,
    latencyThreshold: ?i32 = null,
};
