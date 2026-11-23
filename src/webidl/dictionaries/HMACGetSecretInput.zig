//! WebIDL dictionary: HMACGetSecretInput
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const HMACGetSecretInput = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    salt1: runtime.JSValue,
    salt2: ?runtime.JSValue = null,
};
