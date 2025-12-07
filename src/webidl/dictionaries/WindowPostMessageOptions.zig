//! WebIDL dictionary: WindowPostMessageOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const StructuredSerializeOptions = @import("StructuredSerializeOptions.zig").StructuredSerializeOptions;

pub const WindowPostMessageOptions = struct {
    // Inherited from StructuredSerializeOptions
    base: StructuredSerializeOptions,

    targetOrigin: ?runtime.USVString = null,
};
