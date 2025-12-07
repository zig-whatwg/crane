//! WebIDL typedef: NDEFMessageSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("root.zig");

pub const NDEFMessageSource = union(enum) {
    domstring: runtime.DOMString,
    buffer_source: typedefs.BufferSource,
    ndefmessage_init: dictionaries.NDEFMessageInit,
};
