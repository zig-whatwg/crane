//! WebIDL dictionary: WebTransportErrorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const WebTransportErrorOptions = struct {
    source: ?enums.WebTransportErrorSource = null,
    streamErrorCode: ?u32 = null,

    /// [Clamp] members: converted with that branch of ConvertToInt.
    pub const clamp_members = .{"streamErrorCode"};
};
