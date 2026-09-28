//! WebIDL dictionary: SmartCardGetStatusChangeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const SmartCardGetStatusChangeOptions = struct {
    timeout: ?typedefs.DOMHighResTimeStamp = null,
    signal: ?*runtime.Instance = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"timeout"};
};
