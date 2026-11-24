//! WebIDL typedef: ServiceWorkerRegistrationOrUndefined
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const ServiceWorkerRegistrationOrUndefined = union(enum) {
    service_worker_registration: *runtime.Instance,
    undefined: void,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "service_worker_registration", .kind = .{ .interface = "ServiceWorkerRegistration" } },
        .{ .field = "undefined", .kind = .undefined },
    };
};
