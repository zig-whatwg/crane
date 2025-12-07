//! WebIDL dictionary: JsonLdError
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const JsonLdError = struct {
    code: ?enums.JsonLdErrorCode = null,
    message: ?runtime.USVString = null,
};
