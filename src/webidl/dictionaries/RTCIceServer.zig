//! WebIDL dictionary: RTCIceServer
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const RTCIceServer = struct {
    urls: runtime.JSValue,
    username: ?runtime.DOMString = null,
    credential: ?runtime.DOMString = null,
};
