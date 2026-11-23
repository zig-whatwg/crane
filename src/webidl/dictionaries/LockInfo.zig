//! WebIDL dictionary: LockInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const LockInfo = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    name: ?runtime.DOMString = null,
    mode: ?enums.LockMode = null,
    clientId: ?runtime.DOMString = null,
};
