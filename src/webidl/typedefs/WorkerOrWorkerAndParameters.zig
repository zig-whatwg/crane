//! WebIDL typedef: WorkerOrWorkerAndParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const WorkerOrWorkerAndParameters = union(enum) {
    worker: *runtime.Instance,
    worker_and_parameters: dictionaries.WorkerAndParameters,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "worker", .kind = .{ .interface = "Worker" } },
        .{ .field = "worker_and_parameters", .kind = .dictionary },
    };
};
