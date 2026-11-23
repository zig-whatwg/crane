//! WebIDL dictionary: RTCIceServer
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCIceServer = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    urls: runtime.JSValue,
    username: ?runtime.DOMString = null,
    credential: ?runtime.DOMString = null,
};
