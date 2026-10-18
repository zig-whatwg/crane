//! WebIDL dictionary: CaptureHandleConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CaptureHandleConfig = struct {
    exposeOrigin: ?bool = null,
    handle: ?runtime.DOMString = null,
    permittedOrigins: ?[]const runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "exposeOrigin", .{ .boolean = false } },
        .{ "handle", .{ .string = "" } },
        .{ "permittedOrigins", .empty_sequence },
    };
};
