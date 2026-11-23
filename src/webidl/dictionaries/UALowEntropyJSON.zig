//! WebIDL dictionary: UALowEntropyJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const NavigatorUABrandVersion = @import("NavigatorUABrandVersion.zig").NavigatorUABrandVersion;

pub const UALowEntropyJSON = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    brands: ?[]const NavigatorUABrandVersion = null,
    mobile: ?bool = null,
    platform: ?runtime.DOMString = null,
};
