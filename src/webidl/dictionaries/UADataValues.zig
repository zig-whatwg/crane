//! WebIDL dictionary: UADataValues
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const NavigatorUABrandVersion = @import("NavigatorUABrandVersion.zig").NavigatorUABrandVersion;

pub const UADataValues = struct {
    architecture: ?runtime.DOMString = null,
    bitness: ?runtime.DOMString = null,
    brands: ?[]const NavigatorUABrandVersion = null,
    formFactors: ?[]const runtime.DOMString = null,
    fullVersionList: ?[]const NavigatorUABrandVersion = null,
    model: ?runtime.DOMString = null,
    mobile: ?bool = null,
    platform: ?runtime.DOMString = null,
    platformVersion: ?runtime.DOMString = null,
    uaFullVersion: ?runtime.DOMString = null,
    wow64: ?bool = null,
};
