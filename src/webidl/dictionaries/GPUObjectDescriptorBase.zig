//! WebIDL dictionary: GPUObjectDescriptorBase
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUObjectDescriptorBase = struct {
    label: ?runtime.USVString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "label", .{ .string = "" } },
    };
};
