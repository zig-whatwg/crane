//! WebIDL typedef: NDEFMessageSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const NDEFMessageSource = union(enum) {
    domstring: runtime.DOMString,
    buffer_source: typedefs.BufferSource,
    ndefmessage_init: *runtime.Instance,
};
