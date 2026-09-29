//! WebIDL dictionary: BaseComputedKeyframe
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const BaseComputedKeyframe = struct {
    offset: ?f64 = null,
    computedOffset: ?f64 = null,
    easing: ?runtime.DOMString = null,
    composite: ?enums.CompositeOperationOrAuto = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "offset", "computedOffset" };
};
