//! WebIDL dictionary: WebTransportSendStreamOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const WebTransportSendOptions = @import("WebTransportSendOptions.zig").WebTransportSendOptions;

pub const WebTransportSendStreamOptions = struct {
    // Inherited from WebTransportSendOptions
    base: WebTransportSendOptions,

    waitUntilAvailable: ?bool = null,
};
