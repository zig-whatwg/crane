//! WebIDL dictionary: URLPatternComponentResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const URLPatternComponentResult = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    input: ?runtime.USVString = null,
    groups: ?[]const struct {
        pub const webidl_record_entry = true;
        key: runtime.USVString,
        value: typedefs.USVStringOrUndefined,
    } = null,
};
