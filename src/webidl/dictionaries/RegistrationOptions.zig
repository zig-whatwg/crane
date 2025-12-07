//! WebIDL dictionary: RegistrationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const RegistrationOptions = struct {
    scope: ?runtime.USVString = null,
    @"type": ?enums.WorkerType = null,
    updateViaCache: ?enums.ServiceWorkerUpdateViaCache = null,
};
