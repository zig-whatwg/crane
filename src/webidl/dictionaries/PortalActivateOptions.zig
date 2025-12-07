//! WebIDL dictionary: PortalActivateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const PostMessageOptions = @import("PostMessageOptions.zig").PostMessageOptions;

pub const PortalActivateOptions = struct {
    // Inherited from PostMessageOptions
    base: PostMessageOptions,

    data: ?v8.JSValue = null,
};
