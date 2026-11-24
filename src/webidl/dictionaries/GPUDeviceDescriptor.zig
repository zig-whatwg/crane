//! WebIDL dictionary: GPUDeviceDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const GPUQueueDescriptor = @import("GPUQueueDescriptor.zig").GPUQueueDescriptor;
const GPUObjectDescriptorBase = @import("GPUObjectDescriptorBase.zig").GPUObjectDescriptorBase;

pub const GPUDeviceDescriptor = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from GPUObjectDescriptorBase
    base: GPUObjectDescriptorBase,

    requiredFeatures: ?[]const enums.GPUFeatureName = null,
    requiredLimits: ?[]const struct {
        pub const webidl_record_entry = true;
        key: runtime.DOMString,
        value: typedefs.GPUSize64OrUndefined,
    } = null,
    defaultQueue: ?GPUQueueDescriptor = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "requiredFeatures", .empty_sequence },
        .{ "requiredLimits", .empty_dictionary },
        .{ "defaultQueue", .empty_dictionary },
    };
};
