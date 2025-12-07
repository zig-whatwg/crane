//! WebIDL dictionary: ResponseInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ResponseInit = struct {
    status: ?u16 = null,
    statusText: ?runtime.ByteString = null,
    headers: ?typedefs.HeadersInit = null,
};
