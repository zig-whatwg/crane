//! WebIDL dictionary: WebGLContextAttributes
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const WebGLContextAttributes = struct {
    alpha: ?bool = null,
    depth: ?bool = null,
    stencil: ?bool = null,
    antialias: ?bool = null,
    premultipliedAlpha: ?bool = null,
    preserveDrawingBuffer: ?bool = null,
    powerPreference: ?enums.WebGLPowerPreference = null,
    failIfMajorPerformanceCaveat: ?bool = null,
    desynchronized: ?bool = null,
    xrCompatible: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "alpha", .{ .boolean = true } },
        .{ "depth", .{ .boolean = true } },
        .{ "stencil", .{ .boolean = false } },
        .{ "antialias", .{ .boolean = true } },
        .{ "premultipliedAlpha", .{ .boolean = true } },
        .{ "preserveDrawingBuffer", .{ .boolean = false } },
        .{ "powerPreference", .{ .string = "default" } },
        .{ "failIfMajorPerformanceCaveat", .{ .boolean = false } },
        .{ "desynchronized", .{ .boolean = false } },
        .{ "xrCompatible", .{ .boolean = false } },
    };
};
