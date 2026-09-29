//! WebIDL dictionary: RealTimeContribution
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RealTimeContribution = struct {
    bucket: i32,
    priorityWeight: f64,
    latencyThreshold: ?i32 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"priorityWeight"};
};
