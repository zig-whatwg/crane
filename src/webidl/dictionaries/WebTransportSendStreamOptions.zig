//! WebIDL dictionary: WebTransportSendStreamOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const WebTransportSendOptions = @import("WebTransportSendOptions.zig").WebTransportSendOptions;

pub const WebTransportSendStreamOptions = struct {
    // Inherited from WebTransportSendOptions
    base: WebTransportSendOptions,

    waitUntilAvailable: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "waitUntilAvailable", .{ .boolean = false } },
    };
};
