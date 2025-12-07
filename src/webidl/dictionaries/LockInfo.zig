//! WebIDL dictionary: LockInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const LockInfo = struct {
    name: ?runtime.DOMString = null,
    mode: ?enums.LockMode = null,
    clientId: ?runtime.DOMString = null,
};
