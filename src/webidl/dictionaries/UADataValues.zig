//! WebIDL dictionary: UADataValues
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const UADataValues = struct {
    architecture: ?runtime.DOMString = null,
    bitness: ?runtime.DOMString = null,
    brands: ?*const anyopaque = null,
    formFactors: ?*const anyopaque = null,
    fullVersionList: ?*const anyopaque = null,
    model: ?runtime.DOMString = null,
    mobile: ?bool = null,
    platform: ?runtime.DOMString = null,
    platformVersion: ?runtime.DOMString = null,
    uaFullVersion: ?runtime.DOMString = null,
    wow64: ?bool = null,
};
