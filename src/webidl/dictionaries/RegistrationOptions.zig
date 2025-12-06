//! WebIDL dictionary: RegistrationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RegistrationOptions = struct {
    scope: ?runtime.USVString = null,
    type: ?*const anyopaque = null,
    updateViaCache: ?*const anyopaque = null,
};
