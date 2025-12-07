//! WebIDL dictionary: SmartCardGetStatusChangeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const SmartCardGetStatusChangeOptions = struct {
    timeout: ?typedefs.DOMHighResTimeStamp = null,
    signal: ?*runtime.Instance = null,
};
