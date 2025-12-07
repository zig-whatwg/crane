//! WebIDL dictionary: HMACGetSecretInput
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const HMACGetSecretInput = struct {
    salt1: *const anyopaque,
    salt2: ?*const anyopaque = null,
};
