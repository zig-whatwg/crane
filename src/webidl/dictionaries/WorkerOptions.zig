//! WebIDL dictionary: WorkerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const WorkerOptions = struct {
    name: ?runtime.DOMString = null,
    @"type": ?enums.WorkerType = null,
    credentials: ?enums.RequestCredentials = null,
};
