//! WebIDL typedef: MessageEventSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const MessageEventSource = union(enum) {
    window_proxy: typedefs.WindowProxy,
    message_port: *runtime.Instance,
    service_worker: *runtime.Instance,
    htmlportal_element: *runtime.Instance,
    portal_host: *runtime.Instance,
};
