//! WebIDL dictionary: WebTransportHash
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const WebTransportHash = struct {
    algorithm: ?runtime.DOMString = null,
    value: ?typedefs.BufferSource = null,
};
