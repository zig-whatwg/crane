//! WebIDL typedef: NDEFMessageSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const NDEFMessageSource = union(enum) {
    domstring: runtime.DOMString,
    buffer_source: typedefs.BufferSource,
    ndefmessage_init: dictionaries.NDEFMessageInit,
};
