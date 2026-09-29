//! WebIDL dictionary: GPUColorDict
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUColorDict = struct {
    r: f64,
    g: f64,
    b: f64,
    a: f64,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "r", "g", "b", "a" };
};
