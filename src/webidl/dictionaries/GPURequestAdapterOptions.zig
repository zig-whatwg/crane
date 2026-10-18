//! WebIDL dictionary: GPURequestAdapterOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPURequestAdapterOptions = struct {
    featureLevel: ?runtime.DOMString = null,
    powerPreference: ?enums.GPUPowerPreference = null,
    forceFallbackAdapter: ?bool = null,
    xrCompatible: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "featureLevel", .{ .string = "core" } },
        .{ "forceFallbackAdapter", .{ .boolean = false } },
        .{ "xrCompatible", .{ .boolean = false } },
    };
};
