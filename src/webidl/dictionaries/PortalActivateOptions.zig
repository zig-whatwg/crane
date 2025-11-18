//! WebIDL dictionary: PortalActivateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PostMessageOptions = @import("PostMessageOptions.zig").PostMessageOptions;

pub const PortalActivateOptions = struct {
    // Inherited from PostMessageOptions
    base: PostMessageOptions,

    data: ?anyopaque = null,
};
