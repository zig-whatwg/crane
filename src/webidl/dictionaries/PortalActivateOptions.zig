//! WebIDL dictionary: PortalActivateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PostMessageOptions = @import("PostMessageOptions.zig").PostMessageOptions;

pub const PortalActivateOptions = struct {
    // Inherited from PostMessageOptions
    base: PostMessageOptions,

    data: ?runtime.JSValue = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"data"};
};
