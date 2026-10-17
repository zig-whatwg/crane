//! WebIDL dictionary: WorkerAndParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const WorkerAndParameters = struct {
    worker: *runtime.Instance,
    type: ?enums.RTCRtpScriptTransformType = null,
};
