//! WebIDL typedef: WorkerOrWorkerAndParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const WorkerOrWorkerAndParameters = union(enum) {
    worker: *runtime.Instance,
    worker_and_parameters: dictionaries.WorkerAndParameters,
};
