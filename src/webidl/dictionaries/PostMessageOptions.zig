//! WebIDL dictionary: PostMessageOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const StructuredSerializeOptions = @import("StructuredSerializeOptions.zig").StructuredSerializeOptions;

pub const PostMessageOptions = struct {
    // Inherited from StructuredSerializeOptions
    base: StructuredSerializeOptions,

    includeUserActivation: ?bool = null,
};
