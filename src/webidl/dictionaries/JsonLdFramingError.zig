//! WebIDL dictionary: JsonLdFramingError
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const JsonLdFramingError = struct {
    code: ?enums.JsonLdFramingErrorCode = null,
    message: ?runtime.USVString = null,
};
