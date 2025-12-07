//! WebIDL dictionary: UALowEntropyJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const NavigatorUABrandVersion = @import("NavigatorUABrandVersion.zig").NavigatorUABrandVersion;

pub const UALowEntropyJSON = struct {
    brands: ?[]const NavigatorUABrandVersion = null,
    mobile: ?bool = null,
    platform: ?runtime.DOMString = null,
};
