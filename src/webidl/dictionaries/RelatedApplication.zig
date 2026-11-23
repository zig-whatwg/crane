//! WebIDL dictionary: RelatedApplication
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RelatedApplication = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    platform: runtime.USVString,
    url: ?runtime.USVString = null,
    id: ?runtime.DOMString = null,
    version: ?runtime.USVString = null,
};
