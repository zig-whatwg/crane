//! WebIDL dictionary: RelatedApplication
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const RelatedApplication = struct {
    platform: runtime.USVString,
    url: ?runtime.USVString = null,
    id: ?runtime.DOMString = null,
    version: ?runtime.USVString = null,
};
