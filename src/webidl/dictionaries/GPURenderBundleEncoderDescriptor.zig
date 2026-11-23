//! WebIDL dictionary: GPURenderBundleEncoderDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GPURenderPassLayout = @import("GPURenderPassLayout.zig").GPURenderPassLayout;

pub const GPURenderBundleEncoderDescriptor = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from GPURenderPassLayout
    base: GPURenderPassLayout,

    depthReadOnly: ?bool = null,
    stencilReadOnly: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "depthReadOnly", .{ .boolean = false } },
        .{ "stencilReadOnly", .{ .boolean = false } },
    };
};
