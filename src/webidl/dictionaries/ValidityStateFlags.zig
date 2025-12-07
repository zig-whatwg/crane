//! WebIDL dictionary: ValidityStateFlags
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const ValidityStateFlags = struct {
    valueMissing: ?bool = null,
    typeMismatch: ?bool = null,
    patternMismatch: ?bool = null,
    tooLong: ?bool = null,
    tooShort: ?bool = null,
    rangeUnderflow: ?bool = null,
    rangeOverflow: ?bool = null,
    stepMismatch: ?bool = null,
    badInput: ?bool = null,
    customError: ?bool = null,
};
