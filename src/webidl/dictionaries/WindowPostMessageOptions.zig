//! WebIDL dictionary: WindowPostMessageOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const StructuredSerializeOptions = @import("StructuredSerializeOptions.zig").StructuredSerializeOptions;

pub const WindowPostMessageOptions = struct {
    // Inherited from StructuredSerializeOptions
    base: StructuredSerializeOptions,

    targetOrigin: ?runtime.DOMString = null,
};
