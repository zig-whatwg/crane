//! WebIDL dictionary: WorkerAndParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const WorkerAndParameters = struct {
    worker: *runtime.Instance,
    type: ?enums.RTCRtpScriptTransformType = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "worker", "Worker" },
    };
};
