//! WebIDL dictionary: CaptureHandleConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const CaptureHandleConfig = struct {
    exposeOrigin: ?bool = null,
    handle: ?runtime.DOMString = null,
    permittedOrigins: ?[]const runtime.DOMString = null,
};
