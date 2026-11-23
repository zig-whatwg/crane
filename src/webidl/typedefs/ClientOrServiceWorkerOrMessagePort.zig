//! WebIDL typedef: ClientOrServiceWorkerOrMessagePort
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const ClientOrServiceWorkerOrMessagePort = union(enum) {
    client: *runtime.Instance,
    service_worker: *runtime.Instance,
    message_port: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "client", .kind = .{ .interface = "Client" } },
        .{ .field = "service_worker", .kind = .{ .interface = "ServiceWorker" } },
        .{ .field = "message_port", .kind = .{ .interface = "MessagePort" } },
    };
};
